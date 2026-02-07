return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        -- Detect system appearance
        local bg = vim.o.background
        if bg == "light" then
          return "everforest"
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
      vim.cmd.colorscheme("everforest")

      -- Auto-switch themes based on system appearance
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        callback = function()
          local target_scheme = vim.o.background == "light" and "everforest" or "catppuccin"

          -- Check if colorscheme exists before switching
          local ok = pcall(vim.cmd.colorscheme, target_scheme)
          if not ok then
            vim.notify("Colorscheme " .. target_scheme .. " not found, keeping current theme", vim.log.levels.WARN)
          end
        end,
      })

      -- Fix snacks.nvim explorer colors after theme loads
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "everforest",
        callback = function()
          local config = vim.fn["everforest#get_configuration"]()
          local palette = vim.fn["everforest#get_palette"](config.background, config.colors_override)

          -- Get the normal text color
          local grey1_fg = palette.grey1[1]

          -- Override Snacks picker highlight groups for hidden/ignored files
          vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = grey1_fg })
          -- vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { fg = normal_fg })
          -- vim.api.nvim_set_hl(0, "SnacksPickerDirectory", { fg = normal_fg })
          -- vim.api.nvim_set_hl(0, "SnacksPickerFile", { fg = normal_fg })

          -- Fix untracked git file color (default too washed out)
          -- Using grey1 for better visibility while keeping distinction from tracked files
          -- values: grey0, grey1, grey2
          vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { fg = grey1_fg })
        end,
      })
    end,
  },
}
