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
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          on_init = function(client)
            local libs = {
              vim.env.VIMRUNTIME,
            }
            -- Add all installed lazy.nvim plugin lua/ directories
            local lazy_path = vim.fn.stdpath("data") .. "/lazy"
            for _, name in ipairs({ "LazyVim", "snacks.nvim", "lazy.nvim" }) do
              local p = lazy_path .. "/" .. name .. "/lua"
              if vim.uv.fs_stat(p) then
                libs[#libs + 1] = p
              end
            end
            client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
              workspace = {
                library = libs,
              },
            })
            client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
          end,
        },
      },
    },
  },
}
