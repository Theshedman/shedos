# Releasing ShedOS

ShedOS follows the **hybrid cadence** from
[`docs/cadence-proposal.md`](cadence-proposal.md):

- **Gate 1 (repo)** — signed packages republish on every merge to `main`
  that touches `packaging/**` or `packages/**`. Continuous, already live.
- **Gate 2 (ISO)** — new `v<CalVer>` tag every **Monday**, plus manual
  hotfix / RC paths for anything that can't wait.

This doc covers gate 2.

---

## The weekly release

Every Monday at 07:00 UTC, `.github/workflows/release-weekly.yml` opens a
PR titled `release: v<today>` containing a `bump-version.sh --today` diff.
The PR's commit is **unsigned** — CI does not have the maintainer's SSH
signing key, and won't. Merging the PR directly through the GitHub UI
would land an unsigned commit on `main`; don't do it.

Instead, **finalize locally**:

```sh
today=$(date -u +%Y.%m.%d)            # or whatever date the PR is cut for
branch="release/v$today"

git fetch origin "$branch"
git checkout main && git pull --ff-only
git merge --squash "origin/$branch"
git commit -S -s -m "release: v$today"
git tag -s "v$today" -m "ShedOS v$today"
git push origin main
git push origin "v$today"
git push origin --delete "$branch"
gh pr close <PR-number>
```

Pushing the tag fires `build-iso.yml`; pushing `main` fires
`build-packages.yml`. Both land within ~45 min. No manual step after
that — the retention sweep in `build-iso.yml` keeps R2 tidy.

---

## Skipping a week

`touch .no-release-this-week && git commit -S -s -m 'release: skip next Monday' && git push`

The scheduled workflow removes the marker on Monday (via the bot account)
and exits. The following Monday defaults back to opening a PR.

This is the right hatch when:

- You're mid-debug on a cross-package refactor and don't want Monday's
  cut to capture a half-finished state.
- The week had no `packaging/**` changes anyway (the workflow also
  auto-skips in that case — the marker is only needed to suppress an
  otherwise-wanted cut).

---

## Hotfix release (out-of-band)

When something on `main` needs to ship before Monday:

```sh
# Bump with an incremental suffix — never reuse a published CalVer date.
# Example: last release was 2026.04.21; today is 2026.04.22; urgent fix:
scripts/bump-version.sh 2026.04.22.1
git add VERSION packaging/
git commit -S -s -m "release: v2026.04.22.1 (hotfix: <what>)"
git tag -s "v2026.04.22.1" -m "ShedOS v2026.04.22.1"
git push origin main
git push origin v2026.04.22.1
```

`bump-version.sh` validates that `YYYY.MM.DD.N` is still CalVer-shaped;
anything else errors out.

A hotfix between Mondays doesn't cancel the next Monday's scheduled PR —
the scheduled workflow will propose `v<next-Monday>` on top and that one
will include the hotfix plus anything else that landed.

---

## Cutting a release candidate (RC)

When a change is big enough to want a 24–72 h soak before blessing as
stable:

```sh
# Tag from main — no VERSION change.
today=$(date -u +%Y.%m.%d)
git tag -s "v$today-rc1" -m "ShedOS v$today rc1"
git push origin "v$today-rc1"
```

`build-iso.yml` sees `-rc` in the tag name and:

- Marks the GitHub Release as a prerelease and slots the ISO into the
  RC retention bucket (1 kept) rather than the stable bucket (2 kept).
- Renders the live ISO's `pacman.conf` to pacstrap from
  `[shedos-testing] = repo.shedos.org/test/x86_64` (the always-fresh
  channel that the RC's packages were just published to). So the RC
  ISO actually installs and exercises the RC packages under bake.

If the RC holds up, promote by cutting the plain stable tag:

```sh
git tag -s "v$today" -m "ShedOS v$today"
git push origin "v$today"
```

The stable tag triggers two things in parallel:

1. `build-packages.yml` skips makepkg entirely and runs
   `rclone copy r2:shedos-repo/test/x86_64/ r2:shedos-repo/stable/x86_64/`.
   The packages on `/stable/` are now byte-identical to what `/test/`
   has been serving during RC bake.
2. `build-iso.yml` builds a stable ISO whose live `pacman.conf` points
   at `[shedos] = repo.shedos.org/stable/x86_64`. So users installing
   from the stable ISO pull from the same channel they'll subsequently
   `pacman -Syu` from.

No VERSION file churn between RC and stable — `bump-version.sh` is
hash-aware (since v2026.05.02) and only bumps packages whose content
actually changed since the manifest in
`packaging/.last-release-hashes.toml`. A no-source-change stable cut
publishes nothing new; the rclone promote is the only artifact move.

---

## Why the maintainer is still in the loop

The whole rationale for the PR-then-finalize flow is the SSH-signing
invariant. Alternatives we rejected:

- **CI-side signing key** — would require a second entry in
  `~/.ssh/allowed_signers` and a private key in CI secrets. Doubles the
  attack surface for a release cadence we can handle with a 2-minute
  Monday chore.
- **Unsigned bot merges to `main`** — the whole point of signing every
  commit is that `git log --show-signature` stays clean; a bot commit
  puts a gap in that chain.
- **GitHub's built-in signed squash-merge** — signed by GitHub's key,
  not the maintainer's. "Verified" on the web UI but not by
  `allowed_signers`.

If the weekly chore ever becomes annoying enough to justify the security
tradeoff, revisit.

---

## What's still deferred

**Per-package automatic pkgrel bumps** on pushes to `main` are out of
scope for now. When a change only touches one package's `tree/` and we
want it to ship mid-week via gate 1 (not wait for Monday's pkgver
bump), bump that package's `pkgrel` manually in the same commit:

```sh
sed -i 's/^pkgrel=.*/pkgrel='$((OLD+1))'/' packaging/shedos-<pkg>/PKGBUILD
```

Volume is low enough that this hasn't stung yet. Revisit if it does.
