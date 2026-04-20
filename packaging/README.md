# ShedOS packaging

Native Arch packages that make up a ShedOS installation. Published to
[repo.shedos.org](https://repo.shedos.org) by CI on every push to `main`.

| Package | Ships |
|---|---|
| `shedos-keyring` | GPG pubkey + `pacman-key` bootstrap for the `[shedos]` repo |
| `shedos-system` | Root-owned system payload: `/usr/bin/shedos-*`, systemd units, `/etc` drop-ins, `[shedos]` pacman repo block |
| `shedos-hyprland` | Hyprland desktop profile: `/etc/skel/.config/{hypr,waybar,walker,kitty,mako,rofi,fastfetch,mise}/` + zsh dotfiles, plus pristine mirror under `/usr/share/shedos/hyprland/defaults/` for `shedos-sync-configs` |
| `shedos-nvim` | Default Neovim config (same dual-install pattern). Separate package so its stricter sync policy doesn't pollute the generic tool. |
| `shedos-branding` | Plymouth theme, wallpapers, SDDM theme, `/etc/shedos-ascii.txt`, `/etc/os-release` |
| `shedos-meta` | Zero-file metapackage — `depends=` pulls in every ShedOS package plus every Arch package ShedOS needs. This is the source of truth that replaces `archiso/packages.x86_64`. |
| `shedos-migrate-to-packaged` | One-shot migration script for users on pre-packaged ShedOS installs. |

## Building locally

```
cd packaging/shedos-system
makepkg -s
```

## Publishing (CI only)

See `.github/workflows/build-packages.yml`. On push to `main`, all PKGBUILDs
are built and signed with the key in `SHEDOS_REPO_SIGNING_KEY`, then
`rclone sync`-ed to the `shedos-repo` R2 bucket.
