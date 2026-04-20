return {
  -- Extend lang.yaml extra with schema-switching keymap
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      Snacks.util.lsp.on({ name = "yamlls" }, function(buffer, client)
        vim.keymap.set("n", "<leader>jy", function()
          vim.ui.input({ prompt = "YAML schema URL:" }, function(schema)
            if not schema or schema == "" then
              return
            end
            local params = {
              settings = {
                yaml = {
                  schemas = { [schema] = vim.api.nvim_buf_get_name(buffer) },
                },
              },
            }
            client.notify("workspace/didChangeConfiguration", params)
            vim.notify("Set YAML schema: " .. schema, vim.log.levels.INFO)
          end)
        end, { buffer = buffer, desc = "YAML: Set schema for buffer" })
      end)
    end,
  },
}
