-- Treesitter crash guard.
--
-- LazyVim pins nvim-treesitter to its `main` branch, which installs parsers
-- on demand and asynchronously into ~/.local/share/nvim/site/parser/. During
-- that window (and on any partial/ABI-mismatched parser) nvim-treesitter
-- reports a language as "installed" before its compiled `.so` is actually
-- loadable. LazyVim then calls `vim.treesitter.query.get(lang, ...)`, whose
-- memoized inner `parse` runs `assert(vim.treesitter.language.add(lang))` and
-- throws "No parser for language X", crashing the buffer on open. LazyVim
-- pcall-guards its highlight call but not the have_query path
-- (textobjects/indents/folds), so the crash leaks.
--
-- Fix: make `query.get` non-throwing so a not-yet-loadable parser yields nil
-- (treated as "no highlights yet") instead of raising. Highlighting turns on
-- once the parser is ready; a real, loadable parser is unaffected.
--
-- `query.get` is a *memoized table* (vim.func._memoize) — callable via its
-- metatable's __call, and carrying a `:clear()` method that the runtimepath
-- OptionSet autocmd invokes on every plugin load. So we wrap the metatable's
-- __call rather than replacing the table (which would drop `:clear()` and
-- crash on the next rtp change). memoize builds a fresh metatable per call, so
-- this touches only `query.get`. Patching core nvim — not LazyVim's helper —
-- also survives nvim-treesitter's build step, which reloads LazyVim's module.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      local q = vim.treesitter.query
      if q._shedos_guarded then
        return
      end
      local mt = getmetatable(q.get)
      if mt and type(mt.__call) == "function" then
        local call = mt.__call
        mt.__call = function(self, lang, query_name)
          local ok, res = pcall(call, self, lang, query_name)
          if ok then
            return res
          end
          return nil
        end
        q._shedos_guarded = true
      end
    end,
  },
}
