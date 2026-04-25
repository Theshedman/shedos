# ShedOS repo architecture

Maintainer-facing reference for how ShedOS is built, signed, published,
and garbage-collected. If you're a user trying to upgrade, see
[`upgrading.md`](upgrading.md) instead.

## High-level picture

```
  git push main                        git push v<tag>
       │                                    │
       ▼                                    ▼
  build-packages.yml                   build-iso.yml
  (.github/workflows/)                 (.github/workflows/)
       │                                    │
       │ builds shedos-* pkgs               │ builds ISO
       │ repo-add --sign                    │ uploads flat to R2 /iso/
       │ rclone sync                        │ retention sweep
       ▼                                    ▼
  r2:shedos-repo/x86_64/               r2:shedos-repo/iso/
  (signed pacman repo)                 (release artifacts)
       │                                    │
       └──────────── fronted by ────────────┘
                        │
                        ▼
            https://repo.shedos.org
         (Cloudflare custom domain, TLS)
```

## Cloudflare R2

| Setting | Value |
|---|---|
| Bucket | `shedos-repo` (single bucket, two prefixes) |
| Region | `auto` (Cloudflare picks) |
| Custom domain | `repo.shedos.org` (bound in R2 UI) |
| TLS | Cloudflare edge, automatic |

R2 charges free egress but meters Class A (writes) and Class B (reads)
operations. Package sizes are tens of MB; ISO is ~7.6 GB; both fit
inside the free tier at current scale.

### Bucket layout

```
r2:shedos-repo/
├── x86_64/                       # Stable signed pacman repo
│   ├── shedos.db                 # uploaded as two identical objects (R2 has no symlinks)
│   ├── shedos.db.tar.gz
│   ├── shedos.db.tar.gz.sig
│   ├── shedos.files
│   ├── shedos.files.tar.gz
│   ├── shedos.files.tar.gz.sig
│   ├── shedos-<pkg>-<ver>-<rel>-<arch>.pkg.tar.zst
│   └── shedos-<pkg>-<ver>-<rel>-<arch>.pkg.tar.zst.sig
│
├── x86_64-testing/               # Canary channel (Phase 6B)
│   ├── shedos.db
│   └── …                         # same layout as /x86_64/
│
├── iso/                          # Release artifacts (flat, one file per release)
│   ├── shedos-2026.04.21-rc1-x86_64.iso
│   ├── shedos-2026.04.21-rc1-x86_64.iso.sha256
│   ├── shedos-2026.04.21-rc2-x86_64.iso
│   └── shedos-2026.04.21-rc2-x86_64.iso.sha256
│
└── shedos.gpg                    # Bootstrap pubkey for the migration script
```

**`/x86_64/` vs `/x86_64-testing/`** (Phase 6B). The two prefixes
serve different audiences:

- **`/x86_64/`** — stable channel. Receives every push to `main` and
  every stable tag (`v<date>`). Long-tail retention; no automated
  sweep beyond what `repo-add` does.
- **`/x86_64-testing/`** — canary channel. Receives **the same
  content as `/x86_64/`** plus RC tag pushes (`v<date>-rcN`).
  Retention sweep keeps the latest 5 versions per package; older
  builds are purged after each publish.

Users opt into the testing channel by adding a
`[pacman.repos.shedos-testing]` stanza to `/etc/shedos/system.toml`
and running `shedman apply` (or by uncommenting the
`[shedos-testing]` block that the install scriptlet writes into
`/etc/pacman.conf`). See `docs/upgrading.md` for the user-facing
walkthrough.

**Why `/iso/` is flat.** An earlier layout nested by tag
(`/iso/v<tag>/<file>`). That worked but made browsing harder and
required the client to know the tag to build the URL. Flat plus
filename-embedded CalVer means every object is self-identifying;
`build-iso.yml` has a one-time sweep step that purges the old `v*/`
prefixes if any are still present.

**Why `.db` is uploaded twice.** pacman accepts both filenames. R2 has
no symlink or server-side alias concept, so the workflow uploads the
same bytes under both names. Small cost; avoids a pacman client gotcha.

## Signing

### Keypair

- 4096-bit RSA, no passphrase (CI automation requirement).
- Private key: `SHEDOS_REPO_SIGNING_KEY` GitHub Actions secret, armored.
- Public key: `packaging/shedos-keyring/tree/shedos.gpg` (binary), plus
  fingerprint in `packaging/shedos-keyring/tree/shedos-trusted`.

### Trust bootstrap on user machines

On every ShedOS install, `shedos-keyring`'s `.install` hook runs:

```bash
pacman-key --add /usr/share/pacman/keyrings/shedos.gpg
pacman-key --lsign-key <fingerprint>
```

`pacman.conf` on installed systems has
`SigLevel = Required DatabaseRequired` for the `[shedos]` repo, so
unsigned or wrong-signature packages are rejected.

### Key rotation

Not automated. If rotation is ever needed:

1. Generate a new keypair locally with `packaging/shedos-keyring/scripts/key-ceremony.sh`.
2. Update `packaging/shedos-keyring/tree/shedos.gpg` + `shedos-trusted`.
3. Paste new armored private into `SHEDOS_REPO_SIGNING_KEY`.
4. Bump `shedos-keyring`'s `pkgver` and push. The next `pacman -Syu` on
   user machines pulls the new keyring package, whose `.install` hook
   trusts the new key. From then on, new signatures validate.

Keep both keys trusted for one release cycle before retiring the old
one to avoid stranding users mid-upgrade.

## Release model

### CalVer

Version format: `YYYY.MM.DD[.N]`. Tags: `v<CalVer>` for stable,
`v<CalVer>-rcN` for release candidates.

**VERSION pins the release cycle, not the build date.** RCs for the
same cycle all share a date:

```
v2026.04.21-rc1 ──┐
v2026.04.21-rc2 ──┼── all one cycle
v2026.04.21     ──┘   (stable cut)

v2026.04.28-rc1 ── new cycle, new date
```

### Cutting a release

1. If starting a new cycle, bump `VERSION`:
   ```bash
   scripts/bump-version.sh --today    # or pass a specific CalVer
   ```
   This rewrites every `packaging/shedos-*/PKGBUILD`'s `pkgver` and
   resets `pkgrel=1`. Re-running with an unchanged `VERSION` bumps
   `pkgrel` instead (republish with no source change — rare).

2. Commit `VERSION` + `packaging/` changes (signed):
   ```bash
   git add VERSION packaging/
   git commit -S -m "release: v$(cat VERSION)"
   ```

3. Tag (signed):
   ```bash
   git tag -s v$(cat VERSION)-rc1 -m "ShedOS v$(cat VERSION)-rc1"
   # or v$(cat VERSION) for a stable cut
   ```

4. Push:
   ```bash
   git push origin main
   git push origin v$(cat VERSION)-rc1
   ```

The tag push fires `build-iso.yml`. The main push (if PKGBUILDs
changed) fires `build-packages.yml`.

### VERSION/tag guardrail

`build-iso.yml` has an early step that strips the leading `v` and any
`-rcN` suffix from the pushed tag and compares it to the `VERSION`
file. Mismatch fails the build in ~5s before any expensive work runs.

This exists because `VERSION` drives the **Calamares branding**
(`Makefile` lines 212-215, plain `$(VERSION)` — not the tag-aware
`$(ISO_VER)`), so a stale `VERSION` would ship an ISO whose filename
and installer UI disagree. The guardrail makes that impossible.

The guardrail is skipped on `workflow_dispatch` from branches so manual
dry-runs on `main` still work.

## CI workflows

### `build-packages.yml`

- **Trigger**: push to `main` touching `packaging/**`, `archiso/airootfs/**`, or `packages/**`.
- **Container**: `archlinux:latest` with `pacman-key --init --populate archlinux`.
- **Steps**:
  1. Import `SHEDOS_REPO_SIGNING_KEY`, `--lsign-key` it.
  2. For each `packaging/shedos-*/`: `makepkg --syncdeps --noconfirm --sign`.
  3. Collect `.pkg.tar.zst` + `.sig` into `dist/x86_64/`.
  4. `repo-add --sign` produces `shedos.db.tar.gz`, `shedos.files.tar.gz`, and their sigs.
  5. Duplicate `.db.tar.gz` → `.db` (R2 no symlinks; same for `.files`).
  6. `rclone sync dist/x86_64/ r2:shedos-repo/x86_64/`.
- **AUR cache**: shared cache key with `build-iso.yml` so the ISO
  workflow's 35-min AUR prebuild warms this workflow's cache too (and
  vice versa).

### `build-iso.yml`

- **Trigger**: push of a tag matching `v*`. Also `workflow_dispatch` for manual runs.
- **Environment**: `SHEDOS_ENV` (R2 secrets live here).
- **Permissions**: `contents: write` (needed for the Release page since
  org defaults are often read-only).
- **Steps**:
  1. Verify `VERSION` matches tag (guardrail — see above).
  2. Restore AUR package cache.
  3. `make download-packages` to prebuild AUR into `archiso/shedos-repo/`.
  4. Save AUR cache (unconditional on miss, even on later failure).
  5. `make shedos-packages` to build `shedos-*` into `archiso/shedos-repo/`.
  6. `make iso SHEDOS_ISO_TAG=<stripped>` — env overrides `VERSION` for ISO filename + profiledef stamping.
  7. Compute per-file `<iso>.sha256`.
  8. `rclone copy` ISO + `.sha256` to `r2:shedos-repo/iso/`.
  9. **Retention sweep** (see below).
  10. `softprops/action-gh-release` attaches the `.sha256` to the GH
      Release (ISO itself is >2 GiB — over GitHub's per-file cap —
      so only the checksum ships to GitHub, body points to R2).

### Retention sweep

Run on every successful `build-iso.yml`:

```
KEEP_STABLES=2
KEEP_RCS=1
```

Lists every `shedos-*-x86_64.iso` at the top level of `/iso/`, splits
by RC-vs-stable (filename regex), sorts lex-ascending (CalVer sorts
chronologically that way), and deletes everything except the tail `N`
of each bucket. Each `.iso` is deleted with its sibling `.sha256`.

Why these numbers:

- **2 stables** — the current one for fresh installs, the previous one
  as a rollback lifeline if the newest stable ships broken.
- **1 RC** — RCs are user-review artifacts; once the next RC lands the
  previous one is superseded.

Installed users don't care about old ISOs (they upgrade via
`pacman -Syu` from `/x86_64/`, not by reinstalling). Keeping fewer is
free bucket-space savings.

The sweep also purges the legacy nested `iso/v*/` layout if any
directories still exist (one-time migration). Safe to re-run.

## Adding a new `shedos-*` package

1. Create `packaging/shedos-<name>/` with a PKGBUILD that reads
   `pkgver` from the root `VERSION` (look at existing packages for the
   pattern).
2. If the package ships user configs, use the **dual-install pattern**:
   install to `/etc/skel/` *and* `/usr/share/shedos/shedos-<name>/defaults/`.
   The second path is what `shedman config --sync` reads.
3. If its sync behavior should be stricter (always conflict instead of
   auto-merge), ship a policy file at
   `/usr/share/shedos/shedos-<name>/sync-policy` containing
   `always-conflict`.
4. Add the package name to `scripts/render-meta-depends.sh`'s
   `SHEDOS_PKGS` array so it lands in `shedos-meta`'s `depends=()`.
5. Run `scripts/render-meta-depends.sh` to regenerate `shedos-meta/PKGBUILD`.
6. Commit + push. `build-packages.yml` picks it up automatically via
   the `packaging/**` path filter.

If your package ships an executable that should be a `shedman`
subcommand, drop it in `/usr/libexec/shedman/` and follow the
plugin convention — see [plugins.md](plugins.md) for the
`--help-summary` / `--complete-{bash,zsh,fish}` contract.

## Changing what a default install ships

`archiso/packages.x86_64` is **generated**, not hand-edited. The real
source is:

- `packages/official/*.txt` — Arch repo packages, grouped by category.
- `packages/aur.txt` — AUR packages (republishable + proprietary).
- `packages/aur-norepublish.txt` — subset of `aur.txt` we can't legally
  rebundle (vscode, chrome, slack, …). Stays as optdepends on
  `shedos-meta`; excluded from `packages.x86_64`.

After editing any of those:

```bash
scripts/generate-package-list.sh  # rewrites archiso/packages.x86_64
scripts/render-meta-depends.sh    # rewrites packaging/shedos-meta/PKGBUILD
```

Both generators read the same three files. Keep them in sync by always
re-running both.

Why `packages.x86_64` is flat: see the header comment on
`generate-package-list.sh`. TL;DR — pacman's virtual-dep provider pick
is alphabetical under `--noconfirm`, so every chosen provider has to
live at the root of the resolution graph (explicit in
`packages.x86_64`) or we get unresolvable conflicts during pacstrap.

## Debugging

### "Invalid or corrupted package" on user upgrade

Almost always a signature issue. Check:

```bash
pacman -Qi shedos-keyring     # is it installed and up to date?
pacman-key --list-keys        # is the shedos fingerprint trusted?
```

If the keyring package is outdated, `pacman -Sy shedos-keyring` then
retry the upgrade.

### CI: `build-packages.yml` fails at signing step

Signing key fingerprint in the secret disagrees with
`packaging/shedos-keyring/tree/shedos-trusted`. Check both; the
workflow's validation step names the expected vs found fingerprint.

### CI: `build-iso.yml` fails at pacstrap with "conflicting packages"

Some explicit-provider pick got dropped out of `packages.x86_64`.
Check the header comment on `generate-package-list.sh` for the usual
suspects (`pipewire-jack`, `virtualbox-host-modules-arch`,
`qt6-multimedia-ffmpeg`) and make sure they're in
`packages/official/audio.txt` etc. Re-run `generate-package-list.sh`.

### ISO filename doesn't match the tag

`SHEDOS_ISO_TAG` env wasn't set. In CI, this is set from
`github.ref_name` with the leading `v` stripped. Locally, pass it on
the `make iso` command line if you want to override `VERSION`:

```bash
make iso SHEDOS_ISO_TAG=2026.04.28-rc1
```
