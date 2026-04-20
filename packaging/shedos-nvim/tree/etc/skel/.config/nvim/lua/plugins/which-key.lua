return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>h", group = "harpoon" },
        { "<leader>t", group = "test" },
        { "<leader>g", group = "git" },
        { "<leader>o", group = "openapi" },
        { "<leader>j", group = "lang actions" },
      },
    },
  },
}
