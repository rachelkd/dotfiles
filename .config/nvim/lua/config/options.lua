-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt_local.expandtab = true

-- OSC 52 is a terminal escape sequence that asks the terminal emulator to write to
-- the local clipboard on our behalf. Only enable it in SSH sessions where there is
-- no direct access to the local machine's clipboard. The terminal (e.g. Ghostty)
-- must have clipboard write access enabled.
--
-- Do NOT use OSC 52 locally on macOS: if the clipboard contains an image, the
-- terminal's paste response is binary/huge and causes a multi-second freeze.
-- Locally, Neovim uses pbcopy/pbpaste natively and handles all clipboard types fine.
--
-- Also skip inside VSCode/Cursor: their terminal ignores the OSC 52 paste query,
-- causing the same freeze. vscode-neovim has its own native clipboard provider.
if not vim.g.vscode and os.getenv("SSH_TTY") then
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
end

-- Route all yanks through the + register so they go via the OSC 52 provider above.
vim.opt.clipboard = "unnamedplus"

vim.filetype.add({
  extension = {
    ddl = "sql",
  },
})
