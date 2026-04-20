return {
  -- Harpoon 2
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add(); vim.notify("File harpooned!", vim.log.levels.INFO) end, desc = "Harpoon: Add file" },
      { "<leader>he", function() local h = require("harpoon"); h.ui:toggle_quick_menu(h:list()) end, desc = "Harpoon: Toggle menu" },
      { "<leader>h1", function() require("harpoon"):list():select(1) end, desc = "Harpoon: File 1" },
      { "<leader>h2", function() require("harpoon"):list():select(2) end, desc = "Harpoon: File 2" },
      { "<leader>h3", function() require("harpoon"):list():select(3) end, desc = "Harpoon: File 3" },
      { "<leader>h4", function() require("harpoon"):list():select(4) end, desc = "Harpoon: File 4" },
      { "<C-S-P>", function() require("harpoon"):list():prev() end, desc = "Harpoon: Previous" },
      { "<C-S-N>", function() require("harpoon"):list():next() end, desc = "Harpoon: Next" },
    },
    opts = {
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
        key = function() return vim.loop.cwd() end,
      },
    },
  },

  -- Flash navigation
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      search = { multi_window = true, forward = true, wrap = true, mode = "exact" },
      jump = { jumplist = true, pos = "start", history = true, register = false, nohlsearch = true, autojump = false },
      label = { uppercase = true, rainbow = { enabled = true, shade = 5 } },
      modes = {
        search = { enabled = true },
        char = { enabled = true, jump_labels = true, multi_line = true },
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>fp", "<cmd>Telescope projects<cr>", desc = "Projects" },
    },
    config = function()
      require("project_nvim").setup({
        detection_methods = { "lsp", "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
        silent_chdir = true,
        scope_chdir = "global",
      })
      require("telescope").load_extension("projects")
    end,
  },
}
