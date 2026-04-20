return {
  -- Surface cmake-tools.nvim commands under <leader>j
  {
    "Civitasv/cmake-tools.nvim",
    optional = true,
    keys = {
      { "<leader>jc", "<cmd>CMakeGenerate<cr>", desc = "CMake: Configure (generate)" },
      { "<leader>jb", "<cmd>CMakeBuild<cr>", desc = "CMake: Build" },
      { "<leader>jr", "<cmd>CMakeRun<cr>", desc = "CMake: Run" },
      { "<leader>jd", "<cmd>CMakeDebug<cr>", desc = "CMake: Debug" },
      { "<leader>js", "<cmd>CMakeSelectBuildType<cr>", desc = "CMake: Select build type" },
      { "<leader>jt", "<cmd>CMakeSelectBuildTarget<cr>", desc = "CMake: Select build target" },
    },
  },
}
