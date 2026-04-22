# Maintainer: ShedOS <https://github.com/theshedman/shedos>
#
# Repository keyring for [shedos]. This is the *trust anchor* — every other
# ShedOS package is verified against the key this package installs. Do not
# delete or downgrade without understanding the consequences (pacman will
# start refusing ShedOS updates).
#
# Key rotation procedure: packaging/shedos-keyring/README.md

pkgname=shedos-keyring
pkgver=2026.04.21
pkgrel=3
pkgdesc='ShedOS repository keyring — trust anchor for [shedos]'
arch=('any')
url='https://github.com/theshedman/shedos'
license=('GPL-3.0-or-later')
install=shedos-keyring.install

package() {
    install -Dm644 "$startdir/tree/shedos.gpg" \
        "$pkgdir/usr/share/pacman/keyrings/shedos.gpg"
    install -Dm644 "$startdir/tree/shedos-trusted" \
        "$pkgdir/usr/share/pacman/keyrings/shedos-trusted"
    install -Dm755 "$startdir/tree/usr/lib/shedos-keyring/trust-keys.sh" \
        "$pkgdir/usr/lib/shedos-keyring/trust-keys.sh"
    install -Dm644 "$startdir/tree/usr/lib/systemd/system/shedos-keyring-trust.service" \
        "$pkgdir/usr/lib/systemd/system/shedos-keyring-trust.service"
}
