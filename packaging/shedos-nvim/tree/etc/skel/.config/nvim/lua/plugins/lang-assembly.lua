return {
  -- Assembly treesitter parser
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "asm" } } },

  -- asm-lsp config + keymaps
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.asm_lsp = {}

      Snacks.util.lsp.on({ name = "asm_lsp" }, function(buffer, client)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buffer, desc = desc })
        end

        local file = vim.api.nvim_buf_get_name(buffer)
        local base = vim.fn.fnamemodify(file, ":t:r")
        local dir = vim.fn.fnamemodify(file, ":h")
        local ext = vim.fn.fnamemodify(file, ":e")

        -- Assemble current file
        map("<leader>ja", function()
          if ext == "asm" or ext == "nasm" then
            vim.cmd("!" .. string.format("nasm -f elf64 -o %s/%s.o %s", dir, base, file))
          else
            vim.cmd("!" .. string.format("as -o %s/%s.o %s", dir, base, file))
          end
        end, "ASM: Assemble")

        -- Link object file
        map("<leader>jl", function()
          vim.cmd("!" .. string.format("ld -o %s/%s %s/%s.o", dir, base, dir, base))
        end, "ASM: Link")

        -- Assemble + Link + Run
        map("<leader>jr", function()
          local asm_cmd
          if ext == "asm" or ext == "nasm" then
            asm_cmd = string.format("nasm -f elf64 -o %s/%s.o %s", dir, base, file)
          else
            asm_cmd = string.format("as -o %s/%s.o %s", dir, base, file)
          end
          local link_cmd = string.format("ld -o %s/%s %s/%s.o", dir, base, dir, base)
          local run_cmd = string.format("%s/%s", dir, base)
          vim.cmd("!" .. asm_cmd .. " && " .. link_cmd .. " && " .. run_cmd)
        end, "ASM: Assemble + Link + Run")
      end)
    end,
  },
}
