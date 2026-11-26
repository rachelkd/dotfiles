-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Auto-switch colorscheme when background changes (e.g. system dark/light mode toggle)
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  -- Without nested, :colorscheme skips the ColorScheme event, so plugins (bufferline, blink.cmp,
  -- gitsigns) never re-add the highlights it just cleared.
  nested = true,
  callback = function()
    local target_scheme = vim.o.background == "light" and "rose-pine" or "cutiepro"
    -- local target_scheme = vim.o.background == "light" and "rose-pine" or "catppuccin"
    -- cutiepro's reload sets 'background' back to dark, so Neovim unsets g:colors_name and rose-pine
    -- skips its own `hi clear`, leaving cutiepro colors behind. Clear first.
    vim.cmd.highlight("clear")
    local ok = pcall(vim.cmd.colorscheme, target_scheme)
    if not ok then
      vim.notify("Colorscheme " .. target_scheme .. " not found", vim.log.levels.WARN)
    end
  end,
})
