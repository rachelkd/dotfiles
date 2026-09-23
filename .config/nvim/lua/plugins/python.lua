-- Python LSP: ty (types) + ruff (lint/format), mirroring the Zed setup.
--
-- Both servers are pinned in the project's pyproject.toml/uv.lock, so we launch
-- them from the project's own .venv instead of Mason. Mason's copies drift from
-- the versions CI runs, which shows up as phantom lint diagnostics.

--- Build a `cmd` function that resolves `exe` from the nearest .venv above the
--- LSP root, falling back to $PATH. Resolution happens per client, so each k env
--- worktree (and ~/core) gets its own venv without any per-project config.
---@param exe string
---@param args string[]
local function venv_cmd(exe, args)
  return function(dispatchers, config)
    local root = config.root_dir or assert(vim.uv.cwd())
    local cmd, env = exe, nil
    local venv = vim.fs.find(".venv", { path = root, upward = true, type = "directory" })[1]
    if venv and vim.uv.fs_stat(venv .. "/bin/" .. exe) then
      cmd = venv .. "/bin/" .. exe
      -- ty locates third-party stubs via VIRTUAL_ENV.
      env = { VIRTUAL_ENV = venv, PATH = venv .. "/bin:" .. vim.env.PATH }
    end
    return vim.lsp.rpc.start(vim.list_extend({ cmd }, args), dispatchers, { cwd = root, env = env })
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.ty = vim.tbl_deep_extend("force", opts.servers.ty or {}, {
        enabled = true,
        mason = false,
        cmd = venv_cmd("ty", { "server" }),
      })

      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        enabled = true,
        mason = false,
        cmd = venv_cmd("ruff", { "server" }),
      })

      -- Zed's "!basedpyright". LazyVim's python extra enables pyright by
      -- default; this runs after it, so it has the final say.
      for _, server in ipairs({ "pyright", "basedpyright", "ruff_lsp" }) do
        opts.servers[server] = opts.servers[server] or {}
        opts.servers[server].enabled = false
      end
    end,
  },
}
