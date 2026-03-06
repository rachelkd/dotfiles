-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt_local.expandtab = true

-- When running over SSH, there is no direct access to the local machine's clipboard.
-- OSC 52 is a terminal escape sequence that asks the terminal emulator to write to
-- the local clipboard on our behalf. The terminal (e.g. Ghostty) must have clipboard
-- write access enabled. We register the OSC 52 provider before setting clipboard so
-- Neovim uses it immediately.
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}

-- Route all yanks through the + register so they go via the OSC 52 provider above.
vim.opt.clipboard = "unnamedplus"
