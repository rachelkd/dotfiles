return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    cmd = "LazyDev",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "LazyVim" },
        { path = "snacks.nvim" },
        { path = "lazy.nvim" },
      },
    },
  },
}
