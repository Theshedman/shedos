-- ShedOS Neovim runtime. The editor architecture is OS-owned and updates
-- with the system; the home config is a thin shim that loads this file and
-- then the user's own lua/user/.
local uv = vim.uv or vim.loop
local runtime = vim.env.SHEDOS_NVIM_RUNTIME or "/usr/share/shedos/nvim/runtime"
local shipped = vim.env.SHEDOS_NVIM_NO_SHIPPED and "" or "/usr/share/shedos/nvim"

vim.opt.rtp:prepend(runtime)

-- lazy.nvim comes from the shipped tree; the clone is only reached when
-- the package is gone but the config survived.
local lazypath = shipped .. "/plugins/lazy.nvim"
if shipped == "" or not uv.fs_stat(lazypath) then
  lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not uv.fs_stat(lazypath) then
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none",
      "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" } }, true, {})
      os.exit(1)
    end
  end
end
vim.opt.rtp:prepend(lazypath)

-- The dir overrides must precede any entry carrying an import: lazy
-- resolves imports the moment it meets them, so LazyVim's own specs only
-- load if its shipped dir is already known.
local spec = {}
local overlay = shipped .. "/shipped.lua"
if shipped ~= "" and uv.fs_stat(overlay) then
  spec = dofile(overlay)
end
spec[#spec + 1] = { "LazyVim/LazyVim", import = "lazyvim.plugins" }
spec[#spec + 1] = { import = "shedos.plugins" }
if uv.fs_stat(vim.fn.stdpath("config") .. "/lua/user/plugins") then
  spec[#spec + 1] = { import = "user.plugins" }
end

require("lazy").setup({
  spec = spec,
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      -- lazy resets the rtp to config+data; keep the runtime reachable or
      -- the shedos.plugins import and config.* modules silently vanish.
      paths = { runtime },
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "zipPlugin" },
    },
  },
})
