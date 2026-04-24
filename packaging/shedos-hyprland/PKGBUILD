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
pkgver=2026.04.23
pkgrel=2
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
)
optdepends=(
    'impala: network TUI launched from waybar network icon'
    'pavucontrol: volume mixer launched from waybar pulseaudio icon'
    'blueman: bluetooth manager launched from waybar'
    'btop: system monitor launched from waybar cpu icon'
    'yad: dialog used by `shedman welcome`'
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

    # DE-specific shedman subcommands: `shedman launcher` (Walker) and
    # `shedman power` (shutdown/reboot/logout confirm).
    install -Dm755 tree/usr/libexec/shedman/launcher \
        "$pkgdir/usr/libexec/shedman/launcher"
    install -Dm755 tree/usr/libexec/shedman/power \
        "$pkgdir/usr/libexec/shedman/power"

    # Silent back-compat shims for the old /usr/bin/shedos-* names.
    install -Dm755 tree/usr/bin/shedos-launch-walker \
        "$pkgdir/usr/bin/shedos-launch-walker"
    install -Dm755 tree/usr/bin/shedos-power-confirm \
        "$pkgdir/usr/bin/shedos-power-confirm"

    install -Dm755 tree/usr/bin/toggle-hyprsunset.sh \
        "$pkgdir/usr/bin/toggle-hyprsunset.sh"
}
