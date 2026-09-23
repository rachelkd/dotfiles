-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt_local.expandtab = true

-- OSC 52 is a terminal escape sequence that asks the terminal emulator to write to
-- the local clipboard on our behalf. The terminal (e.g. Ghostty) must have
-- clipboard write access enabled, and any multiplexer in between must pass it through.
--
-- Copying via OSC 52 is cheap and safe. Pasting via OSC 52 is not: it asks the
-- terminal to send the clipboard back, and if the clipboard contains an image the
-- response is binary/huge and causes a multi-second freeze (terminals that ignore
-- the query, like VSCode/Cursor's, freeze until timeout). So:
--   * SSH: OSC 52 for both copy and paste (no other way to reach the local clipboard).
--   * herdr locally on macOS: OSC 52 for copy, pbpaste for paste (read the Mac clipboard directly).
--   * Otherwise: leave Neovim's default provider (pbcopy/pbpaste) alone.
-- Skip inside VSCode/Cursor entirely; vscode-neovim has its own native clipboard provider.
if not vim.g.vscode then
  local osc52 = require("vim.ui.clipboard.osc52")
  local copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") }

  if os.getenv("SSH_TTY") then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = copy,
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  elseif os.getenv("HERDR_ENV") and vim.fn.has("mac") == 1 then
    vim.g.clipboard = {
      name = "OSC 52 (copy) + pbpaste",
      copy = copy,
      paste = { ["+"] = { "pbpaste" }, ["*"] = { "pbpaste" } },
    }
  end
end

-- Route all yanks through the + register so they go via the clipboard provider above.
vim.opt.clipboard = "unnamedplus"

-- Python: use ty for types and ruff for lint/format (see lua/plugins/python.lua).
-- LazyVim's python extra reads these to pick which servers it enables.
vim.g.lazyvim_python_lsp = "ty"
vim.g.lazyvim_python_ruff = "ruff"

vim.filetype.add({
  extension = {
    ddl = "sql",
  },
})
