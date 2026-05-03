#!/usr/bin/env bash
# Build out/install.sfs — the squashfs Calamares unpackfs writes onto /target.
# Pacstrap a full developer install (shedos-meta closure + AUR proprietaries)
# into a scratch dir, then mksquashfs zstd-22.
#
# Env (all optional):
#   SHEDOS_OUT_DIR         (default $repo/out) — install.sfs lands here
#   SHEDOS_LOCAL_REPO_DIR  (default $repo/archiso/shedos-repo) — local pkgs
#   SHEDOS_FORCE_REBUILD   (set =1 to rebuild even if install.sfs exists)
#
# Must run as root (pacstrap + mksquashfs).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must be run as root" >&2
    exit 1
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
out_dir=${SHEDOS_OUT_DIR:-$root/out}
local_repo=${SHEDOS_LOCAL_REPO_DIR:-$root/archiso/shedos-repo}

mkdir -p "$out_dir"

if [[ -f "$out_dir/install.sfs" && -z "${SHEDOS_FORCE_REBUILD:-}" ]]; then
    sz=$(stat -c %s "$out_dir/install.sfs")
    echo "install.sfs exists ($(numfmt --to=iec --suffix=B "$sz")); skipping. SHEDOS_FORCE_REBUILD=1 to rebuild."
    exit 0
fi

if [[ ! -d $local_repo ]] || ! ls "$local_repo"/shedos-meta-*.pkg.tar.zst >/dev/null 2>&1; then
    echo "ERROR: $local_repo missing shedos-meta-*.pkg.tar.zst — run 'sudo make shedos-packages' first" >&2
    exit 1
fi

tmpdir=$(mktemp -d)
scratch=$(mktemp -d -p /tmp shedos-install.XXXXXX)
trap 'rm -rf "$tmpdir" "$scratch"' EXIT

cat > "$tmpdir/pacman.conf" <<EOF
[options]
HoldPkg     = pacman glibc
Architecture = x86_64
SigLevel    = Never
LocalFileSigLevel = Optional

[shedos-repo]
SigLevel = Never
Server = file://$local_repo

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

# Pacstrap roots:
#   - base, base-devel: Arch core
#   - shedos-meta: pulls the full Arch closure + republishable AUR + every
#     shedos-* via depends=() (rendered by scripts/render-meta-depends.sh)
#   - shedos-kernel + headers: split package; -headers isn't a dir, list it
#   - aur-norepublish.txt entries: optdepends on shedos-meta, so pacstrap
#     won't pull them transitively; list explicitly here (they're already
#     built into archiso/shedos-repo/ by build-aur-packages.sh)
roots=(
    base
    base-devel
    shedos-meta
    shedos-kernel
    shedos-kernel-headers
)

if [[ -f "$root/packages/aur-norepublish.txt" ]]; then
    while IFS= read -r p; do
        [[ -z $p || $p == \#* ]] && continue
        roots+=("$p")
    done < <(grep -hEv '^\s*(#|$)' "$root/packages/aur-norepublish.txt")
fi

# Same provider tie-breaks the now-removed shedos_pacstrap module used.
# Stops pacman from auto-picking jack2 over pipewire-jack, etc.
ignore=jack2,iptables-legacy,booster,dracut,jdk21-openjdk,jdk25-openjdk,qt6-multimedia-gstreamer,pipewire-media-session,gnu-free-fonts,ttf-bitstream-vera,ttf-croscore,ttf-droid,ttf-ibm-plex,ttf-input,ttf-input-nerd,ttf-roboto

echo "Pacstrapping ${#roots[@]} roots into $scratch ..."
pacstrap -K -C "$tmpdir/pacman.conf" "$scratch" "${roots[@]}" "--ignore=$ignore"

# Empty the pacman cache inside the scratch — pacstrap leaves the .pkg.tar.zst
# files in /var/cache/pacman/pkg/ which would bloat install.sfs by hundreds
# of MB without adding any installed-system value (pacman -Syu post-boot
# fetches fresh).
rm -f "$scratch"/var/cache/pacman/pkg/*.pkg.tar.zst

echo "Building install.sfs at zstd-22 ..."
mksquashfs "$scratch" "$out_dir/install.sfs" \
    -comp zstd -Xcompression-level 22 -b 1M \
    -noappend -no-progress -no-recovery -wildcards

pacman -Q --root "$scratch" --dbpath "$scratch/var/lib/pacman" \
    | awk '{print $1}' | LC_ALL=C sort > "$out_dir/install-manifest.txt"

sz=$(stat -c %s "$out_dir/install.sfs")
echo "install.sfs: $(numfmt --to=iec --suffix=B "$sz"), $(wc -l < "$out_dir/install-manifest.txt") packages"
