#!/usr/bin/env bash
# Update packaging/shedos-kernel/{PKGBUILD,config.x86_64} from upstream
# Arch linux-zen at a given tag. The kernel-version-watcher workflow
# fires this against `--latest`; humans usually pass an explicit pkgver.
#
# Usage:
#   scripts/bump-kernel.sh --latest          # query Arch's current pkgver
#   scripts/bump-kernel.sh 6.19.15.zen1      # pin to a specific upstream
#
# Side effects: rewrites packaging/shedos-kernel/{PKGBUILD,config.x86_64}.
# Does not git add / commit / push — leaves the diff for the caller to
# review and stage.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
pkg_dir=$root/packaging/shedos-kernel
pkgbuild=$pkg_dir/PKGBUILD
config_file=$pkg_dir/config.x86_64

if [[ ! -f $pkgbuild ]]; then
    echo "FATAL: $pkgbuild missing — wrong repo root?" >&2
    exit 2
fi

target=${1:-}
if [[ -z $target ]]; then
    echo "Usage: $(basename "$0") --latest | <pkgver>" >&2
    exit 2
fi

if [[ $target == --latest ]]; then
    target=$(curl -fsS https://archlinux.org/packages/extra/x86_64/linux-zen/json/ \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['pkgver'])")
    echo "Latest Arch linux-zen: $target"
fi

if ! [[ $target =~ ^[0-9]+\.[0-9]+\.[0-9]+\.zen[0-9]+$ ]]; then
    echo "FATAL: '$target' is not a valid linux-zen pkgver (expected M.m.p.zenN)" >&2
    exit 2
fi

current=$(awk -F= '/^pkgver=/ {print $2; exit}' "$pkgbuild")
if [[ $current == "$target" ]]; then
    echo "shedos-kernel already at $target — nothing to do"
    exit 0
fi

# Arch tags packaging-repo releases as <pkgver>-<pkgrel>. We pin pkgrel=1
# because the kernel-version-watcher only fires when pkgver moves.
tag="${target}-1"
base="https://gitlab.archlinux.org/archlinux/packaging/packages/linux-zen/-/raw/${tag}"

echo "Fetching $base/PKGBUILD…"
upstream_pkgbuild=$(mktemp)
trap 'rm -f -- "$upstream_pkgbuild"' EXIT
curl -fsS -o "$upstream_pkgbuild" "$base/PKGBUILD"

# Extract the four checksum arrays we mirror.
_extract_array() {
    local name=$1 file=$2
    awk -v name="$name" '
        $0 ~ "^"name"=\\(" {capturing=1}
        capturing {print}
        capturing && /\)$/ {exit}
    ' "$file"
}

new_b2sums=$(_extract_array "b2sums" "$upstream_pkgbuild")
new_sha256sums=$(_extract_array "sha256sums" "$upstream_pkgbuild")
new_b2sums_x86_64=$(_extract_array "b2sums_x86_64" "$upstream_pkgbuild")
new_sha256sums_x86_64=$(_extract_array "sha256sums_x86_64" "$upstream_pkgbuild")

if [[ -z $new_b2sums || -z $new_sha256sums ]]; then
    echo "FATAL: couldn't extract checksum arrays from upstream PKGBUILD" >&2
    exit 1
fi

echo "Fetching $base/config.x86_64…"
curl -fsS -o "$config_file" "$base/config.x86_64"
local_x86_64_sha=$(sha256sum "$config_file" | awk '{print $1}')

# Cross-check our config matches the sha256 listed upstream — if not,
# our extraction is buggy or upstream's checksum is wrong.
upstream_x86_64_sha=$(echo "$new_sha256sums_x86_64" \
    | awk -F"'" '/[0-9a-f]{64}/ {print $2; exit}')
if [[ -n $upstream_x86_64_sha && $upstream_x86_64_sha != "$local_x86_64_sha" ]]; then
    echo "FATAL: downloaded config.x86_64 sha256 ($local_x86_64_sha) doesn't match upstream sha256sums_x86_64 ($upstream_x86_64_sha)" >&2
    exit 1
fi

# Rewrite our PKGBUILD: pkgver, pkgrel=1, then swap each array.
sed -i "s/^pkgver=.*/pkgver=$target/" "$pkgbuild"
sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"

_replace_array() {
    local name=$1 new_block_path=$2 file=$3
    python3 - "$name" "$new_block_path" "$file" <<'PY'
import re, sys
name, new_path, target = sys.argv[1], sys.argv[2], sys.argv[3]
with open(new_path) as f: new_block = f.read().rstrip("\n")
with open(target) as f: src = f.read()
pattern = re.compile(rf'^{re.escape(name)}=\(.*?^\)', re.MULTILINE | re.DOTALL)
if not pattern.search(src):
    sys.exit(f"missing {name}=( … ) block in {target}")
with open(target, 'w') as f:
    f.write(pattern.sub(new_block, src, count=1))
PY
}

# Stash each new array body in a temp file and pass the path; lets us
# round-trip arbitrary newline / quote content without shell-quoting hell.
tmpdir=$(mktemp -d)
trap 'rm -rf -- "$upstream_pkgbuild" "$tmpdir"' EXIT
printf '%s' "$new_b2sums"            > "$tmpdir/b2sums"
printf '%s' "$new_sha256sums"        > "$tmpdir/sha256sums"
printf '%s' "$new_b2sums_x86_64"     > "$tmpdir/b2sums_x86_64"
printf '%s' "$new_sha256sums_x86_64" > "$tmpdir/sha256sums_x86_64"

_replace_array b2sums            "$tmpdir/b2sums"            "$pkgbuild"
_replace_array sha256sums        "$tmpdir/sha256sums"        "$pkgbuild"
_replace_array b2sums_x86_64     "$tmpdir/b2sums_x86_64"     "$pkgbuild"
_replace_array sha256sums_x86_64 "$tmpdir/sha256sums_x86_64" "$pkgbuild"

echo "shedos-kernel: $current → $target"
echo "Diff:"
git -C "$root" --no-pager diff --stat -- packaging/shedos-kernel/ || true
echo
echo "Next:"
echo "  git -C $root add packaging/shedos-kernel/"
echo "  git -C $root commit -S -m 'kernel: bump to $target'"
