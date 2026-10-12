-- Point markdownlint-cli2 at a base config: 4-space list indent, no line-length limit.
-- --config is only the base, so a project's own .markdownlint* still wins.
return {
  "mfussenegger/nvim-lint",
  optional = true,
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        args = { "--config", vim.fn.stdpath("config") .. "/.markdownlint.json", "-" },
      },
    },
  },
}
