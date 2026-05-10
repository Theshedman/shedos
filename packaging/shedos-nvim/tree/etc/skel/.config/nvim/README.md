# Neovim Configuration

A LazyVim-based Neovim configuration tailored for backend and full-stack development.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?style=flat&logo=neovim&logoColor=white)
![LazyVim](https://img.shields.io/badge/LazyVim-Plugin%20Manager-2C68F6?style=flat)
![Lua](https://img.shields.io/badge/Lua-Config-2C2D72?style=flat&logo=lua&logoColor=white)

<!-- Add a screenshot here -->

## Features

- **LazyVim** base with 25 extras (languages, DAP, testing, coding, editor)
- **21+ language support** with LSP, formatting, linting, and debugging
- **Custom JPA Buddy++** tooling — entity parsing, DDL generation, migrations, repository/DTO/controller scaffolding, ERD diagrams
- **Custom OpenAPI** tooling — Spectral validation, Swagger UI / ReDoc preview, code generation (25+ targets), mock server (Prism)
- **REST client** (Kulala) with environment support (dev/staging/prod) and HTTP templates
- **AI integration** via Claude Code
- **119 mason-managed tools** — 50 LSPs, 19 linters, 18 formatters, 9 debuggers
- **Custom snippets** for Java/Spring Boot, JUnit/Mockito, TypeScript/Express/NestJS, and Go
- **Zen mode**, Harpoon, Neogit, Diffview, Neotest, nvim-coverage, toggleterm, nvim-surround, refactoring.nvim

## Requirements

| Requirement | Purpose |
| --- | --- |
| [Neovim](https://neovim.io/) >= 0.10 | Editor |
| [Git](https://git-scm.com/) | Plugin management, Neogit |
| [Node.js](https://nodejs.org/) | LSP servers, formatters, OpenAPI tools |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Telescope live grep |
| [fd](https://github.com/sharkdp/fd) | Telescope file finder |
| [A Nerd Font](https://www.nerdfonts.com/) | Icons throughout the UI |
| Language toolchains | Java (JDK), Go, Python, Rust, C/C++ as needed |
| [silicon](https://github.com/Aloxaf/silicon) | Code screenshots (optional) |

## Installation

```bash
# Back up existing config
mv ~/.config/nvim ~/.config/nvim.bak

# Clone this repository
git clone https://github.com/<your-username>/nvim.git ~/.config/nvim

# Launch Neovim; Lazy and Mason will auto-install everything
nvim
```

On first launch, Lazy installs all plugins and Mason installs all configured tools. This may take a few minutes.

## Project Structure

```text
~/.config/nvim/
├── init.lua                          # Entry point — loads config.lazy
├── lazyvim.json                      # Enabled LazyVim extras
├── lua/
│   ├── config/
│   │   ├── lazy.lua                  # Lazy.nvim bootstrap and plugin spec
│   │   ├── options.lua               # Editor options and diagnostics
│   │   ├── keymaps.lua               # Global custom keymaps
│   │   ├── autocmds.lua              # Autocommands
│   │   └── features/
│   │       ├── jpa/                  # JPA Buddy++ (8 files)
│   │       │   ├── init.lua          #   Commands and orchestration
│   │       │   ├── parser.lua        #   Entity parsing and type mapping
│   │       │   ├── generator.lua     #   SQL DDL generation (6 dialects)
│   │       │   ├── migration.lua     #   Flyway / Liquibase migrations
│   │       │   ├── dto.lua           #   DTO generation
│   │       │   ├── repository.lua    #   Spring Data repository scaffolding
│   │       │   ├── controller.lua    #   REST controller scaffolding
│   │       │   └── documentation.lua #   ERD generation (PlantUML / Mermaid)
│   │       └── openapi/              # OpenAPI tooling (7 files)
│   │           ├── init.lua          #   Auto-detection and setup
│   │           ├── core/
│   │           │   └── openapi-ls.lua#   YAML LS + Spectral LSP config
│   │           ├── features/
│   │           │   ├── preview.lua   #   Swagger UI / ReDoc live preview
│   │           │   ├── codegen.lua   #   Client/server code generation
│   │           │   ├── validator.lua #   Spectral validation and rulesets
│   │           │   └── mock-server.lua#  Prism mock server
│   │           └── utils/
│   │               └── detection.lua #   OpenAPI file detection
│   └── plugins/                      # Plugin specs (33 files)
│       ├── ai.lua                    #   Claude Code
│       ├── coding.lua                #   Surround, refactoring, dial, LuaSnip
│       ├── colorscheme.lua           #   Catppuccin (mocha)
│       ├── disabled.lua              #   Disabled features
│       ├── editor.lua                #   Zen mode, twilight, UFO folds, auto-save
│       ├── formatting.lua            #   conform.nvim formatter config
│       ├── git.lua                   #   Neogit, Diffview, git-blame
│       ├── lang-*.lua                #   Language-specific configs (19 files)
│       ├── linting.lua               #   nvim-lint linter config
│       ├── mason-tools.lua           #   Mason tool installer (119 tools)
│       ├── navigation.lua            #   Harpoon, Flash, project.nvim
│       ├── terminal.lua              #   toggleterm
│       ├── test.lua                  #   Neotest, nvim-coverage
│       ├── ui.lua                    #   Edgy, Noice, nvim-notify
│       └── which-key.lua             #   Key group labels
├── snippets/                         # LuaSnip custom snippets
│   ├── java.lua                      #   Core Java snippets
│   ├── spring-boot.lua               #   Spring Boot snippets
│   ├── junit-mockito.lua             #   JUnit 5 / Mockito snippets
│   ├── typescript.lua                #   TypeScript snippets
│   ├── express-nestjs.lua            #   Express / NestJS snippets
│   └── go.lua                        #   Go snippets
├── http-envs/                        # Kulala REST client environments
│   ├── dev.json
│   ├── staging.json
│   └── prod.json
├── http-templates/                   # HTTP request templates
│   ├── api-template.http
│   └── http-client.env.json
└── (config files)                    # Linter/formatter configs at root
```

## Language Support

| Language | LSP | Formatter | Linter | Debugger |
| --- | --- | --- | --- | --- |
| Java | jdtls | google-java-format | checkstyle | java-debug-adapter, java-test |
| Kotlin | kotlin-language-server | ktlint | ktlint | kotlin-debug-adapter |
| Go | gopls | goimports, gofumpt | golangci-lint | delve |
| TypeScript / JavaScript | vtsls, ts_ls, eslint-lsp | prettierd | eslint_d | js-debug-adapter |
| Python | pyright, ruff | black, isort | ruff, flake8 | debugpy |
| Rust | rust-analyzer | (LSP) | — | codelldb |
| C / C++ | clangd | clang-format | cpplint | cpptools, codelldb |
| Lua | lua-language-server | stylua | — | — |
| Bash / Shell | bash-language-server | shfmt | shellcheck | bash-debug-adapter |
| SQL | sqls, postgres-language-server | sqlfluff | sqlfluff | — |
| HTML | html-lsp, emmet-ls, htmx-lsp | prettierd | htmlhint | — |
| CSS / SCSS | css-lsp, css-variables-ls, cssmodules-ls | prettierd | stylelint | — |
| TailwindCSS | tailwindcss-language-server | — | — | — |
| JSON | json-lsp, jq-lsp, jsonld-lsp | prettierd | jsonlint | — |
| YAML | yaml-language-server | yamlfmt | yamllint | — |
| TOML | taplo | — | — | — |
| Markdown | marksman | prettierd | markdownlint | — |
| Docker | dockerfile-language-server, docker-compose-ls | — | hadolint | — |
| Terraform | terraform-ls | terraform_fmt | tflint | — |
| Ansible | ansible-language-server | — | ansible-lint | — |
| Helm | helm-ls | — | — | — |
| Zig | zls | — | — | — |
| CMake | neocmakelsp, cmake-language-server | cmakelang | cmakelint | — |
| Angular | angular-language-server | prettierd | eslint_d | — |
| Vue | vue-language-server | prettierd | eslint_d | — |
| Svelte | svelte-language-server | prettierd | eslint_d | — |
| AsciiDoc | — (treesitter) | — | — | — |
| Assembly (NASM/GAS) | asm-lsp | asmfmt | — | — |
| Kubernetes | helm-ls | — | — | — |

## LazyVim Extras

The following extras are enabled in `lazyvim.json`:

**Languages:** Java, TypeScript, Go, Python, Rust, C/C++ (clangd), Kotlin (manual), Angular, Vue, Svelte, Tailwind, Zig, JSON, YAML, TOML, Markdown, Docker, Helm, Ansible, Terraform, Git

**Tooling:** `test.core`, `dap.core`, `coding.luasnip`, `editor.aerial`

## Plugin Overview

### Editor

| Plugin | Description |
| --- | --- |
| [zen-mode.nvim](https://github.com/folke/zen-mode.nvim) | Distraction-free writing (120-char width) |
| [twilight.nvim](https://github.com/folke/twilight.nvim) | Dim inactive code blocks |
| [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo) | Modern fold management with treesitter |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | Highlight and search TODO/FIXME/HACK comments |
| [auto-save.nvim](https://github.com/okuuva/auto-save.nvim) | Auto-save with 135ms debounce |
| [nvim-bqf](https://github.com/kevinhwang91/nvim-bqf) | Better quickfix window with preview |

### Navigation

| Plugin | Description |
| --- | --- |
| [harpoon](https://github.com/ThePrimeagen/harpoon) (v2) | Quick file marks and navigation |
| [flash.nvim](https://github.com/folke/flash.nvim) | Jump anywhere with search labels |
| [project.nvim](https://github.com/ahmedkhalf/project.nvim) | Auto-detect project root (LSP, .git, package.json) |

### UI

| Plugin | Description |
| --- | --- |
| [catppuccin](https://github.com/catppuccin/nvim) | Mocha flavor with transparent background |
| [edgy.nvim](https://github.com/folke/edgy.nvim) | Window layout management (sidebars, panels) |
| [noice.nvim](https://github.com/folke/noice.nvim) | Replaces cmdline, messages, and popupmenu |
| [nvim-notify](https://github.com/rcarriga/nvim-notify) | Notification popups |

### Git

| Plugin | Description |
| --- | --- |
| [neogit](https://github.com/NeogitOrg/neogit) | Magit-style Git interface |
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | Tabpage diff viewer and file history |
| [git-blame.nvim](https://github.com/f-person/git-blame.nvim) | Inline git blame |

### Terminal

| Plugin | Description |
| --- | --- |
| [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | Floating, horizontal, and vertical terminals |

### Coding

| Plugin | Description |
| --- | --- |
| [nvim-surround](https://github.com/kylechui/nvim-surround) | Add/change/delete surrounding pairs |
| [refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim) | Extract function/variable, inline variable |
| [dial.nvim](https://github.com/monaqa/dial.nvim) | Enhanced increment/decrement (booleans, dates, semver, etc.) |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip) | Snippet engine with custom snippets |

### Testing

| Plugin | Description |
| --- | --- |
| [neotest](https://github.com/nvim-neotest/neotest) | Test runner (Java, Jest, GTest, Go adapters) |
| [nvim-coverage](https://github.com/andythigpen/nvim-coverage) | Code coverage display (80% threshold) |

### AI

| Plugin | Description |
| --- | --- |
| [claudecode.nvim](https://github.com/coder/claudecode.nvim) | Claude Code integration |

### Language-Specific

| Plugin | Description |
| --- | --- |
| [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) | Java LSP with Spring Boot support |
| [spring-boot.nvim](https://github.com/JavaHello/spring-boot.nvim) | Spring Boot integration |
| [kulala.nvim](https://github.com/mistweaverco/kulala.nvim) | REST client with environment support |
| [vim-dadbod](https://github.com/tpope/vim-dadbod) + UI | Database client and query runner |
| [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) | Live markdown preview in browser |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | Inline markdown rendering |
| [vim-asciidoctor](https://github.com/habamax/vim-asciidoctor) | AsciiDoc support |

## Key Bindings

> `<leader>` is `Space` (LazyVim default).

### General

| Key | Mode | Description |
| --- | --- | --- |
| `jk` / `kj` | Insert | Escape to normal mode |
| `<C-s>` | Normal / Insert | Save file |
| `<A-j>` / `<A-k>` | Normal / Visual | Move line(s) down / up |
| `<` / `>` | Visual | Indent and reselect |
| `p` | Visual | Paste without yanking replaced text |
| `<leader>d` | Normal / Visual | Delete without yanking |
| `<C-d>` / `<C-u>` | Normal | Half-page down / up (centered) |
| `<C-Up/Down/Left/Right>` | Normal | Resize windows |
| `<leader>ci` | Normal | Toggle inline diagnostics |
| `[d` / `]d` | Normal | Previous / next diagnostic |
| `[e` / `]e` | Normal | Previous / next error |

### Navigation Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>ha` | Normal | Harpoon: add file |
| `<leader>he` | Normal | Harpoon: toggle menu |
| `<leader>h1`–`h4` | Normal | Harpoon: jump to file 1–4 |
| `<C-S-P>` / `<C-S-N>` | Normal | Harpoon: previous / next |
| `s` | Normal / Visual / Operator | Flash: jump |
| `S` | Normal / Visual / Operator | Flash: treesitter select |
| `r` | Operator | Flash: remote |
| `<leader>fp` | Normal | Switch project |

### Git Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>gg` | Normal | Neogit: open |
| `<leader>gc` | Normal | Neogit: commit |
| `<leader>gp` | Normal | Neogit: push |
| `<leader>gl` | Normal | Neogit: pull |
| `<leader>gb` | Normal | Neogit: branch |
| `<leader>gd` | Normal | Diffview: open |
| `<leader>gh` | Normal | Diffview: file history |
| `<leader>gH` | Normal | Diffview: branch history |
| `<leader>gB` | Normal | Toggle git blame |

### Testing Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>ta` | Normal | Run all tests |
| `]T` / `[T` | Normal | Next / previous failed test |
| `<leader>tc` | Normal | Show coverage |
| `<leader>tC` | Normal | Clear coverage |

### Terminal Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<C-\>` | Normal | Toggle terminal |
| `<leader>tf` | Normal | Float terminal |
| `<leader>th` | Normal | Horizontal terminal |
| `<leader>tv` | Normal | Vertical terminal |
| `<Esc>` / `jk` | Terminal | Exit terminal mode |

### Language Actions (`<leader>j`)

| Key | Mode | Language | Description |
| --- | --- | --- | --- |
| `<leader>jr` | Normal | Java | Compile and run |
| `<leader>jr` | Normal | Go | Run package |
| `<leader>jt` | Normal | Go | Generate test (gotests) |
| `<leader>jg` | Normal | Go | Modify struct tags |
| `<leader>ji` | Normal | Go | Implement interface |
| `<leader>je` | Normal | Go | Insert `if err != nil` |
| `<leader>js` | Normal | JSON | Sort keys (jq) |
| `<leader>jm` | Normal | JSON | Minify (jq) |
| `<leader>jq` | Normal | JSON | Pretty-print (jq) |
| `<leader>jy` | Normal | YAML | Set schema for buffer |
| `<leader>ji` | Normal | Terraform | `terraform init` |
| `<leader>jp` | Normal | Terraform | `terraform plan` |
| `<leader>jv` | Normal | Terraform | `terraform validate` |
| `<leader>jt` | Normal | Helm | `helm template` |
| `<leader>jl` | Normal | Helm | `helm lint` |
| `<leader>jc` | Normal | CMake | Configure (generate) |
| `<leader>jb` | Normal | CMake | Build |
| `<leader>jr` | Normal | CMake | Run |
| `<leader>jd` | Normal | CMake | Debug |
| `<leader>js` | Normal | CMake | Select build type |
| `<leader>jt` | Normal | CMake | Select build target |
| `<leader>ja` | Normal | Assembly | Assemble (NASM/GAS) |
| `<leader>jl` | Normal | Assembly | Link object file |
| `<leader>jr` | Normal | Assembly | Assemble + Link + Run |

### REST Client (`<leader>r`)

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>rr` | Normal | Run request |
| `<leader>ra` | Normal | Run all requests |
| `<leader>rR` | Normal | Replay last request |
| `<leader>rn` / `rp` | Normal | Next / previous request |
| `<leader>rv` | Normal | Toggle response view |
| `<leader>ri` | Normal | Inspect request |
| `<leader>rh` | Normal | Show stats |
| `<leader>rc` | Normal | Copy as cURL |
| `<leader>re` | Normal | Select environment |
| `<leader>rE` | Normal | Show environment |
| `<leader>rs` | Normal | Search requests |
| `<leader>rt` | Normal | Open scratchpad |

### OpenAPI Tools (`<leader>o`)

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>op` | Normal | Preview (Swagger UI) |
| `<leader>or` | Normal | Preview (ReDoc) |
| `<leader>of` | Normal | Floating preview |
| `<leader>oP` | Normal | Stop preview |
| `<leader>og` | Normal | Generate code |
| `<leader>om` | Normal | Toggle mock server |

### Refactoring (`<leader>r`)

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>re` | Visual | Extract function |
| `<leader>rf` | Visual | Extract function to file |
| `<leader>rv` | Visual | Extract variable |
| `<leader>ri` | Normal / Visual | Inline variable |
| `<leader>rb` | Normal | Extract block |
| `<leader>rp` | Normal | Debug print |
| `<leader>rc` | Normal | Debug cleanup |

### Editor Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>z` | Normal | Zen mode |
| `<leader>T` | Normal | Twilight (dim inactive code) |
| `<leader>ua` | Normal | Toggle auto-save |
| `<leader>ue` | Normal | Toggle edgy panels |
| `zR` / `zM` | Normal | Open / close all folds |
| `zp` | Normal | Peek fold |
| `]t` / `[t` | Normal | Next / previous TODO comment |

### Snippet Keys

| Key | Mode | Description |
| --- | --- | --- |
| `<C-k>` | Insert / Select | Expand snippet or jump forward |
| `<C-j>` | Insert / Select | Jump backward |
| `<C-l>` | Insert / Select | Change choice node |
| `<leader>cs` | Normal | Edit snippets |

### Screenshots

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>sC` | Normal | Screenshot: capture file |
| `<leader>sc` | Visual | Screenshot: capture selection |
| `<leader>sb` | Visual | Screenshot: copy to clipboard |

### AI (Claude Code)

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>ac` | Normal | Toggle Claude Code |
| `<leader>af` | Normal | Focus Claude Code |
| `<leader>ar` | Normal | Resume conversation |
| `<leader>aC` | Normal | Continue |
| `<leader>am` | Normal | Select model |
| `<leader>ab` | Normal | Add current buffer |
| `<leader>as` | Visual | Send selection |
| `<leader>aa` | Normal | Accept diff |
| `<leader>ad` | Normal | Deny diff |

## Custom Features

### JPA Buddy++

A complete JPA/Hibernate entity toolkit built in Lua. Parses `@Entity` annotations and generates boilerplate.

**Commands:**

| Command | Description |
| --- | --- |
| `:JPAGenerateSQL [dialect]` | Generate SQL DDL from current entity |
| `:JPAGenerateProjectSQL` | Generate DDL for all project entities |
| `:JPAGenerateRepository` | Scaffold a Spring Data JPA repository |
| `:JPAGenerateDTO` | Generate a Lombok DTO with conversion method |
| `:JPAGenerateController` | Scaffold a REST controller with CRUD endpoints |
| `:JPAGenerateFlywayMigration` | Generate a Flyway migration file |
| `:JPAGenerateLiquibaseMigration` | Generate a Liquibase changeset |
| `:JPAGenerateERD [plantuml\|mermaid]` | Generate an Entity Relationship Diagram |

**Supported SQL dialects:** PostgreSQL, MySQL, Oracle, SQL Server, H2, SQLite

**What it parses:** `@Entity`, `@Table`, `@Column`, `@Id`, `@GeneratedValue`, `@Enumerated`, `@OneToOne`, `@OneToMany`, `@ManyToOne`, `@ManyToMany`

**What it generates:**

- CREATE TABLE statements with proper type mapping per dialect
- Foreign key constraints and join tables for relationships
- Timestamped Flyway migrations (`V{timestamp}__create_{table}.sql`)
- Liquibase XML changesets
- DTOs with `@Data`, `@NoArgsConstructor`, `@AllArgsConstructor` and `fromEntity()` method
- Repository interfaces with custom `findBy` methods for unique fields
- REST controllers with `@RequiredArgsConstructor` and full CRUD
- ERD diagrams with relationship cardinality in PlantUML or Mermaid

### OpenAPI Development Tools

A full OpenAPI development workflow inside Neovim.

**Commands:**

| Command | Description |
| --- | --- |
| `:OpenAPIPreview [swagger\|redoc]` | Start live preview server |
| `:OpenAPIStopPreview` | Stop preview server |
| `:OpenAPIFloatingPreview` | Preview in floating window |
| `:OpenAPIGenerate` | Interactive code generation wizard |
| `:OpenAPIGenerateClient <lang>` | Generate client SDK |
| `:OpenAPIGenerateServer <lang>` | Generate server stub |
| `:OpenAPIValidate` | Validate with Spectral |
| `:OpenAPILint` | Lint OpenAPI spec |
| `:OpenAPIValidateStats` | Show validation statistics |
| `:OpenAPICreateRuleset` | Create default Spectral ruleset |
| `:OpenAPIMockStart` | Start Prism mock server |
| `:OpenAPIMockStop` | Stop mock server |
| `:OpenAPIMockToggle` | Toggle mock server |
| `:OpenAPIMockList` | List running mock servers |
| `:OpenAPIMockTest [endpoint] [method]` | Test a mock endpoint |

**Supported code generation targets:**

- **Clients:** Java, Kotlin, TypeScript (fetch/axios), JavaScript, Python, Go, Rust, C#, PHP, Ruby, Swift, Dart
- **Servers:** Spring, Kotlin Spring, Express, NestJS, Flask, FastAPI, Go, Gin, Rust, ASP.NET Core, Laravel, Rails

**Auto-detection:** OpenAPI 3.0, OpenAPI 3.1, and Swagger 2.0 files are detected automatically by filename pattern and content inspection.

## Snippets

### Java Snippets

| Trigger | Description |
| --- | --- |
| `controller` | Spring REST controller with CRUD |
| `service` | Spring service class |
| `log` | SLF4J logger field |
| `exhandler` | Exception handler with ResponseEntity |
| `test` | JUnit test (Given-When-Then) |

### Spring Boot

| Trigger | Description |
| --- | --- |
| `sbrc` | `@RestController` with CRUD endpoints |
| `sbserv` | `@Service` with repository and CRUD |
| `sbent` | `@Entity` with id and timestamps |
| `sbconf` | `@Configuration` with `@Bean` |
| `sbprop` | `@ConfigurationProperties` class |
| `sbex` | Custom exception |
| `sbadvice` | `@RestControllerAdvice` exception handler |
| `sbrepo` | `@Repository` JpaRepository interface |

### JUnit 5 / Mockito

| Trigger | Description |
| --- | --- |
| `junit5` | Full test class with Mockito |
| `jtest` | Single `@Test` method (AAA) |
| `when` | `when().thenReturn()` |
| `verify` | `verify()` assertion |
| `captor` | ArgumentCaptor setup |
| `before` / `after` | `@BeforeEach` / `@AfterEach` |
| `paramtest` | `@ParameterizedTest` with `@ValueSource` |
| `nested` | `@Nested` test class |
| `assertj` | AssertJ assertion chain |
| `dothrow` | `doThrow().when()` |
| `donothing` | `doNothing().when()` |
| `springtest` | `@SpringBootTest` with MockMvc |

### TypeScript

| Trigger | Description |
| --- | --- |
| `route` | Express route handler |
| `afn` | Async function with return type |
| `int` | Interface definition |
| `apiresponse` | API response type |

### Express / NestJS

| Trigger | Description |
| --- | --- |
| `exrouter` | Express router with CRUD routes |
| `exctrl` | Express controller class |
| `exmw` | Express middleware |
| `nestctrl` | NestJS `@Controller` with CRUD |
| `nestserv` | NestJS `@Injectable` service |
| `nestmod` | NestJS `@Module` |
| `nestdto` | DTO with class-validator |
| `nestent` | TypeORM entity |

### Go Snippets

| Trigger | Description |
| --- | --- |
| `iferr` | `if err != nil { return err }` |
| `errw` | `fmt.Errorf` error wrapping |
| `tdt` | Table-driven test |
| `bench` | Benchmark function |
| `handler` | HTTP handler function |
| `middleware` | HTTP middleware |
| `goroutine` | Goroutine with errgroup |
| `ctx` | Context with timeout/cancel |
| `mock` | Interface mock scaffold |
| `init` | `init()` function |
| `main` | `main()` with signal handling |

## Customization

| What | Where |
| --- | --- |
| Add a language | `lazyvim.json` (extras) + `lua/plugins/lang-<name>.lua` |
| Add a plugin | `lua/plugins/<category>.lua` |
| Add keymaps | `lua/config/keymaps.lua` |
| Add snippets | `snippets/<language>.lua` — register in `lua/plugins/coding.lua` |
| Change theme | `lua/plugins/colorscheme.lua` |
| Change editor options | `lua/config/options.lua` |
| Add autocommands | `lua/config/autocmds.lua` |
| Add Mason tools | `lua/plugins/mason-tools.lua` |
| Configure formatters | `lua/plugins/formatting.lua` |
| Configure linters | `lua/plugins/linting.lua` |

## Linter / Formatter Configuration

Configuration files at the project root that tools pick up automatically:

| File | Tool | Purpose |
| --- | --- | --- |
| `.stylua.toml` | stylua | Lua formatting rules |
| `.golangci.yml` | golangci-lint | Go linting rules |
| `.eslintrc.json` | eslint_d | JS/TS linting rules |
| `.flake8` | flake8 | Python linting rules |
| `.sqlfluff` | sqlfluff | SQL linting/formatting (ANSI dialect) |
| `.stylelintrc.json` | stylelint | CSS/SCSS linting rules |
| `.editorconfig` | EditorConfig | Cross-editor formatting defaults |
| `checkstyle.xml` | checkstyle | Java linting rules |
| `CPPLINT.cfg` | cpplint | C/C++ linting rules |
