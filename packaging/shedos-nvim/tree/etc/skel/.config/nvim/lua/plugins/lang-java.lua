return {
  -- Extend the lang.java extra with JPA detection and compile/run keymap
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      local original_on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr)
        if original_on_attach then original_on_attach(client, bufnr) end

        -- Check for JPA entity
        local ok_parser, parser = pcall(require, "config.features.jpa.parser")
        if ok_parser and parser.is_jpa_entity(bufnr) then
          vim.notify("JPA Entity detected", vim.log.levels.INFO)
        end

        -- Java compile/run keymap
        vim.keymap.set("n", "<leader>jr", function()
          local cmd = string.format(
            "cd %s && javac %s && java %s",
            vim.fn.expand("%:p:h"), vim.fn.expand("%:t"), vim.fn.expand("%:t:r")
          )
          vim.cmd("!" .. cmd)
        end, { buffer = bufnr, desc = "Java: Compile and Run" })
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
