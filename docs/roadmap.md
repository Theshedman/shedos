# ShedOS Roadmap

Living document. Phases are the unit of planning; each phase has a handful
of ordered deliverables (prefixed `B#N`, "bucket N") that stack into a
shippable user-visible improvement. Ticked items are landed on `main`.

---

## Phase 1 — Rolling-release foundation · **Shipped**

The minimum to get existing users off the reinstall treadmill. Everything
shedOS-specific ships as signed Arch packages through
[`repo.shedos.org`](https://repo.shedos.org); installed systems move between
releases via plain `pacman -Syu`. Eleven deliverables (P1–P11) covering:

- Native `shedos-*` package tree under `packaging/` with CalVer-driven
  `pkgver` (single `VERSION` file, `scripts/bump-version.sh`).
- `build-packages.yml` CI publishing signed repo artifacts to R2.
- `build-iso.yml` CI publishing signed ISOs on tag push, with a
  VERSION-vs-tag guardrail.
- `shedman config --sync` for dotfile sync with pacman-style
  `.shedosnew`/`.shedosbak` conflict artefacts.
- `shedman update` CLI + waybar update indicator.
- `shedos-keyring` carrying the repo signing key (rotation is a no-touch
  event for users).

---

## Phase 2 — Upgrade UX polish · **Shipped**

Make `shedman update` feel first-class: unattended, transparent, conflict-aware.

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedman update --yes` unattended mode + stranded-file scan | ✅ Shipped |
| B#2 | `shedman config --review` IntelliJ-style merge TUI | ✅ Shipped |
| B#3 | Mako notification on update detection (beyond the waybar badge) | ✅ Shipped |
| B#4 | Waybar conflict-count indicator for unresolved `.shedosnew` files | ✅ Shipped |
| B#5 | Release cadence: weekly PR + hotfix/RC hatches — [proposal](cadence-proposal.md), [flow](releasing.md) | ✅ Shipped |
| B#6 | Public website at [shedos.org](https://shedos.org) (Astro + Tailwind, GitHub Pages) | ✅ Shipped |
| B#7 | First-boot proprietary-apps installer (`shedman install`) — opt-in checklist for VS Code, Chrome, Slack, etc. | ✅ Shipped |
| B#8 | File-level `$HOME/.config/shedos/sync-exclude` matchers — drop a glob list and `shedman config --sync` will never seed, auto-update, or flag those files. Template at `/usr/share/shedos/sync-exclude.example`. | ✅ Shipped |
| B#9 | Auto-generated GitHub Release notes — every tag push groups Conventional Commits since the previous tag into feat/fix/perf/docs/ci/chore sections and stamps a compare-link in the release body. | ✅ Shipped |

All Phase 2 B#2 deferred polish items (`/` filter, pan/wrap, signal-driven
draft save, excluded-path surfacing, `$HOME` read-only guard, Unicode-aware
hunk-strip width) landed in the review-configs follow-up pass — there is no
outstanding B#2 polish list.

---

## Phase 3 — Rollback + canary · **Shipped** (B#4 deferred — see below)

Once Phase 2 is closed, the next class of user story is "I ran the update
and something broke; get me back." B#1 (btrfs rollback) and B#2 (AUR CI
cache) are the user-facing deliverables; B#3 and B#4 are infrastructure
bets that don't yet have a forcing function and live deferred below.

| # | Deliverable | Status |
|---|---|---|
| B#1 | btrfs snapshot pre-upgrade + `shedman update --rollback` — snapper pre/post pair wraps every upgrade; `shedman rollback` swaps `@` with the chosen snapshot; reboot applies. Home (`@home`) is intentionally **not** rolled back. | ✅ Shipped |
| B#2 | AUR build cache across CI runs — `actions/cache` keyed on `hashFiles('packages/aur.txt')`, shared between `build-packages.yml` and `build-iso.yml`. Cuts the ~35 min AUR tail to near-zero on unchanged releases. | ✅ Shipped |
| B#3 | `[shedos-testing]` canary channel | ✅ Shipped (in Phase 6B) |
| B#4 | Offline-signed packages | ⏸ Deferred — see below |

### B#3 — canary channel (shipped in Phase 6B)

Shipped in Phase 6B (commit on `main`). The deferred prerequisites
all resolved naturally:

- **Publish path**: `r2:shedos-repo/x86_64-testing/` (parallel prefix).
- **Promotion rule**: every push to `main` and every stable tag
  publishes to **both** `/x86_64/` and `/x86_64-testing/`. RC tags
  publish to `/x86_64-testing/` only. So testing is "stable cuts
  + RC iterations"; stable is "stable cuts only". No per-package
  marker needed.
- **Retention**: `build-packages.yml` sweeps `/x86_64-testing/` after
  every publish, keeping the latest 5 versions per package. `/x86_64/`
  retains its long tail.
- **Client opt-in**: no new flag — the existing Phase 6A
  `[pacman.repos]` reconciler handles it. Add a
  `[pacman.repos.shedos-testing]` stanza to
  `/etc/shedos/system.toml`, run `shedman apply -y`, you're in.

### B#4 deferred (offline signing)

The current model signs on ephemeral GitHub runners with a secret-scoped
private key. Moving signing off CI (offline ceremony, detached sig upload)
only makes sense if the threat model tightens — e.g. a leaked runner key,
a regulatory requirement, a compromise scare in the broader Arch ecosystem.
No concrete trigger today.

---

## Phase 4 — Declarative system state + operational awareness · **Shipped**

Two parallel tracks. Track B (observability) ships first because it reuses
existing patterns and gives users visible wins early; Track A (declarative
`/etc/shedos/system.toml` + `shedman apply` reconciler) is the strategic
differentiator. Each bucket is independently shippable.

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedman health` + waybar `custom/health` module — disk/memory/battery/cpu-temp aggregator mirroring the `shedman updates` pattern; signal `SIGRTMIN+10` | ✅ Shipped |
| B#2 | `shedman logs` Textual journal browser TUI — three-pane (units / messages / filters); `Super+Shift+J` | ✅ Shipped |
| B#3 | `shedman update --history` TUI + waybar click-through — groups snapper pre/post pairs by `userdata.source=shedos-update`; `r` invokes `shedman update --rollback` | ✅ Shipped |
| B#4 | `/etc/shedos/system.toml` schema + `shedman apply` core — stdlib-tomllib reconciler for `systemd.{system,user}.enable`, `drop-ins`, `snapper` (Tier 1 state) | ✅ Shipped |
| B#5 | `shedman doctor` drift detector + timer — reuses B#4's diff engine read-only; waybar `custom/doctor` pill on drift; `SIGRTMIN+11` | ✅ Shipped |
| B#6 | Tier 2 state: `[pacman.repos]` fence-managed + `[services.postgresql]` (auto-init / per-user-db) | ✅ Shipped |

### Locked design choices

- **Python + Textual** (already a dep from Phase 2 B#2 review-configs) for
  `shedman apply` and every new TUI. Only new runtime dep is `python-pydantic`
  (already in the installer's `pyproject.toml`, so in most caches).
- **TOML, not YAML** — stdlib `tomllib` parses it; matches starship / mise /
  elephant conventions already used across ShedOS configs.
- **Declarative supersedes, doesn't replace, install hooks.** If it's "set
  once at install", it stays in `shedos-system.install`; if it's "user might
  toggle later", it moves to `system.toml`.
- **`shedman apply` is manual, not timer-driven.** Surprise-reconciles are
  hostile. `shedman doctor` runs on a timer to *detect* drift and nudge,
  mirroring `shedman updates`.

### Deferred to later phases (resolved in Phase 6A)

The Tier 3 schema candidates flagged here — keyring trust, kernel
cmdline, mounts, user accounts, firewall rules — all land in
**Phase 6A** below. Plymouth stays deferred indefinitely.

---

## Phase 5 — Unified `shedman` CLI + migration closure · **Shipped**

The `shedos-*` command surface grew to 17 top-level binaries across Phase
1-4. Phase 5 collapses that into a single dispatcher binary: users
type `shedman update`, `shedman apply`, `shedman doctor`, etc., with
silent shims at the old `/usr/bin/shedos-*` paths preserving muscle
memory and third-party scripts. This phase also closes the two
open-ended items from the old Phase 5+ placeholder (`shedos-migrate-to-packaged`
and completion/docs catch-up).

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedman` dispatcher + rename all 17 `shedos-*` commands — dispatcher at `/usr/bin/shedman`, subcommands under `/usr/libexec/shedman/`, silent back-compat shims at old paths; all waybar/hypr/systemd/desktop callers flipped in one commit | ✅ Shipped |
| B#2 | `shedman status` unified dashboard — one command aggregating updates/conflicts/health/doctor with text + `--json` output | ✅ Shipped |
| B#3 | zsh + bash completions — `_shedman` + `/etc/bash_completion.d/shedman` with runtime subcommand discovery; opt-in per-subcommand flag completions | ✅ Shipped |
| B#4 | `shedos-migrate-to-packaged` — fill the declared-but-empty package: detect pre-packaging state, snapper snapshot, fence `/etc/pacman.conf`, `pacman -Syu shedos-meta`, seed sync manifest, `shedman doctor` verify | ✅ Shipped |
| B#5 | Docs migration — every `shedos-*` reference in `docs/`, `website/`, `README.md` rewrites to `shedman <cmd>` form | ✅ Shipped |

### Post-Phase-5 polish (landed)

- **Short-flag coverage.** Conventional single-letter aliases added to
  every user-typed `shedman` subcommand flag (`-y`, `-n`, `-c`, `-j`,
  `-d`, `-f`, `-l`, `-u`, `-k`, `-s`, `-r`). Machine-facing flags
  (`--waybar`, `--tick`, etc.) stay long-only since systemd and waybar
  invoke them by name. Completions updated; new `T5b` asserts shorts
  are emitted by `--complete-bash` for every opt-in subcommand.
- **Commands reference page.** `site/src/content/docs/commands.mdx` —
  every `shedman` subcommand, short + long flag, plus pacman and yay
  cheatsheets. Linked from README.md, packaging/README.md, and
  getting-started.mdx; replaces the exhaustive table at the bottom of
  `docs/upgrading.md` (which now points at the site).

---

## Phase 6 — Declarative state expansion · **Shipped**

Phase 4 established the TOML reconciler over five domains
(`systemd.{system,user}`, `drop-ins`, `snapper`, `pacman.repos`,
`services.postgresql`). Phase 6 extends that surface and ties up the
last imperative loose ends — firewall, kernel cmdline, mounts, users,
keyring trust — then closes out the two longer-deferred items
(canary channel, polish bucket).

Sub-phases ship in this order:

- **6A — Tier 3 declarative schema.** Five new TOML sections
  (`[network.firewall]`, `[security.keyring]`, `[fs.mounts]`,
  `[kernel.cmdline]`, `[[users]]` + `[[groups]]`). Every section is
  bidirectional: edits via the raw tool (`ufw allow`, `pacman-key
  --lsign-key`, `usermod -aG`, `vi /etc/fstab`, edit `limine.conf`)
  get adopted into `system.toml` on the next `shedman apply`.
  Install-time baseline state is protected — Calamares,
  `trust-keys.sh`, and pacman scriptlets create state we never risk
  destroying.
- **6C — Polish bucket.** ✅ Shipped. `shedman status --watch` live
  TUI (B#1), fish shell completion (B#2), 7 hand-written groff man
  pages (B#3), third-party plugin doc (B#4).
- **6B — `[shedos-testing]` canary channel.** ✅ Shipped. CI now
  publishes to `r2:shedos-repo/x86_64-testing/` on every push to
  main + every tag; RC tags route to testing-only. Client opt-in
  via `[pacman.repos.shedos-testing]` in `system.toml` — no new flag
  needed thanks to the Phase 6A reconciler.

### 6A — Tier 3 declarative schema

The bidirectional model is described in
`~/.claude/plans/let-s-deeply-and-carefully-purring-twilight.md`. Key
properties:

- TOML is the persisted canonical form.
- Per-bucket safety posture: `reconcile` (firewall, mounts, cmdline)
  vs `warn-don't-remove` (keyring) vs `warn-and-preserve-membership`
  (users/groups).
- Install-time state is baseline-snapshotted on first apply and
  protected forever.

| # | Deliverable | Status |
|---|---|---|
| B#1 | `[network.firewall]` reconciler — declarative ufw with full grammar; reconcile posture; bidirectional adoption. Lands the cross-cutting scaffolding (python-tomlkit dep, three-way merge, baseline helpers, env overrides). | ✅ Shipped |
| B#2 | `[security.keyring]` reconciler — `pacman-key --lsign-key` wrapper; warn-don't-remove posture; baseline = shedos's install-time trust chain. | ✅ Shipped |
| B#3 | `[fs.mounts]` reconciler — declarative `/etc/fstab` entries with marker fence; baseline-protects Calamares-shipped lines; auto-named adoption. | ✅ Shipped |
| B#4 | `[kernel.cmdline]` reconciler — Limine append tokens; baseline = install-time cmdline; reboot-required marker on every Change. | ✅ Shipped |
| B#5 | `[[users]]` + `[[groups]]` — additive only; never `userdel`/`groupdel`; warn on TOML removal of any membership. | ✅ Shipped |

### 6C — Polish bucket

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedman status --watch` — Textual live-refreshing dashboard wrapping the one-shot `shedman status` aggregator. `--interval N` configurable; `q` quits. | ✅ Shipped |
| B#2 | Fish shell completion — mirror Phase 5 B#3's bash/zsh completers. New `--complete-fish` handler convention. | ✅ Shipped |
| B#3 | Man pages — 7 `shedman(1)` + subcommand pages installed under `/usr/share/man/man1/`. Originally hand-written groff; later migrated to scdoc source (`packaging/shedos-system/man/*.scd`) rendered to `.1` at `prepare()` time, makedep `scdoc`. | ✅ Shipped |
| B#4 | Third-party plugin doc — `docs/plugins.md` covering the `/usr/libexec/shedman/<cmd>` convention, `--help-summary` contract, and completion handlers. | ✅ Shipped |
| B#5 | Fish completion rich descriptions — `--complete-fish` emits tab-separated `flag\tdescription`, fish completion script reads both columns and passes `-d` to `complete`. | ✅ Shipped |

### 6B — Canary channel

| # | Deliverable | Status |
|---|---|---|
| B#1 | `[shedos-testing]` channel — CI dual-publishes to `/x86_64/` + `/x86_64-testing/`; RC tags route to testing-only. Client opt-in via `[pacman.repos.shedos-testing]` in `system.toml`. Retention sweep keeps the latest 5 versions per package on testing. | ✅ Shipped |

### 6A's deferred (carried forward from Phase 4 + sharpened)

- **Plymouth theme in `system.toml`** — mkinitcpio regen side-effect
  on every change still makes the cost/benefit lopsided.
- **User account deletion** — too destructive for any declarative
  layer; stays an explicit `userdel` gesture.
- **Keyring key revocation** — `warn-don't-remove` is the v1 answer;
  revocation requires a safer protocol than declarative omission.
- **fstab activation without reboot** — deferred `activate = true`
  key on `[fs.mounts]`; revisit when there's a concrete use case.
- **Per-user systemd `enable`/`disable`** — current
  `[systemd.user]` is `--global`; future
  `[systemd.user.<username>]` needs its own design pass.

### 6B's deferred

- **Per-package testing markers / split metapackage** — every package
  flows to both channels by tag. Per-package "testing-only" routing
  needs a concrete trigger (e.g. wanting to ship a v2 of a package
  that's incompatible with stable users).
- **`shedman update --channel testing` flag** — the TOML route is
  canonical. CLI shortcut is a tiny follow-up if asked for.
- **Promote-on-green workflow_dispatch action** — promotion is
  automatic on stable tag; manual gating isn't needed today.

### 6C's deferred

- **Plugin doc on shedos.org** — `docs/plugins.md` is currently
  GitHub-rendered; promoting it into `site/src/content/docs/` would
  give it the Astro nav. Defer until a third-party plugin actually
  exists in the wild.

---

## Phase 7 — Custom kernel + system tuning · **In flight**

| # | Deliverable | Status |
|---|---|---|
| 7.1 | Userspace tuning: sysctl + udev (per-class I/O scheduler, HDD readahead, USB autosuspend), modprobe blacklist, zram-generator, seed `[kernel.cmdline]` defaults via `system.toml` | ✅ Shipped |
| 7.2 | Services: systemd-oomd, tlp (single power manager), ananicy-cpp, realtime audio group + limits.d. Drop power-profiles-daemon (declared as conflict + replaces=) | ✅ Shipped |
| 7.3 | `shedos-kernel` package (vendored linux-zen rebuild, x86_64) + `shedos-kernel-headers`, packaged Limine renderer + pacman hook + `shedman kernel` CLI, kernel-version-watcher CI workflow, storage-driver non-removal contract test | ✅ Shipped |

### 7's deferred

- **`shedos-kernel-x86_64-v3`** — AVX2-targeted variant for post-Haswell hardware. Single follow-up bucket once V1 build pipeline is proven.
- **BORE / sched_ext schedulers** — wait for upstream landing in linux-zen rather than maintaining a patch series.
- **Clang+LTO build** — extra toolchain complexity; revisit if measurable perf win.
- **Secure Boot shim signing** — separate workstream; needs a UEFI keypair in CI secrets. SB users stay on stock `linux` (which Arch signs via `linux-firmware`'s SB shim chain).
- **Per-board `.config` variants** (Framework, Thinkpad, Steam Deck) — wait for user demand.

---

## Conventions

- A phase is "shipped" when every `B#N` in it is on `main`, documented in
  `docs/upgrading.md`, and has been dogfooded through at least one upgrade
  cycle on a real install.
- Deferred items live in the phase they were cut from, under a "deferred"
  subsection, with enough detail that a future pass can pick them up cold.
- New ideas land here before they land in plan files at
  `~/.claude/plans/` — that directory is per-session scratch; this doc is
  durable.
