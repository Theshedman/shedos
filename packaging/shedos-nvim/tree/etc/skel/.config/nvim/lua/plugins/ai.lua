-- Claude Code integration. Drives the `claude` CLI on PATH (shipped by
-- ShedOS). https://github.com/coder/claudecode.nvim
return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude: Toggle" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude: Focus" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Claude: Resume" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude: Continue" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: Add Buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: Send Selection" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: Accept Diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: Deny Diff" },
    },
  },
}
