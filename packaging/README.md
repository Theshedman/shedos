# ShedOS packaging

Native Arch packages that make up a ShedOS installation. Published to
[`repo.shedos.org`](https://repo.shedos.org) by CI on every push to `main`.

| Package | Ships |
|---|---|
| `shedos-keyring` | GPG pubkey + `pacman-key` trust bootstrap for the `[shedos]` repo (post-install hook `pacman-key --add` + `--lsign-key`). |
| `shedos-system` | Root-owned system payload: unified `shedman` CLI + subcommands under `/usr/libexec/shedman/` (with legacy `shedos-*` shims at `/usr/bin/` for back-compat), systemd units, `/etc` drop-ins. Appends the `[shedos]` pacman repo block to `/etc/pacman.conf` on install (idempotent marker block). |
| `shedos-hyprland` | Hyprland desktop profile: `/etc/skel/.config/{hypr,waybar,walker,kitty,mako,rofi,fastfetch,mise}/` + zsh dotfiles, plus pristine mirror under `/usr/share/shedos/hyprland/defaults/` for `shedman config --sync`. |
| `shedos-nvim` | Default Neovim config (same dual-install pattern). Separate package so its `always-conflict` sync policy doesn't pollute the generic tool. |
| `shedos-branding` | Plymouth theme, wallpapers, `/etc/shedos-ascii.txt` (`/etc/os-release` ships from `shedos-system`). |
| `shedos-meta` | Zero-file metapackage. `depends=` pulls in every `shedos-*` package plus every Arch / AUR package a default install needs. |
| `shedos-migrate-to-packaged` | One-shot migration helper for users on pre-packaged ShedOS installs. |

For the user-facing CLI reference (every `shedman` subcommand + flags,
plus pacman / yay cheatsheets) see
[shedos.org/docs/commands](https://shedos.org/docs/commands).

## Versioning

Packages version independently: each `shedos-*` PKGBUILD keeps the
CalVer `pkgver` of its last content change, and CI bumps
`pkgver`/`pkgrel` only for packages whose content hash moved since
the previous release (`scripts/bump-version.sh`, manifest at
`packaging/.last-release-hashes.toml` — never run it locally; CI owns
the bump). The root `VERSION` file names the release/ISO cohort, so
individual package versions routinely differ from it and from each
other. The repo currently carries fourteen packages, including the
repackaged externals (calamares, cage).

## Two pacman repos, one name per purpose

ShedOS CI and the ISO build both deal with two custom repos — easy to
confuse, so:

| Repo | Where it lives | What it's for |
|---|---|---|
| `[shedos-repo]` | `archiso/shedos-repo/` on the build host (ephemeral) | Holds AUR + shedos-* packages pre-built during ISO assembly so `mkarchiso` can resolve them via `file://`. Never shipped. |
| `[shedos]` (stable) | `https://repo.shedos.org/stable/$arch` (signed, persistent, on R2) | The production repo. Installed systems pull `pacman -Syu` from here. Updated only on stable tag promotions. |
| `[shedos-testing]` | `https://repo.shedos.org/test/$arch` | Always-fresh channel. Receives every push to `main` and every RC. Stable tag promotes its contents to `[shedos]` (no rebuild). |

The ISO's `/etc/pacman.conf` has both blocks during `mkarchiso`. The
installed system only has `[shedos]` — `shedos-system`'s `post_install`
scriptlet appends it between `# >>> shedos <<<` markers, and `pre_remove`
strips it back out.

## The metapackage pipeline

There are two outputs feeding the live ISO and the installed-system
update path:

```
packages/official/*.txt   ──► scripts/generate-package-list.sh ──► archiso/packages.x86_64
                                                                   (full pacstrap list for the ISO)

packages/official/*.txt   ──┐
packages/aur.txt          ──┼─► scripts/render-meta-depends.sh ─► packaging/shedos-meta/PKGBUILD
packages/aur-norepublish  ──┘                                     (closure for installed-system updates)
shedos-* package names    ──┘
```

`archiso/packages.x86_64` is the flat resolved closure that
`mkarchiso` pacstraps into the live ISO's airootfs at build time. The
squashfs that lands on a user's disk via Calamares' `unpackfs` step
is that same airootfs, so this list defines what a fresh install
ships with. Every transitive dep is named explicitly so pacman has
no virtual-provider rolls to make.

`shedos-meta` is the metapackage installed systems pull from
`[shedos]` at update time. It depends on every shedos-* package and
every redistributable Arch + AUR package a default install needs.

Regenerate after editing `packages/*.txt`:

```bash
sudo scripts/resolve-meta-closure.sh    # rewrites packages/.meta-closure.txt
scripts/render-meta-depends.sh          # rewrites packaging/shedos-meta/PKGBUILD
sudo scripts/generate-package-list.sh   # rewrites archiso/packages.x86_64
```

`packages.x86_64` is **flat by design**: pacman with `--noconfirm`
picks virtual-dep providers alphabetically, so every chosen provider
must be at the root of the resolution graph or pacstrap collides.

**`aur-norepublish.txt`** lists AUR packages whose vendor EULAs forbid
republishing the `.pkg.tar.zst` signed by the ShedOS key (Chrome,
Postman, Claude Code, JetBrains Toolbox, MS fonts). They are still
built locally during the ISO build and bundled into the airootfs
squashfs — legally equivalent to a user running `yay -S <pkg>`
themselves. They show up as `optdepends=` on `shedos-meta` for
visibility.

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
