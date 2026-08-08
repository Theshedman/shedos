-- Enable every language server from the system, out of the box.
--
-- ShedOS ships each of these language servers as a system package that
-- shedos-meta depends on, so it is present on every install and matches the
-- system toolchain. `mason = false` makes LazyVim enable the system binary
-- directly rather than gating the server on a mason-lspconfig install (which
-- only enables servers Mason itself downloaded — so a system-provided server,
-- or any failed download, would silently leave that language with no LSP).
--
-- The payoff: every language has a working LSP on first launch, fully
-- offline; nothing breaks if a Mason download fails; versions match the
-- system compilers/stdlib; and no redundant 25-30 MB downloads. rust-analyzer
-- is already driven from the system by rustaceanvim.
--
-- The lone exception is the web stack (HTML/CSS/JSON) — see lang-web.lua —
-- whose server has no official package and stays on Mason.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- C/C++, Go, Lua, Bash
        clangd = { mason = false },
        gopls = { mason = false },
        lua_ls = { mason = false },
        bashls = { mason = false },
        -- Python (pyright via vim.g.lazyvim_python_lsp), Ruff, YAML, TOML,
        -- Markdown, Zig
        pyright = { mason = false },
        ruff = { mason = false },
        yamlls = { mason = false },
        taplo = { mason = false },
        marksman = { mason = false },
        zls = { mason = false },
        -- TypeScript/JavaScript: the official typescript-language-server,
        -- not the npm-only vtsls that lang.typescript defaults to. lang.typescript
        -- disables ts_ls in favour of vtsls, so re-enable it and disable vtsls.
        ts_ls = { enabled = true, mason = false },
        vtsls = { enabled = false },
      },
    },
  },

  -- The language servers ship as system packages; Mason would duplicate
  -- them per user and hit the network on first open.
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
}
