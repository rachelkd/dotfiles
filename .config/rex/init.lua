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
