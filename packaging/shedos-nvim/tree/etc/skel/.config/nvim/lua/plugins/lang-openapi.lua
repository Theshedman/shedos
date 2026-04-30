return {
  -- OpenAPI tools via Mason
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      -- spectral-language-server is ensured in lua/plugins/mason-tools.lua

      -- Inject OpenAPI features via LspAttach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end

          local ok_detect, detection = pcall(require, "config.features.openapi.utils.detection")
          if ok_detect then
            local is_openapi, version = detection.is_openapi_file(bufnr)
            if is_openapi then
              vim.b[bufnr].is_openapi = true
              local map_opts = { buffer = bufnr, silent = true }
              vim.keymap.set("n", "<leader>op", "<cmd>OpenAPIPreview swagger<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Preview (Swagger UI)" }))
              vim.keymap.set("n", "<leader>or", "<cmd>OpenAPIPreview redoc<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Preview (ReDoc)" }))
              vim.keymap.set("n", "<leader>of", "<cmd>OpenAPIFloatingPreview<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Floating Preview" }))
              vim.keymap.set("n", "<leader>oP", "<cmd>OpenAPIStopPreview<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Stop Preview" }))
              vim.keymap.set("n", "<leader>og", "<cmd>OpenAPIGenerate<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Generate Code" }))
              vim.keymap.set("n", "<leader>om", "<cmd>OpenAPIMockToggle<cr>", vim.tbl_extend("force", map_opts, { desc = "OpenAPI: Toggle Mock Server" }))
              vim.notify("OpenAPI " .. version .. " detected", vim.log.levels.INFO, { title = "OpenAPI" })
            end
          end
        end,
      })
    end,
  },
}
