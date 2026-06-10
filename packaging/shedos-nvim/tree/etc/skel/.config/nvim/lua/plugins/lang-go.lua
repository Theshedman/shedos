-- Go: format with gofumpt.
--
-- LazyVim's lang.go also lists goimports, but ShedOS doesn't package it (it's
-- AUR-only) and gopls already manages imports — auto-adding them on
-- completion (completeUnimported) and offering an organize-imports code
-- action. Pinning the Go formatter to gofumpt avoids a "formatter not found"
-- notice for the missing goimports.
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        go = { "gofumpt" },
        gomod = { "gofumpt" },
      },
    },
  },
}
