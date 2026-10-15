local indent_colors =
  { "SnacksIndent1", "SnacksIndent2", "SnacksIndent3", "SnacksIndent4", "SnacksIndent5", "SnacksIndent6" }

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      image = {},
      indent = {
        indent = { hl = indent_colors },
        scope = {
          hl = {
            "SnacksIndentScope1",
            "SnacksIndentScope2",
            "SnacksIndentScope3",
            "SnacksIndentScope4",
            "SnacksIndentScope5",
            "SnacksIndentScope6",
          },
        },
      },
      lazygit = {
        -- Focused borders default to MatchParen's fg, which cutiepro leaves unset.
        theme = {
          activeBorderColor = { fg = "FloatTitle", bold = true },
          searchingActiveBorderColor = { fg = "FloatTitle", bold = true },
        },
      },
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
