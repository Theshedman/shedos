return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      default_format_opts = {
        timeout_ms = 3000,
        async = false,
        quiet = true,
        lsp_format = "never",
      },
      notify_on_error = false,
      notify_no_formatters = false,
      format_on_save = nil,

      formatters = {
        stylua = {
          prepend_args = { "--config-path", vim.fn.expand("~/.config/nvim/.stylua.toml") },
        },
        sqlfluff = {
          args = { "format", "--dialect=ansi", "-" },
        },
      },

      formatters_by_ft = {
        lua = { "stylua" },

        -- Web
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        vue = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
        less = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        graphql = { "prettierd", "prettier", stop_after_first = true },
        handlebars = { "prettierd", "prettier", stop_after_first = true },

        -- Python
        python = { "isort", "black" },

        -- Shell
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },

        -- C/C++
        c = { "clang_format", lsp_format = "fallback" },
        cpp = { "clang_format", lsp_format = "fallback" },
        cmake = { "cmakelang" },

        -- Go
        go = { "goimports", "gofumpt", lsp_format = "fallback" },

        -- Java
        java = { "google-java-format", lsp_format = "fallback" },

        -- Kotlin
        kotlin = { lsp_format = "fallback" },

        -- Rust
        rust = { lsp_format = "fallback" },

        -- Terraform
        terraform = { "terraform_fmt" },
        tf = { "terraform_fmt" },

        -- SQL
        sql = { "sqlfluff" },

        -- XML
        xml = { "xmlformatter" },

        -- Assembly
        asm = { "asmfmt" },

        -- Fallback
        ["_"] = { "trim_whitespace" },
      },
    },
  },
}
