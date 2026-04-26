#!/usr/bin/env bash
# Read-only-mode tests for shedos-screensaver. Mirrors the shape of
# test/screenrecord/run.sh: hermetic, no live terminal mucking
# beyond the pty test (T11) which uses script(1) to allocate a tty
# without disturbing the runner's terminal.
#
# Run from the repo root: `bash test/screensaver/run.sh`. The Makefile
# wires this as `make test-screensaver`.

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." &> /dev/null && pwd)

# Locate the binary: prefer the cargo release build (created by
# `cargo build --release` or by the PKGBUILD), fall back to debug.
BIN=
for candidate in \
    "$REPO_ROOT/packaging/shedos-screensaver/target/release/shedos-screensaver" \
    "$REPO_ROOT/packaging/shedos-screensaver/target/debug/shedos-screensaver"; do
    if [[ -x $candidate ]]; then
        BIN=$candidate
        break
    fi
done

if [[ -z $BIN ]]; then
    echo "FATAL: no shedos-screensaver binary found." >&2
    echo "Run \`cd packaging/shedos-screensaver && cargo build\` first." >&2
    exit 1
fi

PASSED=0
FAILED=0
FAILURES=()

ok() {
    PASSED=$((PASSED + 1))
    printf "  \e[32m✓\e[0m %s\n" "$1"
}

fail() {
    FAILED=$((FAILED + 1))
    FAILURES+=("$1")
    printf "  \e[31m✗\e[0m %s\n" "$1"
    if [[ -n ${2:-} ]]; then
        printf "      %s\n" "$2"
    fi
}

# `expect_exit NAME EXPECTED ACTUAL OUT`
# Pass if ACTUAL == EXPECTED; otherwise fail with the captured OUT.
expect_exit() {
    local name=$1 expected=$2 actual=$3 out=$4
    if [[ $actual -eq $expected ]]; then
        ok "$name"
        return 0
    fi
    fail "$name" "expected exit $expected, got $actual; output: $out"
    return 1
}

# `expect_contains NAME NEEDLE HAYSTACK`
# Pass if HAYSTACK contains NEEDLE.
expect_contains() {
    local name=$1 needle=$2 haystack=$3
    if [[ $haystack == *"$needle"* ]]; then
        ok "$name"
        return 0
    fi
    fail "$name" "expected to contain '$needle'; got: $(printf '%s' "$haystack" | head -c 200)"
    return 1
}

echo "Testing $BIN"
echo

# ------------- T1: --help-summary -------------
out=$("$BIN" --help-summary 2>&1); code=$?
expect_exit "T1 --help-summary exits 0" 0 "$code" "$out"
expect_contains "T1 --help-summary mentions screensaver" "screensaver" "$out"

# ------------- T2: --help -------------
out=$("$BIN" --help 2>&1); code=$?
expect_exit "T2 --help exits 0" 0 "$code" "$out"
expect_contains "T2 --help mentions screensaver" "screensaver" "$out"

# ------------- T3: --list lists all 8 styles -------------
out=$("$BIN" --list 2>&1); code=$?
expect_exit "T3 --list exits 0" 0 "$code" "$out"
for style in logo-bounce matrix plasma starfield conway tunnel waves mandala; do
    expect_contains "T3 --list contains $style" "$style" "$out"
done

# ------------- T4: --help-style matrix shows option keys -------------
out=$("$BIN" --help-style matrix 2>&1); code=$?
expect_exit "T4 --help-style matrix exits 0" 0 "$code" "$out"
for opt in density trail_length glyphs; do
    expect_contains "T4 --help-style matrix contains $opt" "$opt" "$out"
done

# ------------- T5: --complete-bash -------------
out=$("$BIN" --complete-bash 2>&1); code=$?
expect_exit "T5 --complete-bash exits 0" 0 "$code" "$out"
[[ -n "$out" ]] && ok "T5 --complete-bash output is non-empty" || fail "T5 output empty"

# ------------- T6: --complete-fish uses native format -------------
out=$("$BIN" --complete-fish 2>&1); code=$?
expect_exit "T6 --complete-fish exits 0" 0 "$code" "$out"
expect_contains "T6 --complete-fish uses native fish format" "complete -c shedos-screensaver" "$out"

# ------------- T7: --complete-zsh -------------
out=$("$BIN" --complete-zsh 2>&1); code=$?
expect_exit "T7 --complete-zsh exits 0" 0 "$code" "$out"
[[ -n "$out" ]] && ok "T7 --complete-zsh output is non-empty" || fail "T7 output empty"

# ------------- T8: --style nonsense → exit 2 -------------
out=$("$BIN" --style nonsense 2>&1); code=$?
expect_exit "T8 --style nonsense exits 2" 2 "$code" "$out"
expect_contains "T8 --style nonsense names the bad style" "nonsense" "$out"

# ------------- T9: --color rubbish → exit 2 -------------
out=$("$BIN" --color rubbish 2>&1); code=$?
expect_exit "T9 --color rubbish exits 2" 2 "$code" "$out"
expect_contains "T9 --color rubbish names the bad color" "rubbish" "$out"

# ------------- T10: out-of-range --style-opt → exit 2 -------------
out=$("$BIN" --style matrix --style-opt density=99 2>&1); code=$?
expect_exit "T10 --style-opt density=99 exits 2" 2 "$code" "$out"
expect_contains "T10 --style-opt density=99 names the option" "density" "$out"

# ------------- T11: pty smoke for --duration -------------
# script(1) allocates a pty so the renderer thinks stdout is a TTY.
# `--duration 0.3` makes the loop self-terminate in ~300 ms.
if command -v script >/dev/null 2>&1; then
    if script -q -c "$BIN --mode=tty --style logo-bounce --duration 0.3" /dev/null > /dev/null 2>&1; then
        ok "T11 pty --duration 0.3 exits cleanly"
    else
        fail "T11 pty --duration 0.3 returned non-zero"
    fi
else
    echo "  (skipping T11: script(1) not installed)"
fi

echo
echo "Passed: $PASSED"
echo "Failed: $FAILED"
if [[ $FAILED -gt 0 ]]; then
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
exit 0
