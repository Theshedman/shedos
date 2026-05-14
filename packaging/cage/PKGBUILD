# Maintainer: ShedOS <https://github.com/Theshedman/shedos>
#
# Patched cage with touchpad tap-to-click enabled by default. cage is
# the kiosk Wayland compositor that greetd hosts shedos-greeter inside,
# but cage has no input-configuration surface — every libinput pointer
# device is attached with the upstream libinput defaults, which leaves
# tap-to-click disabled. That's the wrong default for a modern laptop
# login screen; users expect to tap the power glyph (or anything else)
# rather than be forced into a physical click.
#
# This package supersedes the upstream Arch `cage` (declared via
# provides=/conflicts=) so pacman swaps it in cleanly. The single
# downstream patch lives in 0001-enable-touchpad-tap-by-default.patch
# and should rebase trivially across point releases — handle_new_pointer
# has been stable in cage's source since v0.1.

pkgname=cage
pkgver=0.3.0
pkgrel=1
pkgdesc='Wayland kiosk compositor (ShedOS: touchpad tap-to-click on by default)'
arch=('x86_64')
url='https://github.com/cage-kiosk/cage'
license=('MIT')

depends=(
    'glibc'
    'libinput'
    'libxkbcommon'
    'wayland'
    'wlroots0.20'
)

makedepends=(
    'meson'
    'scdoc'
    'wayland-protocols'
)

provides=('cage')
conflicts=('cage')

source=(
    "cage-$pkgver.tar.gz::https://github.com/cage-kiosk/cage/archive/v$pkgver.tar.gz"
    '0001-enable-touchpad-tap-by-default.patch'
)
sha256sums=(
    'f32e6885444e365de3bc076d307c20eff59ee42ed0237219eebd3d2fe597e289'
    '7449ef5011d484653269737ee54b626fc17c6e82ea88a5d98d9df8c36b2ca9ec'
)

prepare() {
    cd "$srcdir/cage-$pkgver"
    patch -p1 -i "$srcdir/0001-enable-touchpad-tap-by-default.patch"
}

build() {
    arch-meson "$srcdir/cage-$pkgver" build
    meson compile -C build
}

package() {
    meson install -C build --destdir "$pkgdir"
    install -Dm644 "$srcdir/cage-$pkgver/LICENSE" \
        "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
