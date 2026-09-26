return {
  {
    "clabby/difftastic.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "folke/snacks.nvim" },
    cmd = { "Difft", "DifftPick", "DifftPickRange" },
    config = function()
      local difft = require("difftastic-nvim")
      difft.setup({
        download = true,
        vcs = "git",
        snacks_picker = { enabled = true },
        -- Match gitsigns' hunk keys in normal buffers
        keymaps = { next_hunk = "]h", prev_hunk = "[h" },
      })

      -- gf normally closes the diff tab before opening the file. Swap its internal close for a
      -- switch to the original tab so the diff stays open and gt returns to it.
      local goto_file = difft.goto_file
      difft.goto_file = function()
        local original_tabpage = difft.state.original_tabpage
        if not (original_tabpage and vim.api.nvim_tabpage_is_valid(original_tabpage)) then
          return goto_file()
        end
        local close = difft.close
        difft.close = function()
          vim.api.nvim_set_current_tabpage(original_tabpage)
        end
        local ok, err = pcall(goto_file)
        difft.close = close
        if not ok then
          error(err)
        end
      end

      -- The plugin sets a diff buffer's filetype after mapping its keys, so LazyVim's
      -- treesitter-textobjects FileType handler overrides ]f/[f. Re-apply them after it.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("difftastic_keymaps", { clear = true }),
        callback = function(ev)
          if ev.buf == difft.state.left_buf or ev.buf == difft.state.right_buf then
            vim.schedule(function()
              require("difftastic-nvim.keymaps").setup(difft.state)
            end)
          end
        end,
      })
    end,
  },
}
