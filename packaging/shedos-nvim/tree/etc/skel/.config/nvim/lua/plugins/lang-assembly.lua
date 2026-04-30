return {
  -- Assembly treesitter parser
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "asm" } } },

  -- asm-lsp config + keymaps (async via Snacks.terminal)
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

        -- Returns (assemble_cmd, link_cmd, run_cmd, dir) for the *current* buffer.
        -- Resolved per-invocation so it tracks the active buffer.
        local current = function()
          local file = vim.api.nvim_buf_get_name(0)
          local base = vim.fn.fnamemodify(file, ":t:r")
          local dir = vim.fn.fnamemodify(file, ":h")
          local ext = vim.fn.fnamemodify(file, ":e")
          local file_esc = vim.fn.shellescape(file)
          local out_obj = vim.fn.shellescape(dir .. "/" .. base .. ".o")
          local out_bin = vim.fn.shellescape(dir .. "/" .. base)
          local assemble = (ext == "asm" or ext == "nasm")
              and string.format("nasm -f elf64 -o %s %s", out_obj, file_esc)
              or string.format("as -o %s %s", out_obj, file_esc)
          local link = string.format("ld -o %s %s", out_bin, out_obj)
          local run = out_bin
          return assemble, link, run, dir
        end

        map("<leader>ja", function()
          local assemble, _, _, dir = current()
          Snacks.terminal(assemble, { cwd = dir })
        end, "ASM: Assemble")

        map("<leader>jl", function()
          local _, link, _, dir = current()
          Snacks.terminal(link, { cwd = dir })
        end, "ASM: Link")

        map("<leader>jr", function()
          local assemble, link, run, dir = current()
          Snacks.terminal(assemble .. " && " .. link .. " && " .. run, { cwd = dir })
        end, "ASM: Assemble + Link + Run")
      end)
    end,
  },
}
