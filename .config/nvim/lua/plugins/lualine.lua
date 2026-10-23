return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- LazyVim's pretty_path collapses paths deeper than 3 segments to "first/…/last/two".
    -- length = 0 shows the full path (relative to the project root).
    opts.sections.lualine_c[4] = { LazyVim.lualine.pretty_path({ length = 0 }) }

    -- "parent/worktree" (e.g. 3/core) in linked git worktrees only.
    -- A linked worktree's .git is a file pointing into the main repo's .git/worktrees/.
    local worktrees = {}
    table.insert(opts.sections.lualine_b, 1, {
      function()
        local root = vim.fs.root(0, ".git")
        if not root then
          return ""
        end
        if worktrees[root] == nil then
          local git = root .. "/.git"
          local linked = vim.fn.filereadable(git) == 1
            and (vim.fn.readfile(git, "", 1)[1] or ""):find("/worktrees/") ~= nil
          worktrees[root] = linked and vim.fn.fnamemodify(root, ":h:t") .. "/" .. vim.fn.fnamemodify(root, ":t") or ""
        end
        return worktrees[root]
      end,
      icon = "",
    })
  end,
}
