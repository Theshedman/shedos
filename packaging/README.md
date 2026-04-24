# ShedOS packaging

Native Arch packages that make up a ShedOS installation. Published to
[`repo.shedos.org`](https://repo.shedos.org) by CI on every push to `main`.

| Package | Ships |
|---|---|
| `shedos-keyring` | GPG pubkey + `pacman-key` trust bootstrap for the `[shedos]` repo (post-install hook `pacman-key --add` + `--lsign-key`). |
| `shedos-system` | Root-owned system payload: unified `shedman` CLI + subcommands under `/usr/libexec/shedman/` (with legacy `shedos-*` shims at `/usr/bin/` for back-compat), systemd units, `/etc` drop-ins. Appends the `[shedos]` pacman repo block to `/etc/pacman.conf` on install (idempotent marker block). |
| `shedos-hyprland` | Hyprland desktop profile: `/etc/skel/.config/{hypr,waybar,walker,kitty,mako,rofi,fastfetch,mise}/` + zsh dotfiles, plus pristine mirror under `/usr/share/shedos/hyprland/defaults/` for `shedman config --sync`. |
| `shedos-nvim` | Default Neovim config (same dual-install pattern). Separate package so its `always-conflict` sync policy doesn't pollute the generic tool. |
| `shedos-branding` | Plymouth theme, wallpapers, SDDM theme, `/etc/shedos-ascii.txt`, `/etc/os-release`. |
| `shedos-meta` | Zero-file metapackage. `depends=` pulls in every `shedos-*` package plus every Arch / AUR package a default install needs. |
| `shedos-migrate-to-packaged` | One-shot migration helper for users on pre-packaged ShedOS installs. |

For the user-facing CLI reference (every `shedman` subcommand + flags,
plus pacman / yay cheatsheets) see
[shedos.org/docs/commands](https://shedos.org/docs/commands).

## Versioning

Every `shedos-*` PKGBUILD's `pkgver` is driven from the root `VERSION`
file. Bump it with `scripts/bump-version.sh [--today | <version>]` — the
script rewrites every `pkgver=` and resets `pkgrel=1`. Re-running on an
unchanged `VERSION` increments `pkgrel` instead (republish of same source).
One shared version across all six packages means `pacman -Qi shedos-meta`
tells a user exactly which release cohort their system is on.

## Two pacman repos, one name per purpose

ShedOS CI and the ISO build both deal with two custom repos — easy to
confuse, so:

| Repo | Where it lives | What it's for |
|---|---|---|
| `[shedos-build]` | `archiso/shedos-repo/` on the build host (ephemeral) | Holds AUR packages pre-built by `scripts/build-aur-packages.sh` so `pacstrap` can resolve AUR deps without network AUR access. Never shipped. |
| `[shedos]` | `https://repo.shedos.org/$arch` (signed, persistent, on R2) | The production repo. Shipped on every install via `shedos-system`'s install hook. This is where `pacman -Syu` pulls ShedOS updates from. |

The ISO's `/etc/pacman.conf` has both blocks during `mkarchiso`. The
installed system only has `[shedos]` — `shedos-system`'s `post_install`
scriptlet appends it between `# >>> shedos <<<` markers, and `pre_remove`
strips it back out.

## The metapackage pipeline

`packages.x86_64` (the list `mkarchiso`'s `pacstrap` reads) is a **flat,
explicit** list of every package we want at the root of pacman's
resolution graph. Flat for a reason: pacman with `--noconfirm` picks
providers for virtual deps (`jack`, `virtualbox-host-modules`,
`qt6-multimedia-backend`, …) alphabetically from whichever providers it
encounters *first*. If our chosen provider (e.g. `pipewire-jack`) lives
only in `shedos-meta`'s transitive `depends=`, pacman resolves the
virtual dep against the default *before* descending into our choice —
the two collide and the build fails.

The pipeline:

```
packages/official/*.txt   ──┐
packages/aur.txt          ──┼─► scripts/generate-package-list.sh ─► archiso/packages.x86_64
packages/aur-norepublish  ──┘                                       (flat, ~449 entries)
                          
packages/official/*.txt   ──┐
packages/aur.txt          ──┼─► scripts/render-meta-depends.sh ─► packaging/shedos-meta/PKGBUILD
shedos-* package names    ──┘                                     (depends=()`
```

Two generators, one source of truth. Regenerate after editing any
`packages/*.txt`:

```bash
scripts/generate-package-list.sh    # rewrites archiso/packages.x86_64
scripts/render-meta-depends.sh      # rewrites packaging/shedos-meta/PKGBUILD
```

**`aur-norepublish.txt`** lists AUR packages that we can't legally
republish binaries for (proprietary: vscode, chrome, slack, obsidian,
postman, ms-fonts). These stay as `optdepends=()` on `shedos-meta` and
install via `yay`/`shedman welcome` post-boot, never via `pacstrap`.

## Dual-install pattern (for `shedos-hyprland`, `shedos-nvim`)

Config packages install the same tree to two places:

| Path | Role |
|---|---|
| `/etc/skel/.config/<app>/` | Seed copy for new users at `useradd -m`. |
| `/usr/share/shedos/<pkg>/defaults/.config/<app>/` | Pristine reference `shedman config --sync` compares against to detect user edits and upstream changes. |

`shedman config --sync` runs a per-file 3-way merge after `pacman -Syu`.
If the user hasn't touched a file, it auto-updates; if they have, it
drops a `.shedosnew` alongside instead of clobbering. See
[`docs/upgrading.md`](../docs/upgrading.md) for the full algorithm and
the `always-conflict` policy `shedos-nvim` uses.

## Building locally

```bash
cd packaging/shedos-system
makepkg -s
```

For the whole set via the Makefile (builds into `archiso/shedos-repo/`):

```bash
make shedos-packages
```

## Publishing (CI only)

See `.github/workflows/build-packages.yml`. On push to `main` touching
`packaging/**`, `archiso/airootfs/**`, or `packages/**`:

1. Import signing key from `SHEDOS_REPO_SIGNING_KEY` secret.
2. `makepkg --syncdeps --noconfirm --sign` in each `packaging/shedos-*/`.
3. `repo-add --sign` produces `shedos.db.tar.gz` + `.files.tar.gz` + sigs.
4. `rclone sync` publishes `dist/x86_64/` to `r2:shedos-repo/x86_64/`.

From then on every installed system can `pacman -Syu` and pull the new
packages. Signatures are verified against the key in `shedos-keyring`.
