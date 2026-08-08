-- ShedOS Neovim. The editor architecture is system-owned and updates with
-- the OS. Put your own config in lua/user/: init.lua for options and
-- keymaps, plugins/*.lua for extra plugin specs.
local runtime = vim.env.SHEDOS_NVIM_RUNTIME or "/usr/share/shedos/nvim/runtime"
if (vim.uv or vim.loop).fs_stat(runtime .. "/init.lua") then
  dofile(runtime .. "/init.lua")
else
  vim.api.nvim_echo(
    { { "shedos-nvim runtime missing; reinstall shedos-nvim\n", "ErrorMsg" } },
    true, {})
end
pcall(require, "user")
