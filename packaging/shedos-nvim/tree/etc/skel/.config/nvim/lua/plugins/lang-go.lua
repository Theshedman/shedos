return {
  -- Extend neotest with Go-specific configuration
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "fredrikaverpil/neotest-golang" },
    opts = {
      adapters = {
        ["neotest-golang"] = {
          go_test_args = { "-v", "-race", "-count=1" },
          testify_enabled = true,
        },
      },
    },
  },

  -- Extend nvim-lspconfig with Go keymaps via gopls on_attach
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      Snacks.util.lsp.on({ name = "gopls" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        -- Generate test for function under cursor (requires gotests)
        map("<leader>jt", function()
          local func_name = vim.fn.expand("<cword>")
          local file = vim.api.nvim_buf_get_name(buffer)
          vim.cmd("!" .. string.format("gotests -only %s -w %s", func_name, file))
          vim.notify("Generated test for " .. func_name, vim.log.levels.INFO)
        end, "Go: Generate test (gotests)")

        -- Add/remove struct tags (requires gomodifytags)
        map("<leader>jg", function()
          local struct_name = vim.fn.expand("<cword>")
          local file = vim.api.nvim_buf_get_name(buffer)
          vim.ui.select({ "add", "remove" }, { prompt = "Struct tags action:" }, function(action)
            if not action then return end
            vim.ui.input({ prompt = "Tag type (json,xml,yaml):", default = "json" }, function(tag)
              if not tag then return end
              local flag = action == "add" and "-add-tags" or "-remove-tags"
              vim.cmd("!" .. string.format("gomodifytags -file %s -struct %s %s %s -w", file, struct_name, flag, tag))
            end)
          end)
        end, "Go: Modify struct tags")

        -- Generate interface implementation (requires impl)
        map("<leader>ji", function()
          vim.ui.input({ prompt = "Receiver (e.g. 's *MyStruct'):" }, function(receiver)
            if not receiver then return end
            vim.ui.input({ prompt = "Interface (e.g. io.Reader):" }, function(iface)
              if not iface then return end
              local result = vim.fn.system(string.format("impl '%s' %s", receiver, iface))
              if vim.v.shell_error ~= 0 then
                vim.notify("impl failed: " .. result, vim.log.levels.ERROR)
                return
              end
              local pos = vim.api.nvim_win_get_cursor(0)
              local lines = vim.split(result, "\n")
              vim.api.nvim_buf_set_lines(buffer, pos[1], pos[1], false, lines)
            end)
          end)
        end, "Go: Implement interface (impl)")

        -- Insert if err != nil block
        map("<leader>je", function()
          local pos = vim.api.nvim_win_get_cursor(0)
          local indent = string.rep("\t", vim.fn.indent(pos[1]) / vim.bo.tabstop)
          local lines = {
            indent .. "if err != nil {",
            indent .. "\treturn err",
            indent .. "}",
          }
          vim.api.nvim_buf_set_lines(buffer, pos[1], pos[1], false, lines)
          vim.api.nvim_win_set_cursor(0, { pos[1] + 2, #indent + 1 })
        end, "Go: Insert if err != nil")

        -- Run current package
        map("<leader>jr", function()
          local dir = vim.fn.expand("%:p:h")
          vim.cmd("!" .. string.format("cd %s && go run .", dir))
        end, "Go: Run package")
      end)
    end,
  },
}
