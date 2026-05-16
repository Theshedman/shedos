# Maintainer: ShedOS <https://github.com/Theshedman/shedos>
#
# The ShedOS Hyprland desktop profile: every dotfile under /etc/skel/ that a
# new shedos user gets on first login, plus the walker/waybar/hyprsunset
# helpers bound to keys in hyprland.conf. Named -hyprland (not -desktop) so
# shedos-gnome / shedos-kde-plasma can coexist in the same repo later.
#
# Dual-installed: everything under /etc/skel/ is mirrored byte-for-byte at
# /usr/share/shedos/hyprland/defaults/. The mirror is the pristine source
# `shedman config --sync` compares against for its 3-way merge.

pkgname=shedos-hyprland
pkgver=2026.05.16
pkgrel=1
pkgdesc='ShedOS Hyprland desktop profile (dotfiles + DE helpers)'
arch=('any')
url='https://github.com/Theshedman/shedos'
license=('GPL-3.0-or-later')
install=shedos-hyprland.install
depends=(
    'shedos-system'
    'hyprland'
    'waybar'
    'walker'
    'kitty'
    'mako'
    'rofi'
    'fastfetch'
    'mise-bin'
    'zsh'
    'oh-my-zsh-git'
    'zsh-theme-powerlevel10k-git'
    'zsh-autosuggestions'
    'zsh-syntax-highlighting'
    'hyprsunset'
    'pacman-contrib'
    'yad'
    'inotify-tools'
    'nwg-dock-hyprland'   # application dock; ExecStart for shedos-dock.service
    'nwg-drawer'          # full-screen app drawer (dock's default launcher)
    'shedos-power'        # Rust GUI overlay execd by `shedman power` (waybar power icon)
    'shedos-hyprland-plugin-hyprspace'   # workspace overview (macOS Mission Control style) for the 3-finger swipe up gesture
)
optdepends=(
    'impala: network TUI launched from waybar network icon'
    'pavucontrol: volume mixer launched from waybar pulseaudio icon'
    'blueman: bluetooth manager launched from waybar'
    'btop: system monitor launched from waybar cpu icon'
    'wf-recorder: required for `shedman screenrecord` (Super+R / waybar pill)'
    'slurp: region selection for `shedman screenrecord --region`'
)

package() {
    cd "$startdir"

    # /etc/skel/; seed for new users via useradd -m.
    cp -a tree/etc "$pkgdir/"

    # /usr/share/shedos/hyprland/defaults/; pristine mirror for sync tool.
    # Identical to what we put in /etc/skel/, rooted at the same layout the
    # user sees (so relpath logic in `shedman config --sync` is straightforward).
    install -d "$pkgdir/usr/share/shedos/hyprland/defaults"
    cp -a tree/etc/skel/. "$pkgdir/usr/share/shedos/hyprland/defaults/"

    # DE-specific shedman subcommands: `shedman launcher` (Walker),
    # `shedman power` (shutdown/reboot/logout confirm), and
    # `shedman screenrecord` (wf-recorder wrapper + waybar indicator).
    install -d "$pkgdir/usr/libexec/shedman"
    local _libexec_shedman=(browser keybindings launcher power screenrecord)
    local _name
    for _name in "${_libexec_shedman[@]}"; do
        install -Dm755 "tree/usr/libexec/shedman/$_name" \
            "$pkgdir/usr/libexec/shedman/$_name"
    done

    install -Dm644 tree/usr/lib/systemd/user/shedos-hypr-reload.path \
        "$pkgdir/usr/lib/systemd/user/shedos-hypr-reload.path"
    install -Dm644 tree/usr/lib/systemd/user/shedos-hypr-reload.service \
        "$pkgdir/usr/lib/systemd/user/shedos-hypr-reload.service"

    # waybar launch wrapper + drop-in. The wrapper ensures LANG and
    # locale archive are in a workable state before exec'ing waybar so
    # the clock module's L (locale) format modifier doesn't disable
    # the module on a session where the locale is missing.
    install -Dm755 tree/usr/lib/shedos/waybar-launch.sh \
        "$pkgdir/usr/lib/shedos/waybar-launch.sh"
    install -Dm644 tree/usr/lib/systemd/user/waybar.service.d/shedos-locale.conf \
        "$pkgdir/usr/lib/systemd/user/waybar.service.d/shedos-locale.conf"

    # Application dock: systemd user unit + python wrapper that reads
    # ~/.config/shedos/dock.toml, spawns one nwg-dock-hyprland per
    # monitor, and execs nwg-drawer for the launcher button. The unit
    # is auto-enabled per-user via the graphical-session.target.wants
    # symlink shipped under /etc/skel/ (handled by the `cp -a tree/etc`
    # above). The pinned-app seed under /usr/share/shedos/hyprland/ is
    # what start-dock.py copies into ~/.cache/nwg-dock-hyprland/ on
    # first run (cache dir is the dock's own pin-state location).
    install -Dm644 tree/usr/lib/systemd/user/shedos-dock.service \
        "$pkgdir/usr/lib/systemd/user/shedos-dock.service"
    install -Dm755 tree/usr/lib/shedos/start-dock.py \
        "$pkgdir/usr/lib/shedos/start-dock.py"
    install -Dm644 tree/usr/share/shedos/hyprland/nwg-dock-pinned-default \
        "$pkgdir/usr/share/shedos/hyprland/nwg-dock-pinned-default"

    # nwg-drawer as a resident systemd user unit, plus the launcher-button
    # wrapper that sends SIGUSR1 to toggle visibility. Same auto-enable
    # mechanism as shedos-dock — symlink in /etc/skel/.config/systemd/...
    install -Dm644 tree/usr/lib/systemd/user/shedos-drawer.service \
        "$pkgdir/usr/lib/systemd/user/shedos-drawer.service"
    install -Dm755 tree/usr/lib/shedos/toggle-drawer.sh \
        "$pkgdir/usr/lib/shedos/toggle-drawer.sh"

    # Click-outside-to-close catcher — invisible full-screen layer-shell
    # surface on the `top` layer (one below the drawer's `overlay`).
    # Clicks on the drawer hit the drawer; clicks anywhere else fall
    # through to the catcher, which sends the drawer's hide signal.
    # Visibility is gated on Hyprland openlayer/closelayer events so the
    # catcher is inactive whenever the drawer is closed.
    install -Dm644 tree/usr/lib/systemd/user/shedos-click-catcher.service \
        "$pkgdir/usr/lib/systemd/user/shedos-click-catcher.service"
    install -Dm755 tree/usr/lib/shedos/click-catcher.py \
        "$pkgdir/usr/lib/shedos/click-catcher.py"

    install -Dm644 tree/usr/lib/systemd/user/shedos-lock-migration.service \
        "$pkgdir/usr/lib/systemd/user/shedos-lock-migration.service"
    install -Dm755 tree/usr/libexec/shedos-hyprland/lock-migration \
        "$pkgdir/usr/libexec/shedos-hyprland/lock-migration"
    install -Dm644 tree/usr/lib/systemd/user/shedos-wallpaper.service \
        "$pkgdir/usr/lib/systemd/user/shedos-wallpaper.service"
    install -d "$pkgdir/usr/libexec/shedos-postupgrade"
    ln -sf ../shedos-hyprland/lock-migration \
        "$pkgdir/usr/libexec/shedos-postupgrade/lock-migration"

    # uwsm's wayland-wm@.service template inherits stderr from its
    # caller, ending at /dev/console. Drop-in pins Hyprland's stderr
    # to journal so wlroots backend logs don't leak to tty1's vcs
    # buffer and get painted by fbcon during DRM-master gaps.
    install -Dm644 tree/etc/systemd/user/wayland-wm@.service.d/journal-only.conf \
        "$pkgdir/etc/systemd/user/wayland-wm@.service.d/journal-only.conf"
    install -Dm644 tree/etc/systemd/user/wayland-wm@.service.d/restart.conf \
        "$pkgdir/etc/systemd/user/wayland-wm@.service.d/restart.conf"
    install -Dm644 tree/etc/systemd/user/wayland-session-shutdown.target \
        "$pkgdir/etc/systemd/user/wayland-session-shutdown.target"
    install -Dm755 tree/usr/lib/shedos/relock-on-restart \
        "$pkgdir/usr/lib/shedos/relock-on-restart"

    # Silent back-compat shims for the old /usr/bin/shedos-* names.
    local _shims=(
        shedos-launch-walker shedos-power-confirm
        shedos-screenrecord shedos-screenrecord-indicator
    )
    for _name in "${_shims[@]}"; do
        install -Dm755 "tree/usr/bin/$_name" "$pkgdir/usr/bin/$_name"
    done

    install -Dm755 tree/usr/bin/toggle-hyprsunset.sh \
        "$pkgdir/usr/bin/toggle-hyprsunset.sh"

    # "Terminal" alias for kitty so users searching the launcher for
    # "term" / "terminal" find it. The elephant-desktopapplications
    # provider is configured with only_search_title=true, so it matches
    # by Name only; Categories=TerminalEmulator alone isn't enough. We
    # ship a parallel .desktop with Name=Terminal pointing at kitty.
    install -Dm644 tree/usr/share/applications/terminal.desktop \
        "$pkgdir/usr/share/applications/terminal.desktop"

    # /usr/share/shedos-hyprland/ assets used by waybar and `shedman
    # keybindings`. shedos-s.png is the logo painted in waybar's leftmost
    # pill (#custom-shedos-logo background-image). keybindings-{dialog.css,
    # meta.toml} feed the libexec keybindings dialog.
    install -Dm644 tree/usr/share/shedos-hyprland/shedos-s.png \
        "$pkgdir/usr/share/shedos-hyprland/shedos-s.png"
    install -Dm644 tree/usr/share/shedos-hyprland/keybindings-dialog.css \
        "$pkgdir/usr/share/shedos-hyprland/keybindings-dialog.css"
    install -Dm644 tree/usr/share/shedos-hyprland/keybindings-meta.toml \
        "$pkgdir/usr/share/shedos-hyprland/keybindings-meta.toml"
    install -Dm644 tree/usr/share/shedos-hyprland/launcher.svg \
        "$pkgdir/usr/share/shedos-hyprland/launcher.svg"
}
