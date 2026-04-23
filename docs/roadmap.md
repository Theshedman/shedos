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
- `shedos-sync-configs` for dotfile sync with pacman-style
  `.shedosnew`/`.shedosbak` conflict artefacts.
- `shedos-update` CLI + waybar update indicator.
- `shedos-keyring` carrying the repo signing key (rotation is a no-touch
  event for users).

---

## Phase 2 — Upgrade UX polish · **In progress**

Make `shedos-update` feel first-class: unattended, transparent, conflict-aware.

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedos-update --yes` unattended mode + stranded-file scan | ✅ Shipped |
| B#2 | `shedos-review-configs` IntelliJ-style merge TUI | ✅ Shipped (v1) — polish deferred, see below |
| B#3 | Mako notification on update detection (beyond the waybar badge) | ✅ Shipped |
| B#4 | Waybar conflict-count indicator for unresolved `.shedosnew` files | ✅ Shipped |
| B#5 | Release cadence: weekly PR + hotfix/RC hatches — [proposal](cadence-proposal.md), [flow](releasing.md) | ✅ Shipped |
| B#6 | Public website at [shedos.org](https://shedos.org) (Astro + Tailwind, GitHub Pages) | ✅ Shipped |
| B#7 | First-boot proprietary-apps installer (`shedos-apps-installer`) — opt-in checklist for VS Code, Chrome, Slack, etc. | ✅ Shipped |

### B#2 deferred polish (to address in a follow-up iteration)

These were intentionally cut from the first shippable `shedos-review-configs`
cut so the core merge flow could get dogfooded on a real upgrade before more
surface area was added. They are not bugs — they are known gaps.

- **FileList `/` filter** — the key is bound but does not yet filter the list.
- **Pan (`h`/`l`) and wrap toggle (`z`)** — not wired into `MergeScreen`.
  Long single lines (minified JSON etc.) currently rely on the terminal's
  horizontal behaviour.
- **SIGTERM/SIGHUP draft save** — `q` already saves a draft on cancel, but
  forced termination (logout, window manager kill, `kill <pid>`) loses the
  in-progress decisions. A signal handler should flush the current state.
- **Excluded-path `.shedosnew`** — currently silently skipped during the scan.
  Surface a note so the user knows a conflict exists there and can choose to
  delete the stray file.
- **`$HOME` read-only** — no early guard; the tool runs, presents the UI, and
  only fails at save time with a cryptic OSError. Detect EROFS / unwritable
  `$HOME` at startup and exit cleanly.
- **Unicode width** in the custom hunk-strip widget and the long-line cutoff
  in `_render_cell` (`unicodedata.east_asian_width`) so CJK/emoji don't
  desync column math across panes.

---

## Phase 3 — Rollback + canary · **Further out**

Once Phase 2 is closed, the next class of user story is "I ran the update
and something broke; get me back."

- **btrfs snapshot pre-upgrade + `shedos-update --rollback`** — one-command
  revert using the existing `@snapshots` subvolume.
- **`[shedos-testing]` canary channel** — opt-in repo for pre-release
  packages; `shedos-update` grows a `--channel` flag.
- **Offline-signed packages** — move signing off CI runners if the threat
  model tightens.
- **AUR build cache across CI runs** — cut `build-packages.yml` time for
  the slow AUR tail.

---

## Phase 4+ — Unscoped

Placeholder for ideas that have been mentioned but not committed to a phase:
file-level `$HOME/.config/shedos/sync-exclude` matchers, `shedos-migrate-to-packaged`
for pre-packaging installs, signed ISO release notes automation.

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
