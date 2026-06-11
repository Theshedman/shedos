# Releasing ShedOS

Two release gates:

- **Gate 1 (repo)** — signed packages republish on every merge to `main`
  that touches `packaging/**` or `packages/**`. `build-packages.yml`
  runs `scripts/bump-version.sh` (no args) to auto-bump `pkgrel` for
  every shedos-* package whose content hash drifted since the last
  release, commits the bump back to `main` under the `shedos-ci[bot]`
  identity, then rebuilds and publishes. Continuous; no maintainer
  action needed once the merge lands.
- **Gate 2 (ISO)** — a new `v<CalVer>` tag, cut on demand by the
  maintainer when there's something worth shipping. The tag fires
  `build-iso.yml`.

This doc covers gate 2.

---

## Cutting a release

```sh
today=$(date -u +%Y.%m.%d)
scripts/bump-version.sh "$today"
git add VERSION packaging/
git commit -S -s -m "release: v$today"
git tag -s "v$today" -m "ShedOS v$today"
git push origin main
git push origin "v$today"
```

`bump-version.sh <date>` writes `VERSION` and bumps `pkgrel` for every
shedos-* package whose content hash drifted since the last release
manifest (`packaging/.last-release-hashes.toml`).

Pushing `main` fires `build-packages.yml`; the tag push fires
`build-iso.yml`. Both land within ~45 min. The retention sweep in
`build-iso.yml` keeps R2 tidy.

If you've already shipped a release dated today and need another, append
an incremental suffix:

```sh
scripts/bump-version.sh 2026.04.22.1
```

`bump-version.sh` validates that `YYYY.MM.DD[.N]` is still CalVer-shaped;
anything else errors out.

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
- Bakes `test` into the ISO's `/etc/shedos/channel`. The marker rides
  the squashfs into every install, where shedos-system's pacman.conf
  fence reads it and points `[shedos]` at `/test/x86_64/` — so systems
  installed from the RC ISO actually soak the RC packages.

`build-packages.yml` on the RC tag also freezes the exact published
set at `r2:shedos-repo/rc/v<date>-rcN/x86_64/` — an immutable snapshot
of what the soak exercises.

If the RC holds up, promote by cutting the plain stable tag:

```sh
git tag -s "v$today" -m "ShedOS v$today"
git push origin "v$today"
```

The stable tag triggers two things in parallel:

1. `build-packages.yml` skips makepkg entirely and promotes the
   latest matching RC snapshot:
   `rclone copy r2:shedos-repo/rc/v<date>-rcN/x86_64/ → /stable/x86_64/`.
   Promotion refuses to run when no RC snapshot exists for the
   version, and pushes to `main` during the soak cannot contaminate
   it — `/stable` gets exactly the bytes the RC soaked, nothing newer.
2. `build-iso.yml` builds a stable ISO that bakes `stable` into
   `/etc/shedos/channel`, so installs from it track `/stable/x86_64/`.

No `VERSION` churn between RC and stable — `bump-version.sh` is
hash-aware and only bumps packages whose content actually changed since
the manifest. A no-source-change stable cut publishes nothing new; the
rclone promote is the only artifact move.

During the RC soak, after installing in a VM, run
`test/install/verify-calamares-defaults.sh` inside the freshly
installed system — it confirms the proprietary apps that ride
install.sfs actually landed.

---

## Why the maintainer signs locally

Every commit and tag on `main` is SSH-signed under a single maintainer
identity. CI does not have that key and won't; handing it to GitHub
Actions would double the attack surface for a release cadence that takes
two minutes to do by hand.

The only exception is `build-packages.yml`'s pkgrel auto-bump, which
lands an unsigned `shedos-ci[bot]` commit. That's accepted because the
bot's authority is narrow (it can only mutate `pkgrel=` lines under
`packaging/` plus `VERSION` when chained behind a maintainer push), and
because the alternative — making the maintainer manually bump pkgrel on
every drift — was the kind of toil that erodes the discipline that
makes signing useful in the first place.

Alternatives rejected for the rest of the release path:

- **CI-side signing key** — requires a second `~/.ssh/allowed_signers`
  entry plus a private key in CI secrets.
- **Bot tags or merges to `main` outside the pkgrel-bump scope** — the
  whole point of signing every commit is that `git log --show-signature`
  stays clean; a wider bot scope puts a gap in that chain.
- **GitHub's built-in signed squash-merge** — signed by GitHub's key,
  not the maintainer's. "Verified" on the web UI but not by
  `allowed_signers`.
