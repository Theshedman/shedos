return {
  -- Neogit
  {
    "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim", "nvim-telescope/telescope.nvim" },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit: Open" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit: Commit" },
      { "<leader>gp", "<cmd>Neogit push<cr>", desc = "Neogit: Push" },
      { "<leader>gl", "<cmd>Neogit pull<cr>", desc = "Neogit: Pull" },
      { "<leader>gb", "<cmd>Neogit branch<cr>", desc = "Neogit: Branch" },
    },
    opts = {
      kind = "tab",
      signs = {
        section = { "", "" },
        item = { "", "" },
        hunk = { "", "" },
      },
      integrations = { telescope = true, diffview = true },
      sections = {
        untracked = { folded = false },
        unstaged = { folded = false },
        staged = { folded = false },
        stashes = { folded = true },
        unpulled = { folded = true },
        unmerged = { folded = false },
        recent = { folded = true },
      },
    },
  },

  -- Diffview
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewRefresh", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: Open" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: File History" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: Branch History" },
    },
    opts = { enhanced_diff_hl = true, use_icons = true },
  },

  -- Git blame
  {
    "f-person/git-blame.nvim",
    event = "VeryLazy",
    opts = {
      enabled = true,
      message_template = " <author> • <date> • <summary>",
      date_format = "%r",
      virtual_text_column = 80,
    },
    keys = {
      { "<leader>gB", "<cmd>GitBlameToggle<cr>", desc = "Git: Toggle Blame" },
    },
  },
}
