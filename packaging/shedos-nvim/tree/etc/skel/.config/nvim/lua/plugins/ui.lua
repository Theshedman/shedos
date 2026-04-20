return {
  -- Edgy window management
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>ue", function() require("edgy").toggle() end, desc = "Toggle Edgy" },
      { "<leader>uE", function() require("edgy").select() end, desc = "Edgy Select Window" },
    },
    opts = {
      bottom = {
        { ft = "toggleterm", size = { height = 0.4 }, filter = function(_, win) return vim.api.nvim_win_get_config(win).relative == "" end },
        { ft = "lazyterm", title = "LazyTerm", size = { height = 0.4 }, filter = function(buf) return not vim.b[buf].lazyterm_cmd end },
        "Trouble",
        { ft = "qf", title = "QuickFix" },
        { ft = "help", size = { height = 20 }, filter = function(buf) return vim.bo[buf].buftype == "help" end },
        { title = "Neotest Output", ft = "neotest-output-panel", size = { height = 15 } },
      },
      left = {
        { title = "Explorer", ft = "snacks_explorer", pinned = false, size = { width = 0.25 } },
      },
      right = {
        { title = "Aerial", ft = "aerial", pinned = false, open = "AerialOpen", size = { width = 0.2 } },
        { title = "Grug Far", ft = "grug-far", size = { width = 0.4 } },
      },
      keys = {
        ["<c-Right>"] = function(win) win:resize("width", 2) end,
        ["<c-Left>"] = function(win) win:resize("width", -2) end,
        ["<c-Up>"] = function(win) win:resize("height", 2) end,
        ["<c-Down>"] = function(win) win:resize("height", -2) end,
      },
    },
  },

  -- Noice UI
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = { enabled = true, silent = false },
        signature = {
          enabled = true,
          auto_open = { enabled = true, trigger = true, luasnip = true, throttle = 50 },
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
        lsp_doc_border = true,
      },
      routes = {
        { filter = { event = "msg_show", kind = "", find = "written" }, opts = { skip = true } },
      },
    },
    keys = {
      { "<leader>sn", function() require("noice").cmd("history") end, desc = "Noice: Message History" },
      { "<leader>sl", function() require("noice").cmd("last") end, desc = "Noice: Last Message" },
      { "<leader>sd", function() require("noice").cmd("dismiss") end, desc = "Noice: Dismiss All" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward", mode = { "i", "n", "s" } },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward", mode = { "i", "n", "s" } },
    },
  },

  -- Enhanced notifications
  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 3000,
      max_height = function() return math.floor(vim.o.lines * 0.75) end,
      max_width = function() return math.floor(vim.o.columns * 0.75) end,
      stages = "fade_in_slide_out",
      render = "wrapped-compact",
      background_colour = "#000000",
    },
  },
}
