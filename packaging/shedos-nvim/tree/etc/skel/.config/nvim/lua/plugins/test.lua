return {
  -- Neotest — extend the test.core extra with additional adapters
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "rcasia/neotest-java",
      "nvim-neotest/neotest-jest",
      "alfaix/neotest-gtest",
    },
    keys = {
      { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Test: Run All" },
      { "]T", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next Failed Test" },
      { "[T", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Previous Failed Test" },
    },
    opts = {
      adapters = {
        ["neotest-java"] = {},
        ["neotest-jest"] = {
          jestCommand = "npm test --",
          jestConfigFile = "jest.config.js",
          env = { CI = true },
          cwd = function() return vim.fn.getcwd() end,
        },
        ["neotest-gtest"] = {},
      },
      status = { virtual_text = true },
      output = { open_on_run = true },
    },
  },

  -- Coverage
  {
    "andythigpen/nvim-coverage",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "Coverage", "CoverageLoad", "CoverageShow", "CoverageHide", "CoverageToggle", "CoverageSummary" },
    keys = {
      { "<leader>tc", function() require("coverage").load(true); require("coverage").show() end, desc = "Test: Show Coverage" },
      { "<leader>tC", function() require("coverage").clear() end, desc = "Test: Clear Coverage" },
    },
    opts = {
      commands = true,
      highlights = {
        covered = { fg = "#C3E88D" },
        uncovered = { fg = "#F07178" },
      },
      signs = {
        covered = { hl = "CoverageCovered", text = "▎" },
        uncovered = { hl = "CoverageUncovered", text = "▎" },
      },
      summary = { min_coverage = 80.0 },
      lang = {
        python = { coverage_command = "coverage json --fail-under=0 -q -o -" },
      },
    },
  },
}
