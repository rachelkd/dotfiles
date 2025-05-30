return {
  -- Disable plugins in VSCode
  {
    "rose-pine/neovim",
    enabled = not vim.g.vscode,
  },
  {
    "echasnovski/mini.animate",
    enabled = not vim.g.vscode,
  },
  -- Add more plugins to disable in VSCode here
  -- Example format:
  -- {
  --   "author/plugin-name",
  --   enabled = not vim.g.vscode,
  -- },
}

