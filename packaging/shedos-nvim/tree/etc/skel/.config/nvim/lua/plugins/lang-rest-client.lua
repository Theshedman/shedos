return {
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    keys = {
      { "<leader>rr", "<cmd>lua require('kulala').run()<cr>", desc = "REST: Run Request" },
      { "<leader>ra", "<cmd>lua require('kulala').run_all()<cr>", desc = "REST: Run All Requests" },
      { "<leader>rR", "<cmd>lua require('kulala').replay()<cr>", desc = "REST: Replay Last Request" },
      { "<leader>rn", "<cmd>lua require('kulala').jump_next()<cr>", desc = "REST: Next Request" },
      { "<leader>rp", "<cmd>lua require('kulala').jump_prev()<cr>", desc = "REST: Previous Request" },
      { "<leader>rv", "<cmd>lua require('kulala').toggle_view()<cr>", desc = "REST: Toggle View" },
      { "<leader>ri", "<cmd>lua require('kulala').inspect()<cr>", desc = "REST: Inspect Request" },
      { "<leader>rh", "<cmd>lua require('kulala').show_stats()<cr>", desc = "REST: Show Stats" },
      { "<leader>rc", "<cmd>lua require('kulala').copy()<cr>", desc = "REST: Copy as cURL" },
      { "<leader>re", "<cmd>lua require('kulala').set_selected_env()<cr>", desc = "REST: Select Environment" },
      { "<leader>rE", "<cmd>lua require('kulala').show_env()<cr>", desc = "REST: Show Environment" },
      { "<leader>rs", "<cmd>lua require('kulala').search()<cr>", desc = "REST: Search Requests" },
      { "<leader>rt", "<cmd>lua require('kulala').scratchpad()<cr>", desc = "REST: Open Scratchpad" },
    },
    config = function()
      require("kulala").setup({
        default_view = "body",
        default_env = "dev",
        debug = false,
        formatters = {
          json = { "jq", "." },
          xml = { "xmllint", "--format", "-" },
          html = { "prettier", "--parser", "html" },
        },
        icons = {
          inlay = { loading = "⏳", done = "✅", error = "❌" },
        },
        split_direction = "vertical",
        default_headers = {
          ["Content-Type"] = "application/json",
          ["User-Agent"] = "Kulala.nvim/1.0",
        },
        scratchpad_default_contents = {
          "@baseUrl = http://localhost:8080",
          "",
          "### Quick test request",
          "GET {{baseUrl}}/api/health",
          "Accept: application/json",
          "",
          "###",
        },
        env_dir = vim.fn.stdpath("config") .. "/http-envs",
        display_mode = "split",
        winbar = true,
        show_icons = "on_request",
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "http", "rest" },
        callback = function()
          vim.bo.commentstring = "# %s"
        end,
      })
    end,
  },

  -- HTTP treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "http" })
    end,
  },

  -- Which-key group
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>r", group = "refactor/rest", icon = " " },
      },
    },
  },
}
