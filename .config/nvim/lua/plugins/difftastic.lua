return {
  {
    "clabby/difftastic.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "folke/snacks.nvim" },
    cmd = { "Difft", "DifftAll", "DifftPick", "DifftPickRange" },
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

      -- :DifftAll shows staged, unstaged, and untracked (not ignored) changes together: worktree vs HEAD.
      -- The plugin has no such mode, so run its staged diff (HEAD vs index) against a temporary
      -- copy of the index with the whole worktree added. The real index is untouched.
      local function worktree_index()
        local index = vim.trim(vim.system({ "git", "rev-parse", "--git-path", "index" }):wait().stdout or "")
        local tmp = vim.fn.tempname()
        if index == "" or not vim.uv.fs_copyfile(index, tmp) then
          return nil
        end
        if vim.system({ "git", "add", "-A" }, { env = { GIT_INDEX_FILE = tmp } }):wait().code ~= 0 then
          os.remove(tmp)
          return nil
        end
        return tmp
      end

      vim.api.nvim_create_user_command("DifftAll", function()
        local index = worktree_index()
        if not index then
          vim.notify("DifftAll: couldn't build a worktree index (not in a git repo?)", vim.log.levels.ERROR)
          return
        end
        local lib = require("difftastic-nvim.binary").get()
        local tree = require("difftastic-nvim.tree")
        local run_diff_staged, tree_open = lib.run_diff_staged, tree.open
        -- Set GIT_INDEX_FILE only around the library's git calls so nothing else open() spawns sees it
        lib.run_diff_staged = function(vcs)
          local prev = vim.env.GIT_INDEX_FILE
          vim.env.GIT_INDEX_FILE = index
          local ok, result = pcall(run_diff_staged, vcs)
          vim.env.GIT_INDEX_FILE = prev
          if not ok then
            error(result, 0)
          end
          return result
        end
        tree.open = function(state)
          state.range_label = "HEAD → worktree"
          return tree_open(state)
        end
        local ok, err = pcall(difft.open, "--staged")
        lib.run_diff_staged, tree.open = run_diff_staged, tree_open
        os.remove(index)
        if not ok then
          error(err, 0)
        end
      end, { desc = "Difftastic view of staged, unstaged, and untracked changes (worktree vs HEAD)" })

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
