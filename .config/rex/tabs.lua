-- Remembers the current and previous tab across all sessions, for init.lua's tab_last action.
-- Rex only sends tab-switch events to scripts, so init.lua can't track this itself.
-- Run by the launchd job dev.rachel.rex-tabs with `rex do tabs.lua --all`.

local state_file = (os.getenv("TMPDIR") or "/tmp/") .. "rex_last_tabs.json"

-- tab_last also writes the state, so read it fresh for every event
local function load()
  local f = io.open(state_file)
  if not f then return {} end
  local state = rex.json.decode(f:read("*a"))
  f:close()
  return state
end

local function save(state)
  local f = assert(io.open(state_file, "w"))
  f:write(rex.json.encode(state))
  f:close()
end

rex.on("active_window_changed", function(ctx, ev)
  local state = load()
  if state.current and state.current.window_id ~= ev.window_id then
    state.last = state.current
  elseif state.last and state.last.window_id == ev.window_id then
    -- After closing the active tab, Rex may activate the last one
    state.last = nil
  end
  state.current = { session_id = ctx.session_id, window_id = ev.window_id }
  save(state)
end)

rex.on("window_closed", function(ctx, ev)
  local state = load()
  if state.current and state.current.window_id == ev.window_id then state.current = nil end
  if state.last and state.last.window_id == ev.window_id then state.last = nil end
  save(state)
end)
