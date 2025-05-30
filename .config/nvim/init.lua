-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Format on save
vim.cmd([[autocmd BufWritePre * lua vim.lsp.buf.format()]])
