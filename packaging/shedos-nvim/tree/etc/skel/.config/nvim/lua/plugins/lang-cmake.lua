return {
  -- Surface cmake-tools.nvim commands under <leader>j, scoped to cmake/c/cpp buffers
  {
    "Civitasv/cmake-tools.nvim",
    optional = true,
    cmd = {
      "CMakeGenerate",
      "CMakeBuild",
      "CMakeRun",
      "CMakeDebug",
      "CMakeSelectBuildType",
      "CMakeSelectBuildTarget",
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("cmake_keymaps", { clear = true }),
        pattern = { "cmake", "c", "cpp" },
        callback = function(args)
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
          end
          map("<leader>jc", "<cmd>CMakeGenerate<cr>", "CMake: Configure (generate)")
          map("<leader>jb", "<cmd>CMakeBuild<cr>", "CMake: Build")
          map("<leader>jr", "<cmd>CMakeRun<cr>", "CMake: Run")
          map("<leader>jd", "<cmd>CMakeDebug<cr>", "CMake: Debug")
          map("<leader>js", "<cmd>CMakeSelectBuildType<cr>", "CMake: Select build type")
          map("<leader>jt", "<cmd>CMakeSelectBuildTarget<cr>", "CMake: Select build target")
        end,
      })
    end,
  },
}
