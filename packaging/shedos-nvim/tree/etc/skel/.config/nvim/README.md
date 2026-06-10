# ShedOS Neovim

A [LazyVim](https://www.lazyvim.org/) configuration that works out of the box
for the languages ShedOS engineers reach for: **C, C++, Go, Rust, Python,
TypeScript/JavaScript, Lua, Bash/sh, Zig**, plus **JSON, YAML, TOML and
Markdown**. Per-project settings (`.editorconfig`, `.clang-format`,
`rustfmt.toml`, `pyproject.toml`, …) always win over the defaults.

## What's included

- **LazyVim core** + language extras for each of the above (LSP, treesitter,
  formatting, debugging). Every language server is enabled by default — see
  below.
- **Claude Code** (`<leader>a…`) via `claudecode.nvim`, driving the `claude`
  CLI that ships with ShedOS.
- **Catppuccin Mocha** to match the desktop.
- **Language servers** all come from ShedOS system packages on `PATH`
  (`clangd`, `gopls`, `rust-analyzer`, `lua-language-server`,
  `bash-language-server`), so every language has a working LSP on first
  launch — offline, and matching the system toolchain. `shfmt`, `shellcheck`
  and `stylua` are system tools too. **Mason** fetches only what ShedOS
  doesn't package: the Go helpers (`gofumpt`, `goimports`, `golangci-lint`)
  and debuggers (`codelldb`, `delve`). Update Mason tools with `:Mason`.

## First launch

Open `nvim`; lazy.nvim bootstraps itself, installs the plugins pinned in
`lazy-lock.json`, and Mason fetches the tools above. Run `:checkhealth` and
`:LazyHealth` to confirm everything is wired up.

## Customising

- Plugin overrides and additions: drop a file in `lua/plugins/`.
- Editor options / keymaps / autocmds: `lua/config/{options,keymaps,autocmds}.lua`.
- Add or remove language extras with `:LazyExtras` (writes `lazyvim.json`).

This config is shipped at `/etc/skel/.config/nvim` and seeded into new users'
homes; the pristine copy lives at `/usr/share/shedos/nvim/defaults` for
`shedman config --sync`.
