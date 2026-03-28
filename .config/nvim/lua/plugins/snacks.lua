return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      image = {},
      explorer = {
        -- your explorer configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      },
      picker = {
        hidden = true,
        sources = {
          explorer = {
            ignored = true,
          },
          files = {
            hidden = true,
          },
        },
      },
    },
  },
}
