-- Debugger install, race-free.
--
-- LazyVim's dap.core extra wires mason-nvim-dap with automatic_installation.
-- On first launch that path runs twice almost at once — once from dap.core's
-- own config and once when rustaceanvim sets up Rust debugging on the first
-- .rs buffer — and the two concurrent codelldb installs make mason throw
-- "Package is already installing". Turn the auto-installer off; the debuggers
-- (codelldb, delve) are already pulled in through Mason's ensure_installed by
-- the lang extras, so one installer runs and nothing races.
return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = { automatic_installation = false },
  },
}
