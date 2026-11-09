-- Counts the panes in every session whose Claude Code or Codex agent is working or
-- blocked, writes "working blocked" for SketchyBar's agents item and triggers it.
-- done and error aren't counted: agents leave them on the pane until their next turn.
-- Run by the launchd job dev.rachel.rex-agents with `rex do agents.lua --all`.

local apps = { ["claude-code"] = true, codex = true }
local state_file = (os.getenv("TMPDIR") or "/tmp/") .. "sketchybar_rex_agents"
local last

local function count()
  local n = { working = 0, blocked = 0 }
  for _, s in ipairs(rex.call("session.list").sessions) do
    local list = rex.call("session.list_blocks", { session_id = s.session_id })
    for _, b in ipairs(list and list.blocks or {}) do
      local status = rex.call("com.superlogical.terminal.program_status",
        { session_id = s.session_id, block_id = b.block_id, args = {} })
      -- A pane's dot is blocked if any of its records is, else working
      local state
      for _, r in ipairs(status and status.records or {}) do
        if apps[r.effective_app] and n[r.state] and state ~= "blocked" then state = r.state end
      end
      if state then n[state] = n[state] + 1 end
    end
  end
  return n.working .. " " .. n.blocked
end

local function update()
  local counts = count()
  if counts == last then return end
  last = counts
  local f = assert(io.open(state_file, "w"))
  f:write(counts, "\n")
  f:close()
  rex.exec{ "sketchybar", "--trigger", "rex_agents_changed" }
end

-- Agents change state in bursts, so recount once things settle
local pending
local function schedule()
  if pending then pending:cancel() end
  pending = rex.after(0.3, update)
end

for _, event in ipairs{
  "terminal.program_status_changed",
  "terminal.program_status_removed",
  "block_closed",
  "session_destroyed",
} do
  rex.on(event, schedule)
end
rex.after(0, update)
