#!/usr/bin/env bash
# bump-version.sh — propagate VERSION into every shedos-* PKGBUILD.
#
# ShedOS uses CalVer (YYYY.MM.DD[.N]). The VERSION file at the repo root is
# the single source of truth. Each release cycle:
#
#   1. Edit VERSION (e.g. echo '2026.04.21' > VERSION) — or pass `--today`.
#   2. Run scripts/bump-version.sh. It rewrites pkgver= in every
#      packaging/shedos-*/PKGBUILD and resets pkgrel=1. Re-runs without a
#      VERSION change bump pkgrel instead (rebuild of same source).
#   3. Commit. Push. Tag `v<VERSION>[-rcN]` to fire build-iso.yml.
#
# Why one shared version across all six packages: `pacman -Qi shedos-meta`
# then tells a user exactly which release cohort their system is at, and the
# published repo serves a coherent set. Individual packages rarely move
# independently in practice (the payload is small and the team is small).

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
version_file=$root/VERSION

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
    echo "VERSION = $new_version (unchanged; re-run to rev pkgrel only)"
fi

# Validate CalVer shape. Accept YYYY.MM.DD or YYYY.MM.DD.N. Reject anything
# else loudly so typos don't silently ship.
if ! [[ $new_version =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
    echo "FATAL: VERSION '$new_version' is not CalVer (YYYY.MM.DD[.N])" >&2
    exit 1
fi

changed=0
for pkgbuild in "$root"/packaging/shedos-*/PKGBUILD; do
    pkg=$(basename "$(dirname "$pkgbuild")")
    current_ver=$(awk -F= '/^pkgver=/ {print $2; exit}' "$pkgbuild")
    current_rel=$(awk -F= '/^pkgrel=/ {print $2; exit}' "$pkgbuild")

    if [[ $current_ver == "$new_version" ]]; then
        # Same pkgver → bump pkgrel. Used when we republish without a content
        # change (rare; e.g. signing-key rotation).
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
    changed=$((changed + 1))
done

echo "Updated $changed PKGBUILDs."
echo
echo "Next:"
echo "  git diff packaging/ VERSION"
echo "  git add packaging/ VERSION && git commit -m 'release: v$new_version'"
echo "  git tag v$new_version   # or v$new_version-rc1 for a prerelease"
echo "  git push && git push --tags"
