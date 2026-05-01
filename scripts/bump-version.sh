#!/usr/bin/env bash
# Bump pkgver/pkgrel for shedos-* packages whose content hash changed
# since the last release. Hashes via compute-pkg-hash.sh; manifest at
# packaging/.last-release-hashes.toml. Unchanged packages stay at
# their previous version. shedos-kernel is skipped (tracks linux-zen).

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
version_file=$root/VERSION
manifest=$root/packaging/.last-release-hashes.toml

if [[ ${1:-} == --today ]]; then
    new_version=$(date +%Y.%m.%d)
    echo "$new_version" > "$version_file"
    echo "VERSION → $new_version (from --today)"
elif [[ $# -gt 0 && ${1:-} != -* ]]; then
    new_version=$1
    echo "$new_version" > "$version_file"
    echo "VERSION → $new_version (from argv)"
else
    new_version=$(cat "$version_file")
    echo "VERSION = $new_version (unchanged)"
fi

if ! [[ $new_version =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
    echo "FATAL: VERSION '$new_version' is not CalVer (YYYY.MM.DD[.N])" >&2
    exit 1
fi

declare -A skip_pkgs=(
    [shedos-kernel]=1
)

declare -A last_hash=()
if [[ -f $manifest ]]; then
    while IFS= read -r line; do
        [[ -z $line || ${line:0:1} == '#' ]] && continue
        k=${line%%=*}
        k=${k// /}
        [[ -z $k ]] && continue
        v=${line#*=}
        v=${v// /}
        v=${v//\"/}
        last_hash[$k]=$v
    done < "$manifest"
fi

declare -A new_hash=()
changed=0
unchanged=0
skipped=0

for pkgbuild in "$root"/packaging/shedos-*/PKGBUILD; do
    pkg=$(basename "$(dirname "$pkgbuild")")
    if [[ -n ${skip_pkgs[$pkg]:-} ]]; then
        echo "  $pkg: skipped (tracks upstream pkgver)"
        skipped=$((skipped + 1))
        continue
    fi

    h=$("$here"/compute-pkg-hash.sh "$pkg")

    current_ver=$(awk -F= '/^pkgver=/ {print $2; exit}' "$pkgbuild")
    current_rel=$(awk -F= '/^pkgrel=/ {print $2; exit}' "$pkgbuild")
    prev=${last_hash[$pkg]:-}

    if [[ -n $prev && $prev == "$h" ]]; then
        echo "  $pkg: unchanged ($current_ver-$current_rel)"
        new_hash[$pkg]=$h
        unchanged=$((unchanged + 1))
        continue
    fi

    if [[ $current_ver == "$new_version" ]]; then
        new_rel=$((current_rel + 1))
        sed -i "s/^pkgrel=.*/pkgrel=$new_rel/" "$pkgbuild"
        echo "  $pkg: pkgrel $current_rel → $new_rel"
    else
        sed -i \
            -e "s/^pkgver=.*/pkgver=$new_version/" \
            -e "s/^pkgrel=.*/pkgrel=1/" \
            "$pkgbuild"
        echo "  $pkg: $current_ver-$current_rel → $new_version-1"
    fi
    # Recompute hash AFTER the bump so the manifest reflects the
    # post-bump state. Otherwise the next run sees the stored pre-bump
    # hash as "changed" (because pkgrel is in the hash) and bumps again.
    new_hash[$pkg]=$("$here"/compute-pkg-hash.sh "$pkg")
    changed=$((changed + 1))
done

{
    cat <<'EOF'
# Auto-managed by scripts/bump-version.sh. Each entry records the
# content hash of packaging/<pkgname>/ as of the most recent release.
# Compared against current hashes on every run to decide what to bump.

EOF
    for pkg in $(printf '%s\n' "${!new_hash[@]}" | LC_ALL=C sort); do
        printf '%s = "%s"\n' "$pkg" "${new_hash[$pkg]}"
    done
} > "$manifest"

echo
echo "Updated $changed PKGBUILD(s); unchanged $unchanged; skipped $skipped."
echo "Manifest: $manifest"
echo
echo "Next:"
echo "  git diff packaging/ VERSION"
echo "  git add packaging/ VERSION && git commit -m 'release: v$new_version'"
echo "  git tag v$new_version   # or v$new_version-rc1 for a prerelease"
echo "  git push && git push --tags"
