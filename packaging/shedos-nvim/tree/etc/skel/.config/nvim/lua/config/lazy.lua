local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim core and its default plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- ShedOS overrides + the C/C++/Go/Rust language extras (see lazyvim.json)
    { import = "plugins" },
  },
  defaults = {
    -- LazyVim handles lazy-loading for its own plugins; user specs load on
    -- startup unless they opt into an event/cmd/ft.
    lazy = false,
    -- always use the latest git commit; lazy-lock.json pins the versions
    version = false,
  },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = {
    enabled = true, -- periodically check for plugin updates
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
