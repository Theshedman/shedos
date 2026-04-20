return {
  -- Surround
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {
      keymaps = {
        insert = "<C-g>s",
        insert_line = "<C-g>S",
        normal = "ys",
        normal_cur = "yss",
        normal_line = "yS",
        normal_cur_line = "ySS",
        visual = "S",
        visual_line = "gS",
        delete = "ds",
        change = "cs",
        change_line = "cS",
      },
      aliases = {
        ["a"] = ">",
        ["b"] = ")",
        ["B"] = "}",
        ["r"] = "]",
        ["q"] = { '"', "'", "`" },
        ["s"] = { "}", "]", ")", ">", '"', "'", "`" },
      },
      highlight = { duration = 0 },
      move_cursor = "begin",
    },
  },

  -- Refactoring
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>re", function() require("refactoring").refactor("Extract Function") end, mode = "v", desc = "Extract Function" },
      { "<leader>rf", function() require("refactoring").refactor("Extract Function To File") end, mode = "v", desc = "Extract Function to File" },
      { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, mode = "v", desc = "Extract Variable" },
      { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end, mode = { "n", "v" }, desc = "Inline Variable" },
      { "<leader>rb", function() require("refactoring").refactor("Extract Block") end, desc = "Extract Block" },
      { "<leader>rp", function() require("refactoring").debug.printf({ below = false }) end, desc = "Debug Print" },
      { "<leader>rc", function() require("refactoring").debug.cleanup({}) end, desc = "Debug Cleanup" },
    },
    opts = {
      prompt_func_return_type = { go = false, java = false, cpp = false, c = false, h = false, hpp = false, cxx = false },
      prompt_func_param_type = { go = false, java = false, cpp = false, c = false, h = false, hpp = false, cxx = false },
    },
  },

  -- Dial - smart increment/decrement
  {
    "monaqa/dial.nvim",
    keys = {
      { "<C-a>", function() require("dial.map").manipulate("increment", "normal") end, desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "normal") end, desc = "Decrement" },
      { "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, desc = "Increment (gnormal)" },
      { "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, desc = "Decrement (gnormal)" },
      { "<C-a>", function() require("dial.map").manipulate("increment", "visual") end, mode = "v", desc = "Increment" },
      { "<C-x>", function() require("dial.map").manipulate("decrement", "visual") end, mode = "v", desc = "Decrement" },
      { "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, mode = "v", desc = "Increment (gvisual)" },
      { "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, mode = "v", desc = "Decrement (gvisual)" },
    },
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.date.alias["%Y-%m-%d"],
          augend.date.alias["%Y/%m/%d"],
          augend.date.alias["%m/%d/%Y"],
          augend.constant.alias.bool,
          augend.constant.new({ elements = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "true", "false" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "yes", "no" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "on", "off" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
          augend.constant.new({ elements = { "==", "!=" }, word = false, cyclic = true }),
          augend.constant.new({ elements = { "===", "!==" }, word = false, cyclic = true }),
          augend.hexcolor.new({ case = "lower" }),
          augend.semver.alias.semver,
        },
        typescript = {
          augend.integer.alias.decimal,
          augend.constant.new({ elements = { "let", "const" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "true", "false" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "null", "undefined" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "public", "private", "protected" }, word = true, cyclic = true }),
          augend.hexcolor.new({ case = "lower" }),
        },
        python = {
          augend.integer.alias.decimal,
          augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "and", "or" }, word = true, cyclic = true }),
        },
        markdown = {
          augend.integer.alias.decimal,
          augend.date.alias["%Y-%m-%d"],
          augend.constant.new({ elements = { "TODO", "DONE", "WIP", "FIXME", "NOTE" }, word = true, cyclic = true }),
          augend.constant.new({ elements = { "[ ]", "[x]" }, word = false, cyclic = true }),
        },
      })

      local ft_groups = {
        typescript = "typescript", typescriptreact = "typescript",
        javascript = "typescript", javascriptreact = "typescript",
        python = "python", markdown = "markdown",
      }
      for ft, group in pairs(ft_groups) do
        vim.api.nvim_create_autocmd("FileType", {
          pattern = ft,
          callback = function() vim.api.nvim_buf_set_var(0, "dial_augend_group", group) end,
        })
      end
    end,
  },

  -- LuaSnip — extend the coding.luasnip extra with custom snippets and keymaps
  {
    "L3MON4D3/LuaSnip",
    optional = true,
    opts = {
      history = true,
      delete_check_events = "TextChanged",
      updateevents = "TextChanged,TextChangedI",
    },
    config = function(_, opts)
      -- Let the extra's setup run first
      require("luasnip").setup(opts)

      local luasnip = require("luasnip")

      -- Load custom Lua snippets
      require("luasnip.loaders.from_lua").lazy_load({ paths = vim.fn.stdpath("config") .. "/snippets" })

      luasnip.config.set_config({
        enable_autosnippets = true,
        store_selection_keys = "<Tab>",
      })

      -- Filetype extensions
      luasnip.filetype_extend("go", { "go" })
      luasnip.filetype_extend("java", { "spring-boot", "junit-mockito" })
      luasnip.filetype_extend("typescript", { "express-nestjs" })
      luasnip.filetype_extend("typescriptreact", { "express-nestjs" })
      luasnip.filetype_extend("javascript", { "express-nestjs" })

      -- Snippet navigation
      vim.keymap.set({ "i", "s" }, "<C-k>", function()
        if luasnip.expand_or_jumpable() then luasnip.expand_or_jump() end
      end, { silent = true, desc = "Snippet: Expand or Jump Forward" })

      vim.keymap.set({ "i", "s" }, "<C-j>", function()
        if luasnip.jumpable(-1) then luasnip.jump(-1) end
      end, { silent = true, desc = "Snippet: Jump Backward" })

      vim.keymap.set({ "i", "s" }, "<C-l>", function()
        if luasnip.choice_active() then luasnip.change_choice(1) end
      end, { silent = true, desc = "Snippet: Change Choice" })

      vim.keymap.set("n", "<leader>cs", function()
        require("luasnip.loaders").edit_snippet_files()
      end, { desc = "Code: Edit Snippets" })
    end,
  },
}
