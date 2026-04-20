return {
  -- Extend lang.helm extra with chart workflow keymaps
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      Snacks.util.lsp.on({ name = "helm_ls" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        local function find_chart_root()
          local file = vim.api.nvim_buf_get_name(buffer)
          local chart = vim.fs.find("Chart.yaml", { path = vim.fn.fnamemodify(file, ":h"), upward = true })[1]
          if chart then
            return vim.fn.fnamemodify(chart, ":h")
          end
          return vim.fn.expand("%:p:h")
        end

        map("<leader>jt", function()
          local root = find_chart_root()
          vim.cmd("!cd " .. root .. " && helm template .")
        end, "Helm: template")

        map("<leader>jl", function()
          local root = find_chart_root()
          vim.cmd("!cd " .. root .. " && helm lint .")
        end, "Helm: lint")
      end)
    end,
  },
}
