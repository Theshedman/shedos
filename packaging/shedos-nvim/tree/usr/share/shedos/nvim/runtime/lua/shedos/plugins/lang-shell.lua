-- Shell support: sh/bash and zsh. ShedOS is shell-heavy, so highlight zsh
-- through the bash treesitter grammar (treesitter ships no separate zsh
-- parser) and wire up shfmt formatting and shellcheck linting for sh/bash.
--
-- The bash language server is enabled from the system in lsp-system.lua, and
-- shfmt/shellcheck are system packages on PATH (shedos-meta deps), so conform
-- and nvim-lint invoke them directly — no Mason download needed.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "bash" })
      pcall(vim.treesitter.language.register, "bash", "zsh")
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      },
    },
  },
}
