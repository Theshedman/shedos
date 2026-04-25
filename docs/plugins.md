# Writing a `shedman` plugin

`shedman` is a runtime-discovery dispatcher: every executable file
in `/usr/libexec/shedman/` is exposed as `shedman <name>`. There is
no plugin registry, no manifest format, no `init` hook. Drop a
binary in that directory and it's a subcommand.

This page documents the conventions a plugin should follow so it
behaves like the rest of the shedman surface — discoverable in
`shedman help`, completable in zsh/bash/fish, and consistent with the
flag vocabulary users already know.

## Filesystem convention

| Path | Role |
|---|---|
| `/usr/libexec/shedman/<name>` | The plugin binary. Anything executable is a subcommand. |
| `/usr/libexec/shedman/_<name>` | Underscore-prefixed plugins are **internal helpers**: hidden from `shedman help`, but still invokable as `shedman _<name>`. Use this for command-specific tools that aren't meant to be discovered by users (e.g. `_config-sync` is the implementation behind `shedman config --sync`). |

The dispatcher discovers subcommands at runtime via `for f in
$LIBEXEC/*; do …; done`. There's no startup registration cost — a
freshly-installed package is immediately available.

A plugin's name becomes its subcommand. Pick a verb noun-phrase that
plays well with the rest of the surface:

- `apply`, `doctor`, `rollback` — single-verb actions on a known
  subject.
- `config`, `status`, `logs` — topic-noun umbrellas.
- `db`, `launcher`, `power` — internal binaries called by systemd /
  waybar / hyprland; rename freely if your topic adds new actions
  later.

## `--help-summary` (recommended)

Return a one-line description on `--help-summary`. The dispatcher
reads it and prints the line next to your name in `shedman help`:

```
$ shedman help
Available subcommands:
  apply     reconcile /etc/shedos/system.toml against live state
  update    interactive ShedOS upgrade (pacman + AUR + config sync)
  …
  myplugin  one-line description of what this plugin does
```

Example (bash):

```bash
if [[ "${1:-}" == "--help-summary" ]]; then
    echo "one-line description of what this plugin does"
    exit 0
fi
```

Example (Python, before any other imports that might fail):

```python
if len(sys.argv) > 1 and sys.argv[1] == "--help-summary":
    print("one-line description of what this plugin does")
    sys.exit(0)
```

If you don't honour `--help-summary`, the dispatcher falls back to
the first non-`Usage:` line of `--help` output.

## Shell completion (opt-in)

`shedman` ships completers for **bash**, **zsh**, and **fish** that
discover subcommands at completion time. They delegate per-subcommand
flag completion to your plugin via three hooks:

```
shedman <name> --complete-bash
shedman <name> --complete-zsh
shedman <name> --complete-fish
```

If your plugin honours any of those by printing one flag per stdout
line (longs and shorts mixed), users on the matching shell get
tab-completion for free. Skip them and your plugin still works —
completion just falls back to filename completion.

Example handler:

```bash
if [[ "${1:-}" == "--complete-bash" || "${1:-}" == "--complete-zsh" || \
      "${1:-}" == "--complete-fish" ]]; then
    printf '%s\n' --foo -f --bar -b --help -h
    exit 0
fi
```

The four core subcommands that opt in (`update`, `apply`, `doctor`,
`rollback`) emit both long flags and their single-letter shorts on
the same handler. The completion files filter for short-form flags
so `shedman <cmd> -<tab>` works.

## Flag vocabulary

To keep the surface coherent across plugins, prefer these short-flag
mappings when they fit:

| Short | Long | Meaning |
|---|---|---|
| `-y` | `--yes` | Unattended; skip prompts. |
| `-n` | `--dry-run` | Print plan, change nothing. |
| `-h` | `--help` | Usage. |
| `-c` | `--config PATH` | Override `/etc/shedos/system.toml`. |
| `-j` | `--json` | Machine-readable output. |
| `-d` | `--diff` | Unified-diff view. |
| `-f` | `--fix` / `--force` | Apply the obvious fix / bypass guard. |
| `-l` | `--list` | List a thing. |
| `-u` | `--undo` | Undo previous. |

Reserve combined-shorts (`shedman myplugin -yn`) for Python
`argparse` parsers, which support them automatically. `bash`-backed
plugins should accept `-y -n` as separate tokens — `case` statements
don't unbundle short clusters.

## Naming collisions

The dispatcher resolves subcommand names by exact match against
`/usr/libexec/shedman/<name>`. If two installed packages drop a
binary at the same path, the second `pacman -S` wins — pacman's
own conflict detection will warn before the install lands.

To stay collision-safe, prefix plugin names with your project
namespace if there's any risk: `myproject-foo` rather than `foo`.
The `shedos-*` packages own the unprefixed names by convention.

## Argv preservation

The dispatcher does `exec /usr/libexec/shedman/<name> "$@"` — your
plugin sees its argv exactly as the user typed it (after the
`shedman` and subcommand-name tokens). There's no rewriting,
no shell-word-splitting, no flag stripping.

If you want to know how you were invoked (e.g. for branding strings
in `--help` output), use `shedman <name>` rather than `basename
"$0"` since `$0` will be the libexec path.

## Testing your plugin

The shedman dispatcher tests at `test/shedman/run.sh` cover the
dispatch contract, not your plugin. Most plugins benefit from their
own fixture-style harness — see `test/apply/run.sh` for a pattern
that drives the binary against synthetic `/etc` and `/var/lib`
trees, with PATH-stubs for any external tools the plugin shells out
to.

Stub helpers for common tools (`ufw`, `pacman-key`, `useradd`,
`getent`, …) live in `test/apply/_stubs.sh` and can be reused.

## See also

- [Commands reference](https://shedos.org/docs/commands) —
  exhaustive flag list for every shipped subcommand.
- `man shedman` — same content as the discovery surface.
- `docs/repo-architecture.md` — adding a new ShedOS package.
