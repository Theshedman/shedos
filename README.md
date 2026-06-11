# ShedOS

> A developer-focused Arch Linux distribution with Hyprland, BTRFS, and a rolling-release upgrade story.

**Website:** [shedos.org](https://shedos.org)

ShedOS ships as an ISO and a signed pacman repo at
[`repo.shedos.org`](https://repo.shedos.org). Once installed, an existing
system stays current via `pacman -Syu` — no reinstall, no image swap.

## ✨ Features

### 🖥️ Desktop Experience
- **Hyprland**: Tiling window manager with **Catppuccin Mocha** theme.
- **Waybar**: Status bar with media controls, bluetooth, keyboard state, and an update-available indicator.
- **Walker**: Application launcher with 7+ search engines (StackOverflow, Arch Wiki, etc.).
- **Visuals**: Custom geometric wallpapers and consistent "ShedOS" branding.

### 🚀 Productivity
- **Screen Recording**: Built-in interactive menu (`Super+R`).
- **Color Picker**: Integrated `hyprpicker` (`Super+Shift+P`).
- **Clipboard**: History manager via Walker (`Super+C`).

### 🛠️ Developer Ready
- **Tools**: Neovim (LazyVim), VSCode, Zsh + Oh My Zsh.
- **Languages**: Pre-configured for Python, Node, Go, Rust, C++.
- **Containers**: Docker + K8s tools ready (kubectl, minikube, helm, lazydocker).

### 🔒 System
- **Native-package install**: All ShedOS-specific content is delivered as signed Arch packages (see `packaging/`).
- **BTRFS**: Pre-configured subvolumes and snapshots.
- **Secure**: Optional LUKS encryption.
- **In-place upgrades**: `shedman update` + the waybar indicator surface updates the moment they land on the repo.

> **WiFi firmware:** ShedOS ships the linux-firmware splits for AMD/Intel/NVIDIA GPUs plus Atheros, Realtek, Mediatek, Marvell, Broadcom, and more out of the box — WiFi works on first boot on virtually all laptops.

> **Printing:** not in the default install. `pacman -S cups hplip system-config-printer` if you need it.

## ⌨️ Keybindings Cheatsheet

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (Kitty) |
| `Super + D` | Launcher (Walker) |
| `Super + B` | Browser |
| `Super + R` | **Record Screen** (Menu) |
| `Super + Shift + R` | Stop Recording |
| `Super + Shift + P` | Color Picker |
| `Super + C` | Clipboard History |

## 🔄 Upgrading an installed system

Click the waybar update indicator, or run:

```bash
shedman update
```

It surfaces the list of pending updates, waits for your explicit `y/N`, runs
`pacman -Syu`, then prompts again before `shedman config --sync` touches any
dotfiles. See [`docs/upgrading.md`](docs/upgrading.md) for the full flow,
including how conflicts surface as `.shedosnew` files (same model as
pacman's `.pacnew`).

No ISO reinstall is required to move between releases.

## 🧰 Commands

Every ShedOS utility is a subcommand of `shedman`. The headline set:

| Command | Does |
|---|---|
| `shedman` | List every subcommand with summaries. |
| `shedman update` | Interactive upgrade (`pacman -Syu` + `yay -Sua` + config sync, bracketed by a snapper snapshot pair). |
| `shedman config --sync` | 3-way merge packaged defaults into `$HOME`; conflicts land as `.shedosnew`. |
| `shedman status` | One-screen dashboard (updates, conflicts, health, doctor). |
| `shedman rollback -l` | Show recent snapper snapshots to roll back to. |
| `shedman help <cmd>` | Full usage for any subcommand. |

For the full CLI reference (every flag, short aliases, pacman/yay
cheatsheets) see [shedos.org/docs/commands](https://shedos.org/docs/commands).

## 🏗️ Building from source

```bash
# One-time: hydrate the build-local AUR repo (archiso/shedos-repo/).
sudo make download-packages

# Build the ISO.
sudo make iso
```

The ISO picks up `VERSION` from the repo root. For a versioned build
matching a release tag, set `SHEDOS_ISO_TAG` (this is what CI does):

```bash
sudo make iso SHEDOS_ISO_TAG=2026.04.21-rc2
```

## 📦 Release model

ShedOS uses **CalVer** (`YYYY.MM.DD`) with optional `-rcN` suffix:

- `v2026.05.02-rc1`, `v2026.05.02-rc2`, … — release candidates of one cycle.
- `v2026.05.02` — stable cut of that cycle.

Two channels at `repo.shedos.org`:

- **`/test/x86_64/`** — every push to `main` and every RC tag
  publishes here. Receiving channel for in-development packages.
- **`/stable/x86_64/`** — frozen until promoted. Pushing a stable tag
  (`v<CalVer>` without `-rcN`) triggers `rclone copy /test/ → /stable/`
  in CI — no rebuild. Stable users `pacman -Syu` from here.

`bump-version.sh` is hash-aware: only packages whose content drifted
since the manifest in `packaging/.last-release-hashes.toml` get
pkgver/pkgrel bumped. CI caches per-package builds keyed on content
hash, so unchanged packages skip makepkg entirely.

Installs are fully offline. The ISO ships every package needed for
a default ShedOS install. `mkarchiso` pacstraps the full environment
into the airootfs squashfs at build time, and Calamares copies that
squashfs onto `/target` with `unpackfs`. Target install time is 5–8
minutes; no network connection is required.

For the full pipeline (R2 bucket layout, signing, retention sweep,
build incrementality) see
[`docs/repo-architecture.md`](docs/repo-architecture.md).

## 🧪 Testing

```bash
# UEFI
./scripts/test-iso.sh

# Legacy BIOS
./scripts/test-iso.sh bios
```

## 📂 Directory Structure

```
shedos/
├── archiso/              # Archiso profile for the live + install ISO
├── packaging/            # Native shedos-* PKGBUILDs (source of truth)
├── packages/             # Package source-of-truth lists
│   ├── official/*.txt    # Arch repo packages, by category
│   ├── aur.txt           # AUR packages built locally and shipped
│   └── aur-norepublish.txt  # Proprietary AUR (bundled into ISO, never republished)
├── installer/            # Calamares branding + custom Python modules + shared library
├── branding/             # Wallpapers, ASCII logos, /etc/issue, /etc/motd
├── scripts/              # Build, release, and package-list helpers
├── docs/                 # Maintainer documentation
├── site/                 # Astro source for shedos.org
├── test/                 # Fixture-driven test suites
├── .github/workflows/    # CI: build-packages, build-iso,
│                         #     aur-cache-refresh, deploy-site
├── architecture.txt      # System architecture overview
├── Makefile
├── LICENSE
└── VERSION
```

## BTRFS Subvolume Layout

| Subvolume | Mountpoint | CoW | Purpose |
|-----------|------------|-----|---------|
| `@` | `/` | Yes | Root filesystem |
| `@home` | `/home` | Yes | User data |
| `@var` | `/var` | Yes | Variable data |
| `@snapshots` | `/.snapshots` | Yes | Snapper snapshots |
| `@log` | `/var/log` | No | System logs |
| `@cache` | `/var/cache` | No | Cache files |
| `@tmp` | `/tmp` | No | Temporary files |
| `@pkg` | `/var/cache/pacman/pkg` | No | Package cache |
| `@srv` | `/srv` | Yes | Server data |
| `@opt` | `/opt` | Yes | Optional software |
| `@docker` | `/var/lib/docker` | No | Docker data |
| `@machines` | `/var/lib/machines` | No | systemd-nspawn / VM images |

## 🤝 Contributing

Contributions are welcome. Changes to `packaging/`, `packages/`, or
`archiso/airootfs/` ripple through CI automatically — see
`docs/repo-architecture.md` for what triggers what.

## License

GPL-3.0
