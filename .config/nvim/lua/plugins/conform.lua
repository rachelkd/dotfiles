-- Resolve ruff from the nearest .venv above the file, same as the Ruff LSP in
-- python.lua. Search starts at the buffer directory and walks up, so api/.venv
-- is found for files under api/ even when the git root is the monorepo.
---@param _ conform.FormatterConfig
---@param ctx conform.Context
local function venv_ruff(_, ctx)
  local venv = vim.fs.find(".venv", { path = ctx.dirname, upward = true, type = "directory" })[1]
  local bin = venv and (venv .. "/bin/ruff")
  if bin and vim.uv.fs_stat(bin) then
    return bin
  end
  return "ruff"
end

return {
  "stevearc/conform.nvim",
  opts = {
    -- ruff_fix is `ruff check --fix` (import sort, unused imports, other safe
    -- fixes). ruff_format is `ruff format`. Same order as `make lint` in api/.
    formatters_by_ft = {
      python = { "ruff_fix", "ruff_format" },
      sql = { "sqlfluff" },
    },
    formatters = {
      ruff_fix = { command = venv_ruff },
      ruff_format = { command = venv_ruff },
      sqlfluff = {
        args = { "format", "--dialect", "postgres", "-" },
      },
    },
  },
}
