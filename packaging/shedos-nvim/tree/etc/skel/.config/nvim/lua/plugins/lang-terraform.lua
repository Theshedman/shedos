return {
  -- Extend lang.terraform extra with workflow keymaps (async via Snacks.terminal)
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      Snacks.util.lsp.on({ name = "terraformls" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        local run = function(action)
          Snacks.terminal("terraform " .. action, { cwd = vim.fn.expand("%:p:h") })
        end

        map("<leader>ji", function() run("init") end, "Terraform: init")
        map("<leader>jp", function() run("plan") end, "Terraform: plan")
        map("<leader>jv", function() run("validate") end, "Terraform: validate")
      end)
    end,
  },
}
