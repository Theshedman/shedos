return {
  -- Extend lang.json extra with jq-based keymaps and jqls
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.jqls = {}

      Snacks.util.lsp.on({ name = "jsonls" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        map("<leader>js", function()
          vim.cmd("%!jq -S '.'")
          vim.notify("Sorted JSON keys", vim.log.levels.INFO)
        end, "JSON: Sort keys (jq)")

        map("<leader>jm", function()
          vim.cmd("%!jq -c '.'")
          vim.notify("Minified JSON", vim.log.levels.INFO)
        end, "JSON: Minify (jq)")

        map("<leader>jq", function()
          vim.cmd("%!jq '.'")
          vim.notify("Pretty-printed JSON", vim.log.levels.INFO)
        end, "JSON: Pretty-print (jq)")
      end)
    end,
  },
}
