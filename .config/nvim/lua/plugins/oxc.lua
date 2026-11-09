-- JS/TS/JSON formatting: Prettier only in repos with a Prettier config and no
-- oxfmt config, oxfmt everywhere else. Without this, LazyVim's prettier and oxc
-- extras both run on every save.
local oxfmt_configs = { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" }

-- Same check as LazyVim's prettier extra: prettier exits 0 when it finds a config.
local has_prettier_config = LazyVim.memoize(function(file)
  vim.fn.system({ "prettier", "--find-config-path", file })
  return vim.v.shell_error == 0
end)

local function formatters(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if not vim.fs.root(file, oxfmt_configs) and has_prettier_config(file) then
    return { "prettier" }
  end
  return { "oxfmt" }
end

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc" }) do
        opts.formatters_by_ft[ft] = formatters
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        oxlint = {
          cmd = function(dispatchers, config)
            local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin/oxlint")
            local cmd = vim.fn.executable(local_cmd) == 1 and local_cmd or "oxlint"
            return vim.lsp.rpc.start({ cmd, "--lsp" }, dispatchers, { cwd = config.root_dir })
          end,
        },
      },
    },
  },
}
