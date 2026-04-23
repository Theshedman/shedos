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

## Phase 2 — Upgrade UX polish · **Shipped**

Make `shedos-update` feel first-class: unattended, transparent, conflict-aware.

| # | Deliverable | Status |
|---|---|---|
| B#1 | `shedos-update --yes` unattended mode + stranded-file scan | ✅ Shipped |
| B#2 | `shedos-review-configs` IntelliJ-style merge TUI | ✅ Shipped |
| B#3 | Mako notification on update detection (beyond the waybar badge) | ✅ Shipped |
| B#4 | Waybar conflict-count indicator for unresolved `.shedosnew` files | ✅ Shipped |
| B#5 | Release cadence: weekly PR + hotfix/RC hatches — [proposal](cadence-proposal.md), [flow](releasing.md) | ✅ Shipped |
| B#6 | Public website at [shedos.org](https://shedos.org) (Astro + Tailwind, GitHub Pages) | ✅ Shipped |
| B#7 | First-boot proprietary-apps installer (`shedos-apps-installer`) — opt-in checklist for VS Code, Chrome, Slack, etc. | ✅ Shipped |

All Phase 2 B#2 deferred polish items (`/` filter, pan/wrap, signal-driven
draft save, excluded-path surfacing, `$HOME` read-only guard, Unicode-aware
hunk-strip width) landed in the review-configs follow-up pass — there is no
outstanding B#2 polish list.

---

## Phase 3 — Rollback + canary · **In progress**

Once Phase 2 is closed, the next class of user story is "I ran the update
and something broke; get me back."

| # | Deliverable | Status |
|---|---|---|
| B#1 | btrfs snapshot pre-upgrade + `shedos-update --rollback` — snapper pre/post pair wraps every upgrade; `shedos-rollback` swaps `@` with the chosen snapshot; reboot applies. Home (`@home`) is intentionally **not** rolled back. | ✅ Shipped |
| B#2 | AUR build cache across CI runs — `actions/cache` keyed on `hashFiles('packages/aur.txt')`, shared between `build-packages.yml` and `build-iso.yml`. Cuts the ~35 min AUR tail to near-zero on unchanged releases. | ✅ Shipped |
| B#3 | `[shedos-testing]` canary channel | ⏸ Deferred — see below |
| B#4 | Offline-signed packages | ⏸ Deferred — see below |

### B#3 deferred (canary channel)

The client-side opt-in (`shedos-update --channel testing`) is trivial, but
the work to make it useful lives on the CI side:

- A publish path for testing packages (e.g. `r2:shedos-repo/x86_64-testing/`).
- A rule for *which* packages go to testing vs stable. Options:
  dedicated branch (`next`), a PKGBUILD marker, or promote-on-green.
- Retention policy for `x86_64-testing/` so it doesn't balloon.

Shipping a `--channel testing` flag that drops a `[shedos-testing]` stanza
pointing at a path CI isn't publishing to would 404 users' next
`pacman -Sy` — worse UX than the waybar badge today. Reopen once the
pipeline has a home for RC packages to live.

### B#4 deferred (offline signing)

The current model signs on ephemeral GitHub runners with a secret-scoped
private key. Moving signing off CI (offline ceremony, detached sig upload)
only makes sense if the threat model tightens — e.g. a leaked runner key,
a regulatory requirement, a compromise scare in the broader Arch ecosystem.
No concrete trigger today.

---

## Phase 4+ — Unscoped

Placeholder for ideas that have been mentioned but not committed to a phase:
`shedos-migrate-to-packaged` for pre-packaging installs.

**Landed as unscoped follow-ups:**

- File-level `$HOME/.config/shedos/sync-exclude` matchers (April 2026,
  `shedos-system` pkgrel=4): drop a glob list at that path and ShedOS will
  never seed, auto-update, or flag those files. Example template at
  `/usr/share/shedos/sync-exclude.example`.
- Auto-generated GitHub Release notes (April 2026, `build-iso.yml`): every
  tag push groups its Conventional Commits since the previous tag into
  feat/fix/perf/docs/ci/chore sections and stamps a compare-link in the
  release body. No manual release-note maintenance.

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
