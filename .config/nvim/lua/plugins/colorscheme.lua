return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        -- Detect system appearance
        local bg = vim.o.background
        if bg == "light" then
          return "rose-pine"
        else
          return "catppuccin"
        end
      end,
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "auto",
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true,
      float = {
        transparent = true,
        solid = false,
      },
    },
  },
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.everforest_transparent_background = 2
      vim.g.everforest_enable_italic = true
      vim.g.everforest_background = "medium" -- 'hard', 'medium', 'soft'
      vim.g.everforest_better_performance = 1

      -- Fix snacks.nvim explorer colors after theme loads
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "everforest",
        callback = function()
          local config = vim.fn["everforest#get_configuration"]()
          local palette = vim.fn["everforest#get_palette"](config.background, config.colors_override)

          -- Get the normal text color
          local dark_grey = palette.grey2[1]
          local light_grey = palette.grey0[1]

          -- Override Snacks picker highlight groups for hidden/ignored files
          vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = dark_grey })
          vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { fg = light_grey })

          -- Fix untracked git file color (default too washed out)
          vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { fg = light_grey })
        end,
      })
    end,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "auto",
      dark_variant = "main",
      styles = {
        transparency = true,
      },
    },
  },
}
