return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "BufEnter" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        ansible = { "ansible_lint" },
        bash = { "shellcheck" },
        sh = { "shellcheck" },
        cmake = { "cmakelint" },
        c = { "cpplint" },
        cpp = { "cpplint" },
        dockerfile = { "hadolint" },
        gitcommit = { "commitlint" },
        go = { "golangci_lint" },
        html = { "htmlhint" },
        css = { "stylelint" },
        scss = { "stylelint" },
        json = { "jsonlint" },
        java = { "checkstyle" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        kotlin = { "ktlint" },
        markdown = { "markdownlint" },
        python = { "ruff" },
        sql = { "sqlfluff" },
        terraform = { "tflint" },
        yaml = { "yamllint" },
      }

      -- Custom linter configurations
      local cpplint = lint.linters.cpplint
      if cpplint then
        cpplint.args = {
          "--reference_files",
          "--config=" .. vim.fn.expand("~/.config/nvim/CPPLINT.cfg"),
        }
      end

      local golangci = lint.linters.golangcilint or lint.linters.golangci_lint
      if golangci then
        golangci.args = {
          "run", "--out-format", "json",
          "--config=" .. vim.fn.expand("~/.config/nvim/.golangci.yml"),
        }
      end

      local sqlfluff = lint.linters.sqlfluff
      if sqlfluff then
        sqlfluff.args = {
          "lint", "--format=json",
          "--config=" .. vim.fn.expand("~/.config/nvim/.sqlfluff"),
        }
      end

      local checkstyle = lint.linters.checkstyle
      if checkstyle then
        checkstyle.args = {
          "-c", vim.fn.expand("~/.config/nvim/checkstyle.xml"),
        }
      end

      local stylelint = lint.linters.stylelint
      if stylelint then
        stylelint.args = {
          "--formatter", "json",
          "--stdin-filename", "%filepath",
          "--config", vim.fn.expand("~/.config/nvim/.stylelintrc.json"),
        }
      end

      local eslint = lint.linters.eslint_d
      if eslint then
        eslint.args = {
          "--no-warn-ignored",
          "--format", "json",
          "--stdin", "--stdin-filename", "%filepath",
          "--config", vim.fn.expand("~/.config/nvim/.eslintrc.json"),
        }
      end

      -- Auto-trigger linting
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
