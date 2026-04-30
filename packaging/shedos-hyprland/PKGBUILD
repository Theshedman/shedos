# Maintainer: ShedOS <https://github.com/theshedman/shedos>
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
pkgver=2026.05.01
pkgrel=4
pkgdesc='ShedOS Hyprland desktop profile (dotfiles + DE helpers)'
arch=('any')
url='https://github.com/theshedman/shedos'
license=('GPL-3.0-or-later')
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

    # /etc/skel/ — seed for new users via useradd -m.
    cp -a tree/etc "$pkgdir/"

    # /usr/share/shedos/hyprland/defaults/ — pristine mirror for sync tool.
    # Identical to what we put in /etc/skel/, rooted at the same layout the
    # user sees (so relpath logic in `shedman config --sync` is straightforward).
    install -d "$pkgdir/usr/share/shedos/hyprland/defaults"
    cp -a tree/etc/skel/. "$pkgdir/usr/share/shedos/hyprland/defaults/"

    # DE-specific shedman subcommands: `shedman launcher` (Walker),
    # `shedman power` (shutdown/reboot/logout confirm), and
    # `shedman screenrecord` (wf-recorder wrapper + waybar indicator).
    install -d "$pkgdir/usr/libexec/shedman"
    local _libexec_shedman=(launcher power screenrecord)
    local _name
    for _name in "${_libexec_shedman[@]}"; do
        install -Dm755 "tree/usr/libexec/shedman/$_name" \
            "$pkgdir/usr/libexec/shedman/$_name"
    done

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
    # by Name only — Categories=TerminalEmulator alone isn't enough. We
    # ship a parallel .desktop with Name=Terminal pointing at kitty.
    install -Dm644 tree/usr/share/applications/terminal.desktop \
        "$pkgdir/usr/share/applications/terminal.desktop"
}
