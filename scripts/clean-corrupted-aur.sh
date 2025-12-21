#!/bin/bash
# Clean corrupted AUR packages from system cache
# AUR packages should only come from archiso/shedos-repo/

echo "Cleaning corrupted AUR packages from /var/cache/pacman/pkg/..."

sudo rm -f /var/cache/pacman/pkg/walker-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/elephant*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/calamares-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/yay-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/visual-studio-code-bin-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/google-chrome-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/slack-desktop-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/obsidian-bin-*.pkg.tar.zst*
sudo rm -f /var/cache/pacman/pkg/hadolint-bin-*.pkg.tar.zst*

echo "Done! AUR packages removed from system cache."
echo "These packages will only come from archiso/shedos-repo/ during ISO build."
