#!/usr/bin/env bash
# Refuse to push commits that carry CI-managed release state. CI bumps pkgrel and
# packaging/.last-release-hashes.toml in its own auto-bump commit on every push to
# main; if those values ride in a hand-pushed commit, CI reads the package as
# already released, skips the rebuild, and the change never ships. `make push`
# runs this after the rebase, against the exact range about to land.
set -euo pipefail

range=${1:-origin/main..HEAD}
hashes=packaging/.last-release-hashes.toml

hash_hit=$(git diff --name-only "$range" -- "$hashes")
pkgrel_files=$(git diff "$range" -- '*PKGBUILD' | awk '
    /^diff --git/ { f=$3; sub(/^a\//, "", f) }
    /^[+-]pkgrel=/ { print f }
' | sort -u)

if [[ -z $hash_hit && -z $pkgrel_files ]]; then
    exit 0
fi

red=$'\033[0;31m'; nc=$'\033[0m'
{
    printf '\n%s✗ Push refused: this batch changes CI-managed release state.%s\n\n' "$red" "$nc"
    printf 'CI auto-bumps pkgrel and %s on every push to main. If those\n' "$hashes"
    printf 'ride in a hand-pushed commit, CI reads the package as already released, skips\n'
    printf 'the rebuild, and the change never ships — with no error.\n\n'
    printf 'Offending change(s) in %s:\n' "$range"
    [[ -n $hash_hit ]] && printf '    %s\n' "$hash_hit"
    [[ -n $pkgrel_files ]] && while IFS= read -r f; do printf '    %s  (pkgrel)\n' "$f"; done <<< "$pkgrel_files"
    printf '\nRestore them to origin/main and let CI bump them after the push:\n'
    [[ -n $hash_hit ]] && printf '    git checkout origin/main -- %s\n' "$hashes"
    [[ -n $pkgrel_files ]] && printf '    # set pkgrel back to origin/main, then git commit --amend (or rebase)\n'
    printf '\n'
} >&2
exit 1
