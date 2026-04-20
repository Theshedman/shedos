return {
  -- Silicon screenshot keymaps (loaded at startup)
  {
    "LazyVim/LazyVim",
    init = function()
      local function take_screenshot(range_start, range_end)
        local dir = os.getenv("HOME") .. "/Pictures/Screenshots"
        vim.fn.mkdir(dir, "p")
        local timestamp = os.date("!%Y%m%d_%H%M%S")
        local output = string.format("%s/code_screenshot_%s.png", dir, timestamp)

        if vim.fn.executable("silicon") == 0 then
          vim.notify("Silicon not installed! Install with: cargo install silicon", vim.log.levels.WARN)
          return
        end

        local lines
        if range_start and range_end then
          lines = vim.api.nvim_buf_get_lines(0, range_start - 1, range_end, false)
        else
          lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end

        local filetype = vim.bo.filetype
        local temp_file = vim.fn.tempname()
        vim.fn.writefile(lines, temp_file)

        local cmd = string.format(
          "silicon --output %s --language %s --font 'JetBrainsMono Nerd Font=34' --theme 'Dracula' --shadow-blur-radius 16 --shadow-offset-x 8 --shadow-offset-y 8 --pad-horiz 80 --pad-vert 100 %s",
          vim.fn.shellescape(output),
          vim.fn.shellescape(filetype ~= "" and filetype or "txt"),
          vim.fn.shellescape(temp_file)
        )
        local result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error
        vim.fn.delete(temp_file)

        if exit_code == 0 then
          vim.notify("Screenshot saved to: " .. output, vim.log.levels.INFO)
          if vim.fn.executable("xdg-open") == 1 then
            vim.fn.jobstart({ "xdg-open", output }, { detach = true })
          end
        else
          vim.notify("Failed to create screenshot: " .. result, vim.log.levels.ERROR)
        end
      end

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.schedule(function()
            pcall(vim.keymap.del, "n", "<leader>sC")

            vim.keymap.set("n", "<leader>sC", function() take_screenshot() end, { desc = "Screenshot: Capture File", silent = true })

            vim.keymap.set("v", "<leader>sc", function()
              local start_line = vim.fn.line("v")
              local end_line = vim.fn.line(".")
              if start_line > end_line then start_line, end_line = end_line, start_line end
              take_screenshot(start_line, end_line)
            end, { desc = "Screenshot: Capture Selection", silent = true })

            vim.keymap.set("v", "<leader>sb", function()
              if vim.fn.executable("silicon") == 0 then
                vim.notify("Silicon not installed!", vim.log.levels.WARN)
                return
              end
              if vim.fn.executable("xclip") == 0 then
                vim.notify("xclip not installed!", vim.log.levels.WARN)
                return
              end
              local start_line = vim.fn.line("v")
              local end_line = vim.fn.line(".")
              if start_line > end_line then start_line, end_line = end_line, start_line end
              local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
              local filetype = vim.bo.filetype
              local temp_file = vim.fn.tempname()
              vim.fn.writefile(lines, temp_file)
              local cmd = string.format(
                "silicon --to-clipboard --language %s --font 'JetBrainsMono Nerd Font=34' --theme 'Dracula' --shadow-blur-radius 16 --shadow-offset-x 8 --shadow-offset-y 8 --pad-horiz 80 --pad-vert 100 %s",
                vim.fn.shellescape(filetype ~= "" and filetype or "txt"),
                vim.fn.shellescape(temp_file)
              )
              local result = vim.fn.system(cmd)
              local exit_code = vim.v.shell_error
              vim.fn.delete(temp_file)
              if exit_code == 0 then
                vim.notify("Screenshot copied to clipboard", vim.log.levels.INFO)
              else
                vim.notify("Failed to copy screenshot: " .. result, vim.log.levels.ERROR)
              end
            end, { desc = "Screenshot: Copy to Clipboard", silent = true })
          end)
        end,
      })
    end,
  },
}
