return {
  -- Extend lang.tailwind extra with stricter lint settings
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      servers = {
        tailwindcss = {
          settings = {
            tailwindCSS = {
              classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
              lint = {
                invalidApply = "error",
                invalidScreen = "error",
                invalidVariant = "error",
                invalidConfigPath = "error",
                invalidTailwindDirective = "error",
                cssConflict = "warning",
                recommendedVariantOrder = "warning",
              },
            },
          },
        },
      },
    },
  },
}
