return {
  -- Markdown preview
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    -- Use the plugin's own installer: pulls a prebuilt binary when available,
    -- avoiding the npm/yarn lockfile churn that dirties the working tree.
    -- Force-load via lazy's Lua API so the autoload path is on rtp before
    -- calling the install function.
    build = function()
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      vim.fn["mkdp#util#install"]()
    end,
    config = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
    end,
  },

  -- Render markdown in-buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
}
