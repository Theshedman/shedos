return {
  -- Extend lang.terraform extra with workflow keymaps
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      Snacks.util.lsp.on({ name = "terraformls" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        local dir = vim.fn.expand("%:p:h")

        map("<leader>ji", function()
          vim.cmd("!cd " .. dir .. " && terraform init")
        end, "Terraform: init")

        map("<leader>jp", function()
          vim.cmd("!cd " .. dir .. " && terraform plan")
        end, "Terraform: plan")

        map("<leader>jv", function()
          vim.cmd("!cd " .. dir .. " && terraform validate")
        end, "Terraform: validate")
      end)
    end,
  },
}
