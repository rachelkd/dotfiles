return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        -- Pick the scheme by background, then load it via the plugin's own `load()`.
        -- Using `require(plugin).load()` (rather than `vim.cmd.colorscheme`) forces
        -- lazy.nvim to load the plugin -- running its opts/setup() -- BEFORE applying,
        -- so the theme's options (transparency, etc.) are in effect on the first apply.
        if vim.o.background == "light" then
          require("rose-pine").colorscheme()
        else
          require("catppuccin").load()
        end
      end,
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      transparent_background = true,
      float = { transparent = true },
    },
  },
  {
    "sainnhe/everforest",
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
    opts = {
      styles = { transparency = true },
    },
  },
}
