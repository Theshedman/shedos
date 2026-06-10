# ShedOS Neovim

A minimal [LazyVim](https://www.lazyvim.org/) configuration, focused on the
four languages ShedOS targets: **C, C++, Go, and Rust**. Nothing else is
pre-wired — LazyVim's defaults handle the rest, and per-project settings
(`.editorconfig`, `.clang-format`, `.golangci.yml`, `rustfmt.toml`, …) win
over any global config.

## What's included

- **LazyVim core** + the `lang.clangd`, `lang.go`, `lang.rust` and `dap.core`
  extras (LSP, treesitter, formatting, and debugging for the four languages).
- **Claude Code** (`<leader>a…`) via `claudecode.nvim`, driving the `claude`
  CLI that ships with ShedOS.
- **Catppuccin Mocha** to match the desktop.
- **Mason** installs the toolchain on first launch via the language extras —
  `clangd`, `gopls`, `codelldb`, `delve`, the Go/C formatters and
  `golangci-lint`. `rust-analyzer` is used from the system package on `PATH`.
  Update tools any time with `:Mason` (press `U`).

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
