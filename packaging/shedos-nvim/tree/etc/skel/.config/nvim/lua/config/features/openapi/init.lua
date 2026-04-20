local M = {}

-- Safe require/setup helper (replaces lsp.helpers dependency)
local function safe_setup(mod_path)
  local ok, mod = pcall(require, mod_path)
  if ok and type(mod) == "table" and mod.setup then
    mod.setup()
  end
end

function M.setup()
  safe_setup("config.features.openapi.core.openapi-ls")
  safe_setup("config.features.openapi.features.preview")
  safe_setup("config.features.openapi.features.codegen")
  safe_setup("config.features.openapi.features.validator")
  safe_setup("config.features.openapi.features.mock-server")
end

-- Auto-detect and setup OpenAPI files
local ok_detect, detection = pcall(require, "config.features.openapi.utils.detection")
if ok_detect and detection.setup_detection_autocmd then
  detection.setup_detection_autocmd(function(bufnr, version)
    M.setup()
    vim.api.nvim_buf_set_var(bufnr, "is_openapi", true)
    vim.api.nvim_buf_set_var(bufnr, "openapi_version", version)
    vim.notify(
      string.format("OpenAPI %s detected in %s", version, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")),
      vim.log.levels.INFO
    )
  end)
end

return M
