#!/usr/bin/env bash
# Run every test/<suite>/run.sh and roll up the result. Exit non-zero if
# any suite fails. Suites are hermetic — they stub pacman/systemctl/snapper/
# ufw/yad and redirect their surface roots, so this needs no root and never
# touches the host system. Optional deps (textual, scdoc, zsh, …) are
# skipped per-suite when absent, so install them in CI for full coverage.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/.." && pwd)

pass=0
fail=0
failed=()

for runner in "$repo_root"/test/*/run.sh; do
    suite=$(basename "$(dirname "$runner")")
    printf '════════ %s ════════\n' "$suite"
    if bash "$runner"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        failed+=("$suite")
    fi
    echo
done

printf '════════ %d suites passed, %d failed ════════\n' "$pass" "$fail"
if (( fail > 0 )); then
    printf 'failed: %s\n' "${failed[*]}" >&2
    exit 1
fi
