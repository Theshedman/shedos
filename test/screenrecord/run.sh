#!/usr/bin/env bash
# run.sh — fixture-style harness for `shedman screenrecord`.
#
# Covers the read-only modes the harness can fully drive:
#   T1 --help-summary  one non-empty line.
#   T2 --help          exits 0 + prints usage banner.
#   T3 --waybar idle   no live PID file → idle JSON.
#   T4 --waybar active PID file points at a live process → active JSON.
#   T5 --complete-bash emits ≥1 long flag and ≥1 short flag.
#   T6 --complete-fish same payload (parity).
#   T7 unknown flag    rc=2 + "Try:" hint.
#   T8 --stop idle     rc=1 (no recording) + state cleared.
#
# --start / --stop against a real recording aren't tested here: they need
# wf-recorder and a Wayland session. Manual verification on a live install
# covers them.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
tool=$repo_root/packaging/shedos-hyprland/tree/usr/libexec/shedman/screenrecord

if [[ ! -x $tool ]]; then
    echo "FATAL: $tool not executable" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "FATAL: jq required (tests parse --waybar JSON)" >&2
    exit 2
fi

pass=0
fail=0
failures=()

_ok()    { echo "PASS $1"; ((pass++)); }
_fail()  { echo "FAIL $1: $2"; failures+=("$1"); ((fail++)); }

# Hermetic environment — never let real notify-send fire and never let the
# command write into a real $XDG_RUNTIME_DIR.
tmp=$(mktemp -d -t shedos-screenrecord-test.XXXXXX)
trap 'rm -rf -- "$tmp"' EXIT

export DBUS_SESSION_BUS_ADDRESS=""
export XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$XDG_RUNTIME_DIR"

# ---------------------------------------------------------------------------
# T1: --help-summary prints one non-empty line.
# ---------------------------------------------------------------------------
out=$("$tool" --help-summary 2>&1)
rc=$?
if (( rc == 0 )) && [[ -n $out ]] && (( $(wc -l <<<"$out") == 1 )); then
    _ok T1_help_summary
else
    _fail T1_help_summary "rc=$rc out=$out"
fi

# ---------------------------------------------------------------------------
# T2: --help exits 0 with a "Usage:" banner.
# ---------------------------------------------------------------------------
out=$("$tool" --help 2>&1)
rc=$?
if (( rc == 0 )) && grep -q '^Usage:' <<<"$out"; then
    _ok T2_help
else
    _fail T2_help "rc=$rc out=$out"
fi

# ---------------------------------------------------------------------------
# T3: --waybar with no live PID file → idle JSON.
#
# Note: `VAR=value out=$(cmd)` doesn't put VAR into the subshell — both
# are treated as local assignments at the current shell. Use `env` so the
# override actually reaches the tool.
# ---------------------------------------------------------------------------
out=$(env SHEDOS_SCREENRECORD_PID_FILE="$tmp/missing.pid" "$tool" --waybar 2>&1)
rc=$?
if (( rc == 0 )) \
        && jq -e '.class == "idle" and .text == "" and .tooltip == ""' \
            <<<"$out" >/dev/null 2>&1; then
    _ok T3_waybar_idle
else
    _fail T3_waybar_idle "rc=$rc out=$out"
fi

# ---------------------------------------------------------------------------
# T4: --waybar with a live PID + path → active JSON.
#     We use the test runner's own PID — guaranteed alive for the duration
#     of this script.
# ---------------------------------------------------------------------------
pidfile="$tmp/active.pid"
printf '%s\n%s\n' "$$" "/tmp/recording_test.mp4" > "$pidfile"
out=$(env SHEDOS_SCREENRECORD_PID_FILE="$pidfile" "$tool" --waybar 2>&1)
rc=$?
if (( rc == 0 )) \
        && jq -e '.class == "recording" and (.text | length) > 0 and (.tooltip | contains("/tmp/recording_test.mp4"))' \
            <<<"$out" >/dev/null 2>&1; then
    _ok T4_waybar_active
else
    _fail T4_waybar_active "rc=$rc out=$out"
fi

# ---------------------------------------------------------------------------
# T5: --complete-bash emits at least one long flag and one short flag.
# ---------------------------------------------------------------------------
out=$("$tool" --complete-bash 2>&1)
rc=$?
long_count=$(grep -c '^--' <<<"$out" || true)
short_count=$(grep -cE '^-[a-zA-Z]$' <<<"$out" || true)
if (( rc == 0 && long_count >= 1 && short_count >= 1 )); then
    _ok T5_complete_bash
else
    _fail T5_complete_bash "rc=$rc long=$long_count short=$short_count out=$out"
fi

# ---------------------------------------------------------------------------
# T6: --complete-fish parity with --complete-bash.
# ---------------------------------------------------------------------------
out_fish=$("$tool" --complete-fish 2>&1)
rc=$?
if (( rc == 0 )) && [[ "$out_fish" == "$out" ]]; then
    _ok T6_complete_fish
else
    _fail T6_complete_fish "rc=$rc out=$out_fish"
fi

# ---------------------------------------------------------------------------
# T7: unknown flag → rc=2 + "Try:" hint.
# ---------------------------------------------------------------------------
out=$("$tool" --bogus 2>&1)
rc=$?
if (( rc == 2 )) && grep -q 'unknown flag' <<<"$out" && grep -q 'Try:' <<<"$out"; then
    _ok T7_unknown_flag
else
    _fail T7_unknown_flag "rc=$rc out=$out"
fi

# ---------------------------------------------------------------------------
# T8: --stop with no recording → rc=1, message on stderr, state cleared.
# ---------------------------------------------------------------------------
pidfile="$tmp/stop_idle.pid"
out=$(env SHEDOS_SCREENRECORD_PID_FILE="$pidfile" "$tool" --stop 2>&1)
rc=$?
if (( rc == 1 )) && grep -q 'no recording in progress' <<<"$out" && [[ ! -e $pidfile ]]; then
    _ok T8_stop_idle
else
    _fail T8_stop_idle "rc=$rc out=$out pid_exists=$([[ -e $pidfile ]] && echo y || echo n)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "screenrecord: $pass passed, $fail failed"
if (( fail > 0 )); then
    printf '  %s\n' "${failures[@]}" >&2
    exit 1
fi
