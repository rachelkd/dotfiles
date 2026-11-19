-- Brings back what panes were running, after a Rex server restart and when init.lua's tab_reopen
-- reopens a closed tab. Rex brings panes back as new shells in the same directory, so this saves
-- each pane's command line (written by shell.zsh) and types it into the new shell. Claude Code
-- panes resume their conversation instead.
-- Run by the launchd job dev.rachel.rex-restore with `rex do restore.lua --all`. The script exits
-- when the server goes away, and launchd starts it again.

local terminal = "com.superlogical.terminal"
local tmp = os.getenv("TMPDIR") or "/tmp/"
local state_file = tmp .. "rex_restore.json"
local closed_file = tmp .. "rex_closed_tabs.json"
local panes = {} -- block_id -> { session_id, command }
local cwds = {} -- block_id -> the directory its shell last reported
local tabs = {} -- window_id -> { label, layout }, as session.view last showed it

local function read(path)
	local f = io.open(path)
	if not f then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
end

local function write(path, value)
	local f = assert(io.open(path, "w"))
	f:write(rex.json.encode(value))
	f:close()
end

-- Read before any handler saves over it
local saved = rex.json.decode(read(state_file) or "{}") or {}
local server = rex.call("server.status").instance_id

local function process(session_id, block_id)
	return rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id })
end

-- The process a pane's shell started, or nil while the shell is starting or at its prompt.
-- p is the pane's process info, from the process method or a process_changed event.
-- Rex starts each shell through login as a login shell (-zsh).
local function job(p)
	if not p or not p.foreground then
		return nil
	end
	local found
	for _, proc in ipairs({ p.foreground, unpack(p.ancestors or {}) }) do
		if proc.name == "login" or (proc.argv0 or ""):sub(1, 1) == "-" then
			break
		end
		found = proc
	end
	return found
end

local function command(block_id, proc)
	local claude = read(os.getenv("HOME") .. "/.claude/sessions/" .. proc.pid .. ".json")
	if claude then
		return "claude --resume " .. rex.json.decode(claude).sessionId
	end
	-- Nothing says which thread a Codex TUI shows, so pick it from this directory's threads
	if proc.argv0 == "codex" then
		return "codex resume"
	end
	return read(tmp .. "rex_commands/" .. block_id)
end

-- Records what a pane runs, and returns whether that changed
local function update(session_id, block_id, p)
	local proc = job(p)
	local cmd = proc and command(block_id, proc)
	if cmd == (panes[block_id] and panes[block_id].command) then
		return false
	end
	panes[block_id] = cmd and { session_id = session_id, command = cmd } or nil
	return true
end

local function save()
	write(state_file, { server = server, panes = panes })
end

-- Shells report their directory (OSC 7) as file://host/path
local function set_cwd(block_id, url)
	cwds[block_id] = url and url:gsub("^file://[^/]*", "")
end

-- A window's layout is gone by the time its window_closed event arrives, so keep a copy
local function cache_tabs(session_id)
	local view = rex.session.view({ session_id = session_id })
	for _, w in ipairs(view and view.windows or {}) do
		-- An unnamed tab shows a made-up "Window <id>" label, which a reopened tab shouldn't keep
		local label = w.label ~= "Window " .. w.window_id:sub(-8) and w.label or nil
		for _, layer in ipairs(w.layers) do
			if layer.kind == "tiled" then
				tabs[w.window_id] = { label = label, layout = layer.layout }
			end
		end
	end
end

-- A closed tab's layout, with each pane's directory and command in place of its block
local function describe(node)
	if node.split then
		local s = node.split
		return { direction = s.direction, ratio = s.ratio, before = describe(s.before), after = describe(s.after) }
	end
	local pane = panes[node.block_id]
	return { cwd = cwds[node.block_id], command = pane and pane.command }
end

-- After a server restart, types each saved command into its pane, unless the pane already runs something
local function restore()
	if saved.server == server then
		return
	end
	for block_id, pane in pairs(saved.panes or {}) do
		if not job(process(pane.session_id, block_id)) then
			rex.block.call(terminal, "write", {
				session_id = pane.session_id,
				block_id = block_id,
				data = pane.command .. "\n",
			})
		end
	end
end

rex.on("terminal.process_changed", function(ctx, ev)
	if update(ctx.session_id, ctx.block_id, ev) then
		save()
	end
end)
-- Claude Code reports its status as it works, which also catches a /clear or /resume changing its session
rex.on("terminal.program_status_changed", function(ctx)
	if update(ctx.session_id, ctx.block_id, process(ctx.session_id, ctx.block_id)) then
		save()
	end
end)
rex.on("terminal.pwd_changed", function(ctx, ev)
	set_cwd(ctx.block_id, ev.pwd)
end)
rex.on("session_view_changed", function(ctx)
	cache_tabs(ctx.session_id)
end)
-- Arrives before its panes' block_closed events, so their commands and directories are still known
rex.on("window_closed", function(ctx, ev)
	local tab = tabs[ev.window_id]
	tabs[ev.window_id] = nil
	if not tab then
		return
	end
	-- tab_reopen also writes this file, so read it fresh
	local closed = rex.json.decode(read(closed_file) or "{}") or {}
	local list = closed[ctx.session_id] or {}
	table.insert(list, { label = tab.label, layout = describe(tab.layout) })
	if #list > 20 then
		table.remove(list, 1)
	end
	closed[ctx.session_id] = list
	write(closed_file, closed)
end)
rex.on("block_closed", function(_, ev)
	cwds[ev.block_id] = nil
	if panes[ev.block_id] then
		panes[ev.block_id] = nil
		save()
	end
end)
rex.after(0, function()
	restore()
	for _, s in ipairs(rex.call("session.list").sessions) do
		cache_tabs(s.session_id)
		local list = rex.call("session.list_blocks", { session_id = s.session_id })
		for _, b in ipairs(list and list.blocks or {}) do
			update(s.session_id, b.block_id, process(s.session_id, b.block_id))
			local pwd = rex.block.call(terminal, "pwd", { session_id = s.session_id, block_id = b.block_id })
			set_cwd(b.block_id, pwd and pwd.pwd)
		end
	end
	save()
end)
