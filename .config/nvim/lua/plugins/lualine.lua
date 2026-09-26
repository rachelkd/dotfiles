return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- LazyVim's pretty_path collapses paths deeper than 3 segments to "first/…/last/two".
    -- length = 0 shows the full path (relative to the project root).
    opts.sections.lualine_c[4] = { LazyVim.lualine.pretty_path({ length = 0 }) }
  end,
}
