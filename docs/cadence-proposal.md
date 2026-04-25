# Phase 2 B#5 — Release cadence proposal

Status: proposal, not yet accepted. Pick one of the options below (or a
variant) and move the chosen mechanics into `docs/releasing.md`.

---

## Context

ShedOS already has **two independent release gates**:

1. **Packages** — `build-packages.yml` fires on every push to `main` that
   touches `packaging/**` or `packages/**`. Signed packages land at
   `repo.shedos.org` within ~40 min. Installed systems pick them up via
   `shedman update` / `pacman -Syu`. **This gate is already continuous.**
2. **ISOs** — `build-iso.yml` fires on `v*` tag push. ~45 min build; the
   7.6 GiB artefact goes to `r2:shedos-repo/iso/` with a 2-stable + 1-RC
   retention sweep. **This gate is manual today** (a human decides when to
   tag).

CalVer (`YYYY.MM.DD[.N]`) is the single source of truth in `VERSION`;
`scripts/bump-version.sh` propagates it into every `shedos-*/PKGBUILD`. On
same-`pkgver` re-runs the script bumps `pkgrel` instead (cheap republish).

B#5 is a decision about **how often we flip gate 2** and **how tightly we
couple gate 1 to a version bump**. Nothing about gate 1's "always fresh"
property is up for debate — that's why we built rolling release in the
first place.

---

## Options at a glance

| # | Option | pkgver cadence | ISO cadence | Ops load | Install-delta risk |
|---|---|---|---|---|---|
| A | Continuous | per merge (same day → `.N`) | per merge | **High** | None |
| B | Weekly | Monday only | Monday only | Low | Low (≤6d) |
| C | Rolling repo, episodic ISO | on-demand | on-demand | Very low | **High** (unbounded) |
| D | **Hybrid (recommended)** | weekly (Mon) + hotfix | weekly (Mon) + hotfix | Low-medium | Low (≤6d) |

---

## Option A — Continuous (per-merge)

Every `push` to `main` that touches packaging runs `bump-version.sh --today`,
commits the bump, and pushes a `v<today>[.N]` tag. If the same day already
has a stable tag, append `.N`. ISO build fires automatically.

**Pros**
- No ceremony. Every fix is a released fix.
- Zero "should we cut one this week?" decisions.

**Cons**
- **Tag soup.** At 3–5 merges/week we'd cut 150–250 tags/year — all of them
  with an ISO. Grep-hunting through `git tag --list` becomes painful.
- **CI churn.** ~45 min/ISO × every merge = routinely >10 h/week of build
  time for changes that don't warrant a new ISO. AUR cache helps but the
  mkarchiso + R2 upload costs are still paid.
- **User UX noise.** `shedman update` would show "new release" every day or
  two. Great for dogfooding, bad signal.
- **Retention sweep becomes a firehose.** 2 stable + 1 RC means almost every
  ISO is deleted before anyone downloads it.

**Verdict:** reject. The cost is real; the benefit is imaginary (gate 1
already ships every fix to installed systems — the ISO is for installers,
not upgraders).

---

## Option B — Weekly (fixed weekday)

A scheduled workflow runs on Mondays at a fixed UTC time, does
`scripts/bump-version.sh --today`, commits the bump, pushes a tag. ISO
fires on tag. Intra-week merges land on `main` with the current pkgver; if
their `packaging/` payload actually changed, the pkgrel bumper (new tool)
increments `pkgrel` on the affected packages so installed systems get the
content. pkgver only turns over on Mondays.

**Pros**
- Predictable. "There's a new ShedOS ISO every Monday" is easy to
  communicate and easy to plan releases around.
- One ISO/week fits comfortably inside retention (2 stables + 1 RC = 3
  weeks of coverage).
- Release notes write themselves: "here's what landed this week."
- Still gives users continuous repo updates between ISO cuts (via pkgrel
  bumps from gate 1).

**Cons**
- An urgent fix merged Monday evening waits until next Monday for the
  pkgver bump + ISO. Mitigation: a manual hotfix path (see Option D).
- Requires the pkgrel bumper to exist, or intra-week changes don't ship
  at all until Monday.
- An unattended bot creating tags needs signing credentials in CI (the
  same key the packages workflow already has; not new risk).

**Verdict:** acceptable fallback. Ship this if D's per-package pkgrel
automation feels like too much new tooling for now.

---

## Option C — Rolling repo, episodic ISOs

Gate 1 stays as-is (always current). Gate 2 fires only when a human
decides "it's time" — no schedule. Cadence emerges from what we're
working on: one ISO after B#5 lands, another after Phase 3 lands, etc.

**Pros**
- Zero automation. This is what we've done so far.
- ISOs carry meaning: each one corresponds to a named milestone.

**Cons**
- **Install-delta trap.** If the latest ISO is 3 months old, a new user's
  first-boot `pacman -Syu` pulls 3 months of changes. That's where
  conflicts surface (file-path churn, keyring rotation, hook upgrades).
  The ISO exists specifically to minimize this delta; letting it drift
  wastes the gate.
- **Asymmetric reliance on one person.** Releases only happen when
  someone remembers. After a busy stretch we suddenly realize the last
  ISO is 2 months old.
- No rhythm for early adopters to sync to — RC testing is ad-hoc.

**Verdict:** reject. We already lived this for the Phase 1 prelaunch
and the drift accumulated fast; persisting it undercuts the ISO's purpose.

---

## Option D — Hybrid (recommended)

Two tracks running side by side, each with a manual override:

### Track 1 — Continuous repo (gate 1, already in place)

Every push to `main` that touches `packaging/**`:
- Current behavior preserved: `build-packages.yml` rebuilds + republishes.
- **New**: a lightweight pre-step auto-bumps `pkgrel` for any `shedos-*`
  package whose `packaging/<pkg>/` tree actually changed in the push.
  Commit goes onto `main` with `[skip ci]` to avoid re-triggering itself.

Installed systems then see the change within a `shedman update` cycle —
same as today, but without requiring a human to remember to bump pkgrel.

### Track 2 — Weekly ISO (gate 2, new)

A new scheduled workflow, e.g. `release-weekly.yml`, runs every Monday at
07:00 UTC:
1. `scripts/bump-version.sh --today` (flips pkgver → today, resets pkgrel=1).
2. Commit + push.
3. Create an annotated tag `v<today>` (SSH-signed via the same key CI
   already uses for packages and repo DB).
4. ISO build fires on that tag via existing `build-iso.yml`.

Release notes (optional, later): collect merge titles since last stable
tag into the GitHub Release body.

### Manual hatches

- **Hotfix**: `scripts/bump-version.sh 2026.04.21.1` + sign + push +
  `git tag v2026.04.21.1` + push tag. Fires ISO. No schedule change.
- **RC**: tag `v<date>-rcN` any time. RC tag pushes fire both
  `build-iso.yml` (RC ISO into the RC retention slot) **and**
  `build-packages.yml` (RC packages into `r2:shedos-repo/x86_64-testing/`,
  Phase 6B). Stable users (`[shedos]` only) don't see them; testing
  users (`[shedos-testing]` declared in `system.toml`) do.
- **Skip a Monday**: `touch .no-release-this-week` in the repo root; the
  weekly workflow checks for and removes the file before cutting.

### Why this wins

- **Repo is always current** (track 1) — no install-delta trap.
- **ISOs are predictable** (track 2) — one per week, retention covers it.
- **Intra-week urgent fixes ship** without waiting for Monday (hotfix tag).
- **RC testing has rhythm** — any intra-week tag can be an RC.
- **No per-merge ISO churn** — we spend CI minutes on releases that
  matter.

### New tooling required

Two small pieces, both feasible in a single PR:

1. `scripts/bump-changed-pkgrels.sh` (~40 LOC) — given a git diff range,
   produces the set of `shedos-*` packages whose files changed, and
   `sed`s `pkgrel++` in each. Called from `build-packages.yml` before
   the build step. Self-commits with `[skip ci]`.
2. `.github/workflows/release-weekly.yml` (~30 LOC) — `schedule: cron`
   trigger, `.no-release-this-week` check, bump-version invocation,
   signed commit + tag.

Existing infrastructure (`bump-version.sh`, VERSION guardrail in
`build-iso.yml`, signing key plumbing) all carries over unchanged.

---

## Recommendation

**Adopt Option D** and implement it in two phases to de-risk:

1. **Phase 2 B#5 itself**: ship `release-weekly.yml` + document the
   hotfix/skip paths. Leave the per-package pkgrel bumper for follow-up
   (manual pkgrel bumps are fine at current merge volume; we've been
   doing it by hand so far).
2. **Follow-up (deferred, optional)**: `bump-changed-pkgrels.sh` once
   merge volume makes manual pkgrel bumps annoying.

If the pkgrel automation feels too speculative to commit to, **fall back
to Option B** — identical weekly cadence, just with manual pkgrel bumps.
Zero difference from the user's perspective.

**Reject A and C** for the reasons above.

---

## Open questions

- **Day of week.** Monday 07:00 UTC was chosen so a failed build surfaces
  during Monday working hours for the maintainer. Swap if another slot
  fits dogfooding better.
- **RC cadence.** Do we want every weekly cut to go out as `-rc1` first
  for a 24 h soak and promote to stable only if no regressions? Probably
  yes once we have more than one dogfooder, but overkill for now.
- **Release-notes automation.** Punt until the first weekly cut lands —
  we'll know what's useful to surface after seeing a few in the wild.
