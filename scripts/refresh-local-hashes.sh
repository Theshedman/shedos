#!/usr/bin/env bash
# Refresh sha256sums*=() and b2sums*=() entries for LOCAL source files in
# a PKGBUILD. Skips URLs / VCS sources (which would otherwise force a
# re-download). Called per-package by bump-version.sh; idempotent.

set -euo pipefail

pkgbuild=$1
pkgdir=$(dirname "$pkgbuild")
cd "$pkgdir"

eval "$(
    set +u
    source ./PKGBUILD 2>/dev/null
    declare -p source 2>/dev/null || echo 'declare -a source=()'
    declare -p source_x86_64 2>/dev/null || echo 'declare -a source_x86_64=()'
    declare -p sha256sums 2>/dev/null || echo 'declare -a sha256sums=()'
    declare -p sha256sums_x86_64 2>/dev/null || echo 'declare -a sha256sums_x86_64=()'
    declare -p b2sums 2>/dev/null || echo 'declare -a b2sums=()'
    declare -p b2sums_x86_64 2>/dev/null || echo 'declare -a b2sums_x86_64=()'
)"

_is_local() {
    case "$1" in
        *://*|git+*|hg+*|svn+*|bzr+*) return 1 ;;
        *) return 0 ;;
    esac
}

# Rewrite a checksum only where it sits as a quoted array token, first match
# only. An unanchored s/old/new/ would rewrite the first hash-looking string
# anywhere in the file (a comment, a URL, a _commit= pin) — wrong line.
_sub_quoted_hash() {
    local old=$1 new=$2
    sed -i "0,/\\(['\"]\\)$old\\1/s//\\1$new\\1/" PKGBUILD
}

_refresh_array() {
    local src_name=$1 sha_name=$2 b2_name=$3
    declare -n src="$src_name" sha="$sha_name" b2="$b2_name"
    local idx entry file new_sha new_b2 old_sha old_b2
    for idx in "${!src[@]}"; do
        entry="${src[$idx]}"
        file="${entry##*::}"
        _is_local "$file" || continue
        [[ -f $file ]] || continue
        new_sha=$(sha256sum "$file" | awk '{print $1}')
        new_b2=$(b2sum "$file" | awk '{print $1}')
        old_sha="${sha[$idx]:-}"
        old_b2="${b2[$idx]:-}"
        if [[ -n $old_sha && $old_sha != SKIP && $old_sha != "$new_sha" ]]; then
            _sub_quoted_hash "$old_sha" "$new_sha"
            echo "    refresh $file: sha256 $old_sha → $new_sha"
        fi
        if [[ -n $old_b2 && $old_b2 != SKIP && $old_b2 != "$new_b2" ]]; then
            _sub_quoted_hash "$old_b2" "$new_b2"
            echo "    refresh $file: b2sum $old_b2 → $new_b2"
        fi
    done
}

_refresh_array source sha256sums b2sums
_refresh_array source_x86_64 sha256sums_x86_64 b2sums_x86_64
