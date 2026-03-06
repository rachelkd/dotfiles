return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      sqlfluff = {
        args = { "format", "--dialect", "postgres", "-" },
      },
    },
  },
}
