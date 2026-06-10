-- Catppuccin Mocha, matching the ShedOS desktop theme.
return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, opts = { flavour = "mocha" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
