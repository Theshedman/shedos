#!/usr/bin/env bash
# Bump pkgver/pkgrel for shedos-* packages whose content hash changed
# since the last release. Hashes via compute-pkg-hash.sh; manifest at
# packaging/.last-release-hashes.toml.
#
# Modes:
#   bump-version.sh              Bump VERSION (or use --today / argv) and
#                                bump pkgrel for changed shedos-* packages.
#   bump-version.sh --check      Validate manifest matches the working tree.
#                                Exits non-zero on drift. (Runs
#                                refresh-local-hashes.sh first, which may
#                                rewrite hash stamps inside PKGBUILDs —
#                                no pkgver/pkgrel/manifest changes.)
#                                CI uses this to refuse pushes with a stale
#                                manifest.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
version_file=$root/VERSION
manifest=$root/packaging/.last-release-hashes.toml

mode=bump
explicit_version=

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            mode=check
            ;;
        --today)
            explicit_version=$(date +%Y.%m.%d)
            ;;
        -h|--help)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        -*)
            echo "unknown flag: $1" >&2
            exit 2
            ;;
        *)
            explicit_version=$1
            ;;
    esac
    shift
done

# Resolve VERSION (only meaningful in bump mode).
if [[ $mode == bump ]]; then
    if [[ -n $explicit_version ]]; then
        echo "$explicit_version" > "$version_file"
        new_version=$explicit_version
        echo "VERSION → $new_version"
    else
        new_version=$(cat "$version_file")
        echo "VERSION = $new_version (unchanged)"
    fi
    if ! [[ $new_version =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
        echo "FATAL: VERSION '$new_version' is not CalVer (YYYY.MM.DD[.N])" >&2
        exit 1
    fi
fi

# Robust PKGBUILD field reader.
#   - Handles `field=value`, `field='value'`, `field="value"`,
#     with optional trailing `# comment`.
#   - Refuses dynamic values (`$(...)`, backticks, ${...}); bump-version
#     can't safely round-trip those, so failing loud beats silently
#     mangling them with sed.
_read_pkgbuild_field() {
    local pkgbuild=$1 field=$2
    local raw
    raw=$(awk -v f="$field" '
        $0 ~ "^"f"=" {
            sub("^"f"=", "")
            sub("[ \t]*#.*$", "")
            sub("^[\047\"]", "")
            sub("[\047\"]$", "")
            print
            exit
        }
    ' "$pkgbuild")
    if [[ -z $raw ]]; then
        echo "FATAL: $pkgbuild has no $field= line" >&2
        return 1
    fi
    if [[ $raw == *'$('* || $raw == *'`'* || $raw == *'${'* ]]; then
        echo "FATAL: $pkgbuild has dynamic $field=$raw; static value required" >&2
        return 1
    fi
    printf '%s' "$raw"
}

# Read the existing manifest.
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
declare -A drifted=()
changed=0
unchanged=0

# Every PKGBUILD under packaging/, not just shedos-*: the repackaged
# externals (calamares, cage) used to sit outside the hash system, so
# content edits without a manual pkgrel bump shipped stale cached
# binaries.
for pkgbuild in "$root"/packaging/*/PKGBUILD; do
    pkg=$(basename "$(dirname "$pkgbuild")")
    bash "$here/refresh-local-hashes.sh" "$pkgbuild"
    h=$("$here/compute-pkg-hash.sh" "$pkg")
    prev=${last_hash[$pkg]:-}

    current_ver=$(_read_pkgbuild_field "$pkgbuild" pkgver)
    current_rel=$(_read_pkgbuild_field "$pkgbuild" pkgrel)

    if [[ -n $prev && $prev == "$h" ]]; then
        echo "  $pkg: unchanged ($current_ver-$current_rel)"
        new_hash[$pkg]=$h
        unchanged=$((unchanged + 1))
        continue
    fi

    drifted[$pkg]=content

    if [[ $mode == check ]]; then
        echo "  $pkg: drifted (content $h differs from manifest ${prev:-none})"
        continue
    fi

    if [[ $pkg != shedos-* ]]; then
        # Repackaged externals (calamares, cage) keep their upstream
        # pkgver; only the rebuild counter moves.
        new_rel=$((current_rel + 1))
        sed -i "s/^pkgrel=.*/pkgrel=$new_rel/" "$pkgbuild"
        echo "  $pkg: pkgrel $current_rel → $new_rel (external; pkgver untouched)"
    elif [[ $current_ver == "$new_version" ]]; then
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
    new_hash[$pkg]=$("$here/compute-pkg-hash.sh" "$pkg")
    changed=$((changed + 1))
done

if [[ $mode == check ]]; then
    if (( ${#drifted[@]} > 0 )); then
        echo
        echo "FATAL: ${#drifted[@]} package(s) drifted from manifest:" >&2
        for pkg in $(printf '%s\n' "${!drifted[@]}" | LC_ALL=C sort); do
            printf '  - %s (%s)\n' "$pkg" "${drifted[$pkg]}" >&2
        done
        echo
        echo "Run \`make bump\` (or \`make bump-today\`) and commit the result." >&2
        exit 1
    fi
    echo "Manifest matches working tree."
    exit 0
fi

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
echo "Updated $changed PKGBUILD(s); unchanged $unchanged."
echo "Manifest: $manifest"
echo
echo "Next:"
echo "  git diff packaging/ VERSION"
echo "  git add packaging/ VERSION && git commit -m 'release: v$new_version'"
echo "  git tag v$new_version   # or v$new_version-rc1 for a prerelease"
echo "  git push && git push --tags"
