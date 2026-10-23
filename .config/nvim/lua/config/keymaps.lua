-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>cy", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Copy relative file path" })

-- lazygit writes its final directory to LAZYGIT_NEW_DIR_FILE on quit (Q keeps the old one),
-- so switching worktrees there also moves Neovim's cwd.
vim.keymap.set("n", "<leader>gg", function()
  local cwd, file = LazyVim.root.git(), vim.fn.tempname()
  Snacks.lazygit({
    cwd = cwd,
    env = { LAZYGIT_NEW_DIR_FILE = file },
    win = {
      on_close = function()
        local dir = vim.fn.filereadable(file) == 1 and vim.uv.fs_realpath(vim.fn.readfile(file)[1])
        os.remove(file)
        if dir and dir ~= vim.uv.fs_realpath(cwd) then
          vim.cmd.cd(dir)
        end
      end,
    },
  })
end, { desc = "Lazygit (Root Dir)" })
