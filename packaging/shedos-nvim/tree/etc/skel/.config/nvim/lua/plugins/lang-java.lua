return {
  -- Extend the lang.java extra with JPA detection and compile/run keymap
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      local original_on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr)
        if original_on_attach then original_on_attach(client, bufnr) end

        -- Java compile/run keymap (async via Snacks.terminal)
        vim.keymap.set("n", "<leader>jr", function()
          local dir = vim.fn.expand("%:p:h")
          local file = vim.fn.shellescape(vim.fn.expand("%:t"))
          local class = vim.fn.shellescape(vim.fn.expand("%:t:r"))
          Snacks.terminal(string.format("javac %s && java %s", file, class), { cwd = dir })
        end, { buffer = bufnr, desc = "Java: Compile and Run" })

        -- JPA entity-only keymaps (only bound when buffer parses as a JPA entity)
        local ok_parser, parser = pcall(require, "config.features.jpa.parser")
        if ok_parser and parser.is_jpa_entity(bufnr) then
          vim.notify("JPA Entity detected", vim.log.levels.INFO)
          local jmap = function(lhs, cmd, desc)
            vim.keymap.set("n", lhs, cmd, { buffer = bufnr, desc = desc })
          end
          jmap("<leader>jps", "<cmd>JPAGenerateSQL<cr>", "JPA: Generate SQL DDL")
          jmap("<leader>jpS", "<cmd>JPAGenerateProjectSQL<cr>", "JPA: Generate project SQL")
          jmap("<leader>jpR", "<cmd>JPAGenerateRepository<cr>", "JPA: Generate repository")
          jmap("<leader>jpd", "<cmd>JPAGenerateDTO<cr>", "JPA: Generate DTO")
          jmap("<leader>jpc", "<cmd>JPAGenerateController<cr>", "JPA: Generate controller")
          jmap("<leader>jpm", "<cmd>JPAGenerateFlywayMigration<cr>", "JPA: Generate Flyway migration")
          jmap("<leader>jpM", "<cmd>JPAGenerateLiquibaseMigration<cr>", "JPA: Generate Liquibase migration")
          jmap("<leader>jpe", "<cmd>JPAGenerateERD<cr>", "JPA: Generate ERD")
        end
      end
      return opts
    end,
  },

  -- Spring Boot
  {
    "JavaHello/spring-boot.nvim",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-jdtls",
      { "ibhagwan/fzf-lua", optional = true },
      { "nvim-telescope/telescope.nvim", optional = true },
    },
  },
}
