#!/usr/bin/env bash
# Build out/bundle.sfs for Calamares' unpackfs module.
# Env: SHEDOS_BUNDLE_BUDGET_BYTES, SHEDOS_OUT_DIR, SHEDOS_LOCAL_REPO_DIR.
# Set SHEDOS_FORCE_BUNDLE=1 to rebuild when out/bundle.sfs already exists.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must be run as root (pacstrap, mksquashfs)." >&2
    echo "       Run: sudo $0" >&2
    exit 1
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
packages_dir=$root/packages
out_dir=${SHEDOS_OUT_DIR:-$root/out}
local_repo=${SHEDOS_LOCAL_REPO_DIR:-$root/archiso/shedos-repo}
budget=${SHEDOS_BUNDLE_BUDGET_BYTES:-2000000000}

closure_file=$packages_dir/.meta-closure.txt
if [[ ! -f $closure_file ]]; then
    echo "ERROR: $closure_file missing." >&2
    echo "       Run: sudo scripts/resolve-meta-closure.sh" >&2
    exit 1
fi

mkdir -p "$out_dir"

if [[ -f "$out_dir/bundle.sfs" && -z "${SHEDOS_FORCE_BUNDLE:-}" ]]; then
    sz=$(stat -c %s "$out_dir/bundle.sfs")
    echo "bundle.sfs exists ($(numfmt --to=iec --suffix=B "$sz")); skipping. SHEDOS_FORCE_BUNDLE=1 to rebuild."
    exit 0
fi

echo "Building bundle (budget $budget bytes)..."

mapfile -t closure < <(grep -hEv '^\s*(#|$)' "$closure_file" | sort -u)

declare -A skip_set=()
if [[ -f "$packages_dir/bundle-skip.txt" ]]; then
    while IFS= read -r p; do
        [[ -z $p || $p == \#* ]] && continue
        skip_set[$p]=1
    done < <(grep -hEv '^\s*(#|$)' "$packages_dir/bundle-skip.txt")
fi

declare -A pin_set=()
if [[ -f "$packages_dir/bundle-pin.txt" ]]; then
    while IFS= read -r p; do
        [[ -z $p || $p == \#* ]] && continue
        pin_set[$p]=1
    done < <(grep -hEv '^\s*(#|$)' "$packages_dir/bundle-pin.txt")
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/db"

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

pacman -Sy --noconfirm --dbpath "$tmpdir/db" --config "$tmpdir/pacman.conf" >/dev/null

declare -A pkg_size=()
current_pkg=""
while IFS= read -r line; do
    case "$line" in
        Name*:*)
            current_pkg=${line#*: }
            current_pkg=${current_pkg// /}
            ;;
        "Installed Size"*:*)
            raw=${line#*: }
            value=$(awk '{print $1}' <<<"$raw")
            unit=$(awk '{print $2}' <<<"$raw")
            case "$unit" in
                B)   bytes=$(awk "BEGIN {print int($value)}") ;;
                KiB) bytes=$(awk "BEGIN {print int($value * 1024)}") ;;
                MiB) bytes=$(awk "BEGIN {print int($value * 1024 * 1024)}") ;;
                GiB) bytes=$(awk "BEGIN {print int($value * 1024 * 1024 * 1024)}") ;;
                *)   bytes=0 ;;
            esac
            [[ -n $current_pkg ]] && pkg_size[$current_pkg]=$bytes
            ;;
    esac
done < <(pacman -Si --dbpath "$tmpdir/db" --config "$tmpdir/pacman.conf" "${closure[@]}" 2>/dev/null)

mapfile -t sorted < <(
    for pkg in "${closure[@]}"; do
        printf '%d\t%s\n' "${pkg_size[$pkg]:-0}" "$pkg"
    done | LC_ALL=C sort -k1,1nr -k2,2
)

declare -A bundle_set=()
total_bytes=0
fitted=0
skipped=0
for entry in "${sorted[@]}"; do
    size=${entry%%$'\t'*}
    pkg=${entry##*$'\t'}
    [[ -z $pkg ]] && continue
    if [[ -n ${skip_set[$pkg]:-} ]]; then
        skipped=$((skipped + 1))
        continue
    fi
    if (( total_bytes + size <= budget )); then
        bundle_set[$pkg]=$size
        total_bytes=$((total_bytes + size))
        fitted=$((fitted + 1))
    fi
done

echo "fitted $fitted, skipped $skipped, total $total_bytes bytes"

forced=(
    base
    base-devel
    shedos-keyring
    shedos-meta
    shedos-kernel-headers
)
for d in "$root"/packaging/shedos-*/; do
    [[ -f "$d/PKGBUILD" ]] || continue
    forced+=("$(basename "$d")")
done

for p in "${forced[@]}" "${!pin_set[@]}"; do
    bundle_set[$p]=1
done

mapfile -t bundle_list < <(printf '%s\n' "${!bundle_set[@]}" | LC_ALL=C sort -u)

scratch=$(mktemp -d -p /tmp shedos-bundle.XXXXXX)
trap 'rm -rf "$tmpdir" "$scratch"' EXIT

pacstrap -K -C "$tmpdir/pacman.conf" "$scratch" "${bundle_list[@]}"

mksquashfs "$scratch" "$out_dir/bundle.sfs" \
    -comp xz -Xbcj x86 -b 1M \
    -noappend -no-progress -no-recovery -wildcards

pacman -Q --root "$scratch" --dbpath "$scratch/var/lib/pacman" \
    | awk '{print $1}' | LC_ALL=C sort > "$out_dir/bundle-manifest.txt"

bundle_size=$(stat -c %s "$out_dir/bundle.sfs")
echo "bundle.sfs: $(numfmt --to=iec --suffix=B "$bundle_size"), $(wc -l < "$out_dir/bundle-manifest.txt") packages"
