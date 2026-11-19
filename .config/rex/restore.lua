-- Reruns what each pane was running when the Rex server restarted. Rex brings panes back as new
-- shells in the same directory, so this saves each pane's command line (written by shell.zsh) and
-- types it into the new shell. Claude Code panes resume their conversation instead.
-- Run by the launchd job dev.rachel.rex-restore with `rex do restore.lua --all`. The script exits
-- when the server goes away, and launchd starts it again.

local terminal = "com.superlogical.terminal"
local tmp = os.getenv("TMPDIR") or "/tmp/"
local state_file = tmp .. "rex_restore.json"
local panes = {} -- block_id -> { session_id, command }

local function read(path)
	local f = io.open(path)
	if not f then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
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
	local f = assert(io.open(state_file, "w"))
	f:write(rex.json.encode({ server = server, panes = panes }))
	f:close()
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
rex.on("block_closed", function(_, ev)
	if panes[ev.block_id] then
		panes[ev.block_id] = nil
		save()
	end
end)
rex.after(0, function()
	restore()
	for _, s in ipairs(rex.call("session.list").sessions) do
		local list = rex.call("session.list_blocks", { session_id = s.session_id })
		for _, b in ipairs(list and list.blocks or {}) do
			update(s.session_id, b.block_id, process(s.session_id, b.block_id))
		end
	end
	save()
end)
