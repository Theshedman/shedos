# shedOS

> A developer-focused Arch Linux distribution with Hyprland, BTRFS, and comprehensive development tools.

## ✨ Features

### 🖥️ Desktop Experience
- **Hyprland**: Tiling window manager with **Catppuccin Mocha** theme.
- **Waybar**: Enhanced status bar with media controls, bluetooth, and keyboard state.
- **Walker**: Application launcher with 7+ search engines (StackOverflow, Arch Wiki, etc.).
- **Visuals**: Custom geometric wallpapers and consistent "shedOS" branding.

### 🚀 Productivity
- **Screen Recording**: Built-in interactive menu (`Super+R`).
- **Color Picker**: Integrated `hyprpicker` (`Super+Shift+P`).
- **Clipboard**: History manager via Walker (`Super+C`).

### 🛠️ Developer Ready
- **Tools**: Neovim (LazyVim), VSCode, Zsh + Oh My Zsh.
- **Languages**: Pre-configured for Python, Node, Go, Rust, C++.
- **Containers**: Docker, Podman, K8s tools ready.

### 🔒 System
- **Immutable-style Builds**: Deterministic ISO generation.
- **BTRFS**: Pre-configured subvolumes and snapshots.
- **Secure**: Optional LUKS encryption.

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

## 🏗️ Building shedOS

shedOS uses a **deterministic build system** to ensure stability.

### 1. Download Packages (Run Once)
This step downloads and freezes all package versions (including AUR) to ensure offline build capability.

```bash
sudo make download-packages
```

### 2. Build ISO
Uses the frozen packages to generate the ISO.

```bash
sudo make iso
```

## 🧪 Testing

```bash
# Test in UEFI Mode
./scripts/test-iso.sh

# Test in Legacy BIOS Mode
./scripts/test-iso.sh bios
```

## 📂 Directory Structure

```
shedos/
├── archiso/          # Archiso profile
├── installer/        # Python TUI installer
├── configs/          # Default configurations
├── packages/         # Package lists
├── branding/         # Logos, wallpapers, themes
├── scripts/          # Build and test scripts
├── docs/             # Documentation
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

Contributions are welcome! Please read the contributing guidelines before submitting PRs.

## License

GPL-3.0
