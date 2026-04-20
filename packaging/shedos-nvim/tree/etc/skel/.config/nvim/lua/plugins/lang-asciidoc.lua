return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "asciidoc" })
    end,
  },

  { "habamax/vim-asciidoctor", ft = { "asciidoc", "asciidoctor" } },
}
