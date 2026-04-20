return {
  -- Helm LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        helm_ls = {
          settings = {
            ["helm-ls"] = {
              yamlls = {
                enabled = true,
                diagnosticsLimit = 50,
                showDiagnosticsDirectly = false,
                path = "yaml-language-server",
                config = {
                  schemas = { kubernetes = "templates/**" },
                  completion = true,
                  hover = true,
                },
              },
            },
          },
        },
      },
    },
  },
}
