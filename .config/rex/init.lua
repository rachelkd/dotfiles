local p = "ctrl+b>"

rex.bind(p .. "c", "client.tab.new")
rex.bind(p .. "n", "client.tab.next")
rex.bind(p .. "p", "client.tab.previous")
rex.bind(p .. "shift+x", "client.tab.close")
rex.bind(p .. "shift+t", "client.tab.rename")
for i = 1, 9 do
  rex.bind(p .. i, "client.tab.goto", { index = i })
end

rex.bind(p .. "v", "pane.split.right")
rex.bind(p .. "-", "pane.split.down")
rex.bind(p .. "h", "pane.focus.left")
rex.bind(p .. "j", "pane.focus.down")
rex.bind(p .. "k", "pane.focus.up")
rex.bind(p .. "l", "pane.focus.right")
rex.bind(p .. "tab", "pane.focus_next")
rex.bind(p .. "shift+tab", "pane.focus_previous")
rex.bind(p .. "z", "pane.zoom")
rex.bind(p .. "x", "pane.close")

rex.bind(p .. "g", "session.switch")
rex.bind(p .. "shift+n", "session.new")
rex.bind(p .. "shift+w", "session.rename")
rex.bind(p .. "b", "client.sidebar.toggle")
rex.bind(p .. "shift+r", "client.config.reload")

rex.bind(p .. "r", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane.resize", { direction = "left" })
rex.bind("resize/j", "pane.resize", { direction = "down" })
rex.bind("resize/k", "pane.resize", { direction = "up" })
rex.bind("resize/l", "pane.resize", { direction = "right" })
rex.mode("resize", { exclusive = true })

rex.bind(p .. "w", "client.mode.enter", { name = "navigate" })
rex.bind("navigate/up", "session.previous")
rex.bind("navigate/down", "session.next")
rex.bind("navigate/h", "pane.focus.left")
rex.bind("navigate/j", "pane.focus.down")
rex.bind("navigate/k", "pane.focus.up")
rex.bind("navigate/l", "pane.focus.right")
rex.bind("navigate/left", "pane.focus.left")
rex.bind("navigate/right", "pane.focus.right")
rex.bind("navigate/enter", "client.mode.exit")
rex.bind("navigate/ctrl+b", "client.mode.exit")
rex.mode("navigate", { exclusive = true })

rex.bind(p .. "ctrl+b", "pane.send_key", { key = "ctrl+b" })

rex.action{
  name = "send_insert",
  title = "Send Insert",
  description = "Presses Insert in the focused pane, which copies the selection in pspg.",
  keywords = "ins pspg copy yank",
  run = function()
    rex.client.queue("pane.send_key", { key = "insert" })
  end,
}
rex.bind(p .. "y", "send_insert")

local terminal = "com.superlogical.terminal"
local shell = "com.superlogical.terminal.shell"

rex.action{
  name = "lazygit_popup",
  title = "Lazygit Popup",
  description = "Opens lazygit in a floating pane, in the focused pane's directory. Quitting lazygit closes it.",
  keywords = "git diff review float",
  run = function(ctx)
    local proc, err = rex.block.call(terminal, "process", { block_id = ctx.block_id })
    if err ~= nil then error(err, 0) end
    local _, err = rex.session.new_layer{
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = rex.layout.block{
        flavor = shell,
        options = { command = { "lazygit" }, cwd = proc.foreground and proc.foreground.cwd },
      },
    }
    if err ~= nil then error(err, 0) end
  end,
}
rex.bind(p .. "shift+g", "lazygit_popup")

-- Rex version of kws: one session per k env, labeled N, with the same tabs
rex.action{
  name = "kenv",
  title = "Open k env",
  description = "Shows the session for ~/code/kenv/N, creating it with shell, nvim, git, logs, db and agents tabs.",
  keywords = "kws env worktree workspace",
  args = { n = "integer" },
  run = function(ctx, args)
    local label = tostring(args.n)
    local dir = os.getenv("HOME") .. "/code/kenv/" .. label .. "/core"
    if not rex.exec{ "test", "-d", dir }.ok then error("no k env at " .. dir, 0) end

    local list, err = rex.call("session.list")
    if err ~= nil then error(err, 0) end
    for _, s in ipairs(list.sessions) do
      if s.label == label then
        rex.client.queue("session.select", { session_id = s.session_id })
        return
      end
    end

    local tabs = {
      { "shell" },
      { "nvim", "nvim ." },
      { "git", "lazygit" },
      { "logs", "docker compose logs -f --tail 200 api" },
      { "db", "db-local" },
      { "agents" },
    }
    local windows = {}
    for i, tab in ipairs(tabs) do
      windows[i] = {
        window_label = tab[1],
        layout = rex.layout.block{
          flavor = shell,
          options = { cwd = dir, initial_input = tab[2] and tab[2] .. "\n" },
        },
      }
    end
    local created, err = rex.call("session.create", { label = label, initial_windows = windows })
    if err ~= nil then error(err, 0) end
    rex.client.queue("session.select", {
      session_id = created.session_id,
      window_id = created.initial_windows[1].window_id,
    })
  end,
}
for i = 1, 9 do
  rex.bind(p .. "e>" .. i, "kenv", { n = i })
end
