# ShedOS packaging

Native Arch packages that make up a ShedOS installation. Published to
[`repo.shedos.org`](https://repo.shedos.org) by CI on every push to `main`.

| Package | Ships |
|---|---|
| `shedos-keyring` | GPG pubkey + `pacman-key` trust bootstrap for the `[shedos]` repo (post-install hook `pacman-key --add` + `--lsign-key`). |
| `shedos-system` | Root-owned system payload: unified `shedman` CLI + subcommands under `/usr/libexec/shedman/` (with legacy `shedos-*` shims at `/usr/bin/` for back-compat), systemd units, `/etc` drop-ins. Appends the `[shedos]` pacman repo block to `/etc/pacman.conf` on install (idempotent marker block). |
| `shedos-hyprland` | Hyprland desktop profile: `/etc/skel/.config/{hypr,waybar,walker,kitty,mako,rofi,fastfetch,mise}/` + zsh dotfiles, plus pristine mirror under `/usr/share/shedos/hyprland/defaults/` for `shedman config --sync`. |
| `shedos-nvim` | Default Neovim config (same dual-install pattern). Separate package so its `always-conflict` sync policy doesn't pollute the generic tool. |
| `shedos-branding` | Plymouth theme, wallpapers, `/etc/shedos-ascii.txt`, `/etc/os-release`. |
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
| `[shedos-repo]` | `archiso/shedos-repo/` on the build host (ephemeral) | Holds AUR + shedos-* packages pre-built during ISO assembly so `mkarchiso` can resolve them via `file://`. Never shipped. |
| `[shedos]` (stable) | `https://repo.shedos.org/stable/$arch` (signed, persistent, on R2) | The production repo. Installed systems pull `pacman -Syu` from here. Updated only on stable tag promotions. |
| `[shedos-testing]` | `https://repo.shedos.org/test/$arch` | Always-fresh channel. Receives every push to `main` and every RC. Live ISOs pacstrap from here at install time. Stable tag promotes its contents to `[shedos]`. |

The ISO's `/etc/pacman.conf` has both blocks during `mkarchiso`. The
installed system only has `[shedos]` — `shedos-system`'s `post_install`
scriptlet appends it between `# >>> shedos <<<` markers, and `pre_remove`
strips it back out.

## The metapackage pipeline

There are two outputs and two source-of-truth scopes:

```
packages/official/{base,installer}.txt ──► scripts/generate-package-list.sh ──► archiso/packages.x86_64
                                           (live ISO only — ~116 packages)

packages/official/*.txt   ──┐
packages/aur.txt          ──┼─► scripts/render-meta-depends.sh ─► packaging/shedos-meta/PKGBUILD
packages/aur-norepublish  ──┘                                     (the full installed system)
shedos-* package names    ──┘
```

`archiso/packages.x86_64` is the **lean** package set that mkarchiso
pacstraps into the live ISO airootfs — just enough to boot the
installer (base + Calamares deps + 5 extras: calamares, hyprland,
kitty, shedos-branding, shedos-keyring). The installer pacstraps the
full shedOS to /target at install time, pulling `shedos-meta` (which
transitively deps every package in `packages/official/*.txt` +
republishable AUR) from `[shedos-testing]` over HTTPS.

`packages.x86_64` is still **flat by design**: pacman with `--noconfirm`
picks virtual-dep providers alphabetically, so every chosen provider
must be at the root of the resolution graph or pacstrap collides.

Regenerate after editing `packages/*.txt`:

```bash
scripts/generate-package-list.sh    # rewrites archiso/packages.x86_64
scripts/render-meta-depends.sh      # rewrites packaging/shedos-meta/PKGBUILD
```

**`aur-norepublish.txt`** lists AUR packages whose EULAs forbid us
republishing binaries (proprietary: chrome, postman, slack, obsidian,
ms-fonts). These stay as `optdepends=()` on `shedos-meta`. Calamares'
optional-apps screen handles installing them at install time via
`yay`-in-chroot; users can also `shedman install <pkg>` post-boot.

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
4. `rclone sync` publishes `dist/x86_64/` to `r2:shedos-repo/test/x86_64/`. Stable tag promotes `/test/x86_64/` → `/stable/x86_64/` (no rebuild).

From then on every installed system can `pacman -Syu` and pull the new
packages. Signatures are verified against the key in `shedos-keyring`.
