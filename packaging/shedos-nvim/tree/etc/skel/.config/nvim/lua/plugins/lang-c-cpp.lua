return {
  -- C/C++ autocmds: disable auto-format
  {
    "LazyVim/LazyVim",
    init = function()
      local augroup = vim.api.nvim_create_augroup("CCppCustom", { clear = true })

      -- Disable format-on-save for C/C++
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = { "c", "cpp" },
        callback = function()
          vim.b.autoformat = false
          vim.api.nvim_buf_set_option(0, "formatoptions", "tcqj")
        end,
      })

      -- Prevent formatexpr in insert mode
      vim.api.nvim_create_autocmd("InsertEnter", {
        group = augroup,
        pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
        callback = function()
          vim.bo.formatexpr = ""
        end,
      })

      -- Restore formatexpr when leaving insert
      vim.api.nvim_create_autocmd("InsertLeave", {
        group = augroup,
        pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
        callback = function()
          vim.bo.formatexpr = "v:lua.require'conform'.formatexpr()"
        end,
      })
    end,
  },
}
