-- Remembers each session's previously active tab, for init.lua's tab_last action.
-- Rex only sends tab-switch events to scripts, so init.lua can't track this itself.
-- Run by the launchd job dev.rachel.rex-tabs with `rex do tabs.lua --all`.

local state_file = (os.getenv("TMPDIR") or "/tmp/") .. "rex_last_tabs.json"
local current, last = {}, {}

local function save()
  local f = assert(io.open(state_file, "w"))
  f:write(rex.json.encode(last))
  f:close()
end

-- A session's first active tab doesn't fire active_window_changed, so read it
local function track(session_id)
  local view = rex.session.view{ session_id = session_id }
  current[session_id] = view and view.active_window_id
end

for _, s in ipairs(rex.call("session.list").sessions or {}) do
  track(s.session_id)
end
save()

rex.on("session_created", function(ctx, ev)
  track(ev.session.session_id)
end)

rex.on("active_window_changed", function(ctx, ev)
  local s = ctx.session_id
  if current[s] and current[s] ~= ev.window_id then
    last[s] = current[s]
  elseif last[s] == ev.window_id then
    -- After closing the active tab, Rex may activate the last one
    last[s] = nil
  end
  current[s] = ev.window_id
  save()
end)

rex.on("window_closed", function(ctx, ev)
  local s = ctx.session_id
  if current[s] == ev.window_id then current[s] = nil end
  if last[s] == ev.window_id then last[s] = nil end
  save()
end)
