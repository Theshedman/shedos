-- Mason install race guard.
--
-- On first launch LazyVim's LSP setup, mason-lspconfig, the lang extras and
-- rustaceanvim all kick off Mason installs at once. mason's Package:install()
-- runs `assert(not self:is_installing())`, so when two callers hit the same
-- package concurrently the second throws "Package is already installing." —
-- and because it surfaces inside lazy.nvim's blocking install_missing, it
-- crashes nvim on first load (the dap/codelldb and lsp variants are the same
-- bug). Make install idempotent: if an install is already in flight, return
-- its handle instead of asserting, so the second caller joins the running
-- install. This neutralises the race at the source for every package — LSP
-- servers, debuggers, formatters, linters — not one extra at a time.
--
-- Applied from mason's `opts` (resolved as the plugin loads, before its
-- config runs any install) so the patch is in place before the first
-- install fires. mason-core.package is on the runtimepath by then.
local function guard_mason()
  local ok, Package = pcall(require, "mason-core.package")
  if not ok or Package._shedos_install_guarded then
    return
  end
  local install = Package.install
  Package.install = function(self, opts, callback)
    if self:is_installing() then
      local handle = self:get_install_handle():get()
      if callback then
        pcall(function()
          handle:once("closed", function()
            callback(self:is_installed(), nil)
          end)
        end)
      end
      return handle
    end
    return install(self, opts, callback)
  end
  Package._shedos_install_guarded = true
end

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      guard_mason()
      -- Install nothing on first launch. Every server runs via mason = false
      -- (lsp-system.lua), and the formatters/linters/debuggers this config
      -- uses are all on PATH from shedos-meta (gofumpt, golangci-lint, shfmt,
      -- shellcheck, stylua, ruff, prettier, eslint, delve, lldb-dap). Clearing
      -- ensure_installed keeps first launch deterministic and offline, with no
      -- npm/pip fetches that can fail. Niche extras (js-debug-adapter,
      -- markdownlint, markdown-toc) are one `:Mason` keystroke away.
      opts.ensure_installed = {}
      return opts
    end,
  },
}
