-- Custom Go Snippets

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- if err != nil
  s("iferr", fmt([[
if err != nil {{
	return {}
}}
]], {
    i(1, "err"),
  })),

  -- Wrap error
  s("errw", fmt([[
fmt.Errorf("{}: %w", err)
]], {
    i(1, "failed to do something"),
  })),

  -- Table-driven test
  s("tdt", fmt([[
func {}(t *testing.T) {{
	tests := []struct {{
		name string
		{}
	}}{{
		{{
			name: "{}",
			{}
		}},
	}}

	for _, tt := range tests {{
		t.Run(tt.name, func(t *testing.T) {{
			{}
		}})
	}}
}}
]], {
    i(1, "TestSomething"),
    i(2, "// fields"),
    i(3, "test case"),
    i(4, "// values"),
    i(5, "// test body"),
  })),

  -- Benchmark function
  s("bench", fmt([[
func {}(b *testing.B) {{
	for i := 0; i < b.N; i++ {{
		{}
	}}
}}
]], {
    i(1, "BenchmarkSomething"),
    i(2, "// benchmark body"),
  })),

  -- HTTP handler
  s("handler", fmt([[
func {}(w http.ResponseWriter, r *http.Request) {{
	{}
}}
]], {
    i(1, "handleSomething"),
    i(2, "// handler body"),
  })),

  -- HTTP middleware
  s("middleware", fmt([[
func {}(next http.Handler) http.Handler {{
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {{
		{}
		next.ServeHTTP(w, r)
	}})
}}
]], {
    i(1, "middlewareName"),
    i(2, "// middleware logic"),
  })),

  -- Goroutine with errgroup
  s("goroutine", fmt([[
g, ctx := errgroup.WithContext({})
g.Go(func() error {{
	{}
	return nil
}})
if err := g.Wait(); err != nil {{
	return err
}}
]], {
    i(1, "ctx"),
    i(2, "// goroutine body"),
  })),

  -- Context with cancel/timeout
  s("ctx", fmt([[
ctx, cancel := context.{}({}, {})
defer cancel()
]], {
    c(1, {
      t("WithTimeout"),
      t("WithCancel"),
      t("WithDeadline"),
    }),
    i(2, "parentCtx"),
    i(3, "5*time.Second"),
  })),

  -- Interface mock scaffold
  s("mock", fmt([[
type {} struct {{
	{}Func func({}) {}
}}

func (m *{}) {}({}) {} {{
	return m.{}Func({})
}}
]], {
    i(1, "MockService"),
    i(2, "Method"),
    i(3, ""),
    i(4, "error"),
    f(function(args) return args[1][1] end, { 1 }),
    f(function(args) return args[1][1] end, { 2 }),
    f(function(args) return args[1][1] end, { 3 }),
    f(function(args) return args[1][1] end, { 4 }),
    f(function(args) return args[1][1] end, { 2 }),
    i(5, ""),
  })),

  -- Init function
  s("init", fmt([[
func init() {{
	{}
}}
]], {
    i(1, ""),
  })),

  -- Main with signal handling
  s("main", fmt([[
func main() {{
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	{}

	<-ctx.Done()
	log.Println("shutting down...")
}}
]], {
    i(1, "// start services"),
  })),
}
