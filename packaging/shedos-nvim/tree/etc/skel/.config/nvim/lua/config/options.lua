-- Options are automatically loaded before lazy.nvim startup.
-- Defaults that LazyVim always sets:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
--
-- ShedOS keeps this minimal on purpose: prefer LazyVim's defaults and let
-- per-project settings (.editorconfig, LSP, formatter configs) win. Add
-- personal overrides below.

-- Python: use the official pyright (a shedos-meta system package) instead of
-- the AUR-only basedpyright that lang.python defaults to.
vim.g.lazyvim_python_lsp = "pyright"
