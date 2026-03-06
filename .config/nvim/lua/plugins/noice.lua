-- Fix :! shell commands not showing output.
-- By default, noice.nvim captures shell output but doesn't display it.
-- This routes shell stdout/stderr to the notify view so it's actually visible.
return {
  "folke/noice.nvim",
  opts = {
    routes = {
      {
        view = "notify",
        filter = {
          event = "msg_show",
          kind = { "shell_out", "shell_err" },
        },
      },
    },
  },
}
