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
  callback = function()
    local target_scheme = vim.o.background == "light" and "rose-pine" or "catppuccin"
    local ok = pcall(vim.cmd.colorscheme, target_scheme)
    if not ok then
      vim.notify("Colorscheme " .. target_scheme .. " not found, keeping current theme", vim.log.levels.WARN)
    end
  end,
})
