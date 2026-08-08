-- Debuggers come from system packages (delve, lldb); Mason's DAP installer
-- would duplicate them per user and hit the network on first open.
return {
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      dap.adapters.delve = {
        type = "server",
        host = "127.0.0.1",
        port = 38697,
        executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:38697" } },
      }
    end,
  },
}
