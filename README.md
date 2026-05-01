# shedOS

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
- **Visuals**: Custom geometric wallpapers and consistent "shedOS" branding.

### 🚀 Productivity
- **Screen Recording**: Built-in interactive menu (`Super+R`).
- **Color Picker**: Integrated `hyprpicker` (`Super+Shift+P`).
- **Clipboard**: History manager via Walker (`Super+C`).

### 🛠️ Developer Ready
- **Tools**: Neovim (LazyVim), VSCode, Zsh + Oh My Zsh.
- **Languages**: Pre-configured for Python, Node, Go, Rust, C++.
- **Containers**: Docker + K8s tools ready (kubectl, kind, helm, k9s).

### 🔒 System
- **Native-package install**: All shedOS-specific content is delivered as signed Arch packages (see `packaging/`).
- **BTRFS**: Pre-configured subvolumes and snapshots.
- **Secure**: Optional LUKS encryption.
- **In-place upgrades**: `shedman update` + the waybar indicator surface updates the moment they land on the repo.

> **WiFi firmware:** ShedOS ships firmware for AMD/Intel/NVIDIA GPUs and Atheros + Realtek WiFi (covers ~95% of laptops). If your WiFi card is Mediatek, Marvell, Broadcom, or Qualcomm, run `pacman -S linux-firmware-mediatek` (or `-marvell` / `-broadcom` / `-qcom`) on a wired connection after first boot.

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

- **`/test/x86_64/`** — every push to `main` and every RC tag publishes
  here. Live ISOs (RC + dev) pacstrap from this channel at install time.
- **`/stable/x86_64/`** — frozen until promoted. Pushing a stable tag
  (`v<CalVer>` without `-rcN`) triggers `rclone copy /test/ → /stable/`
  in CI — no rebuild. Stable users `pacman -Syu` from here.

`bump-version.sh` is hash-aware (since v2026.05.02): only packages
whose content drifted since the manifest in
`packaging/.last-release-hashes.toml` get pkgver/pkgrel bumped. CI
caches per-package builds keyed on content hash, so unchanged
packages skip makepkg entirely.

The install model is **online pacstrap** at Calamares run time. The
live ISO is a lean ~1.5 GB Arch+Calamares environment; the full shedOS
arrives via `shedos-meta` from `/test/` (RC ISOs) or `/stable/`
(stable ISOs) during install.

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
├── archiso/              # Archiso profile (slimmed — live-only bits)
├── packaging/            # Native shedos-* Arch packages (source of truth)
├── packages/             # Package lists driving shedos-meta + the ISO
│   ├── official/*.txt    # Arch repo packages, by category
│   ├── aur.txt           # AUR packages
│   └── aur-norepublish.txt  # Proprietary AUR (optdepends only)
├── installer/            # Calamares modules + branding
├── branding/             # Logos, wallpapers, Plymouth assets
├── scripts/              # build, test, version-bump, package-list gen
├── docs/                 # User + maintainer docs
├── .github/workflows/    # build-packages.yml, build-iso.yml
├── Makefile
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
| `@temp` | `/tmp` | No | Temporary files |
| `@pkg` | `/var/cache/pacman/pkg` | No | Package cache |
| `@srv` | `/srv` | Yes | Server data |
| `@opt` | `/opt` | Yes | Optional software |
| `@libvirt` | `/var/lib/libvirt` | No | VM images |
| `@docker` | `/var/lib/docker` | No | Docker data |
| `@database` | `/var/lib/database` | No | Database storage |

## 🤝 Contributing

Contributions are welcome. Changes to `packaging/`, `packages/`, or
`archiso/airootfs/` ripple through CI automatically — see
`docs/repo-architecture.md` for what triggers what.

## License

GPL-3.0
