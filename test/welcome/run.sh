#!/usr/bin/env bash
# run.sh — smoke tests for `shedman welcome`.
#
# Coverage: --help-summary, --help (mentions --force), live-ISO short-
# circuit, marker short-circuit, yad-missing path (regression test for
# the v2026.04.27-rc1 silent-failure bug), --force flag.
#
# The interactive yad-form path is NOT exercised — that needs a Wayland
# session and a real keyboard. Manual first-boot login covers it.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
tool=$repo_root/packaging/shedos-system/tree/usr/libexec/shedman/welcome

if [[ ! -x $tool ]]; then
    echo "FATAL: $tool not executable" >&2
    exit 2
fi

pass=0
fail=0
failures=()

_ok() { echo "ok: $1"; ((pass++)); }
_fail() { echo "FAIL: $1: $2" >&2; failures+=("$1"); ((fail++)); }

tmp=$(mktemp -d -t shedos-welcome-test.XXXXXX)
trap 'rm -rf -- "$tmp"' EXIT

# Hermetic env so we don't touch the real ~/.config or ~/.local/state.
export HOME="$tmp/home"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME/.config" "$XDG_STATE_HOME/shedos"

# Make sure we're never matched as the live-ISO `shedos` user.
export USER=test_not_calamares

# T1 — --help-summary
out=$("$tool" --help-summary 2>&1); rc=$?
if (( rc == 0 )) && [[ -n $out ]] && (( $(printf '%s\n' "$out" | wc -l) == 1 )); then
    _ok T1_help_summary
else
    _fail T1_help_summary "rc=$rc out=$out"
fi

# T2 — --help mentions --force (the new flag)
out=$("$tool" --help 2>&1); rc=$?
if (( rc == 0 )) && grep -q '^Usage:' <<<"$out" && grep -q -- '--force' <<<"$out"; then
    _ok T2_help_mentions_force
else
    _fail T2_help_mentions_force "rc=$rc out=$out"
fi

# T3 — running inside the live ISO short-circuits with no marker write.
# We can't really fake /run/archiso (root-owned) without sudo, so we
# exercise the second skip branch: $USER=shedos AND
# /etc/calamares/settings.conf exists. The script's existing logic
# treats that combination as "running inside Calamares".
#
# In CI/dev boxes where /etc/calamares/settings.conf may or may not
# exist, the test is informational: skip cleanly if the file isn't
# there, otherwise verify the short-circuit path.
if [[ -f /etc/calamares/settings.conf ]]; then
    HOME="$tmp/home" USER=shedos out=$("$tool" 2>&1); rc=$?
    if (( rc == 0 )) && [[ -z $out ]] && [[ ! -f "$HOME/.config/shedos-setup-complete" ]]; then
        _ok T3_calamares_short_circuit
    else
        _fail T3_calamares_short_circuit "rc=$rc out=$out marker=$([[ -f $HOME/.config/shedos-setup-complete ]] && echo yes || echo no)"
    fi
else
    # Inactive on this host. Note in stdout, count as pass.
    _ok T3_calamares_short_circuit_skipped_no_calamares_config
fi

# T4 — marker pre-existing → silent skip, marker untouched.
touch "$HOME/.config/shedos-setup-complete"
mtime_before=$(stat -c %Y "$HOME/.config/shedos-setup-complete")
sleep 1
out=$("$tool" 2>&1); rc=$?
mtime_after=$(stat -c %Y "$HOME/.config/shedos-setup-complete")
if (( rc == 0 )) && [[ -z $out ]] && (( mtime_before == mtime_after )); then
    _ok T4_marker_short_circuit_silent
else
    _fail T4_marker_short_circuit_silent "rc=$rc out=$out mtime_before=$mtime_before mtime_after=$mtime_after"
fi
rm -f "$HOME/.config/shedos-setup-complete"

# T5 — yad missing → exits 0 without writing the marker. This is the
# regression test for the v2026.04.27-rc1 first-boot bug: the previous
# welcome silently wrote the marker on yad failure, making the wizard
# unrecoverable on subsequent logins.
#
# Strategy: PATH-stub `command -v yad` to fail by stripping yad from
# PATH. We build a minimal PATH containing only /usr/bin (for getent /
# git / etc.) but not yad's location. yad ships in /usr/bin too on
# Arch, so we use a different tactic: a stub directory containing
# everything else the script needs, but no yad.
#
# Easier: use `env -i` to scrub the env, then explicitly set PATH to a
# stub dir that has the binaries the script needs minus yad.
stub_dir=$tmp/no-yad-stubs
mkdir -p "$stub_dir"
# Symlink everything the script touches that isn't yad / notify-send.
for bin in bash id mkdir touch git getent grep cut date readlink dirname stat sleep rm cat sed; do
    src=$(command -v "$bin" 2>/dev/null)
    [[ -n $src ]] && ln -sf "$src" "$stub_dir/$bin"
done

# notify-send may or may not be there — let it be missing too so we
# don't accidentally fire a real desktop toast during the test.
HOME_T5="$tmp/home-t5"
mkdir -p "$HOME_T5/.config"
out=$(env -i \
    PATH="$stub_dir" \
    HOME="$HOME_T5" \
    USER=test_not_calamares \
    XDG_STATE_HOME="$HOME_T5/.local/state" \
    "$tool" 2>&1); rc=$?

if (( rc == 0 )) && [[ ! -f "$HOME_T5/.config/shedos-setup-complete" ]] && \
   grep -q "yad not installed" "$HOME_T5/.local/state/shedos/welcome.log" 2>/dev/null; then
    _ok T5_yad_missing_no_marker
else
    log_content=$(cat "$HOME_T5/.local/state/shedos/welcome.log" 2>/dev/null || echo "(no log)")
    marker_state=$([[ -f "$HOME_T5/.config/shedos-setup-complete" ]] && echo present || echo absent)
    _fail T5_yad_missing_no_marker "rc=$rc marker=$marker_state log=${log_content//$'\n'/ | }"
fi

# T6 — --force removes the pre-existing marker. We can't drive yad
# interactively, so the verification is just that --force unlinks the
# marker before yad would fire. With yad missing on this host we'd hit
# the yad-preflight bail; with yad present we'd block on the form.
# Neither lets us assert "marker is gone after --force" cleanly without
# additional plumbing — so we instead check that --force is documented
# and that the entry-point handles the flag without erroring on
# argument parsing.
#
# The actual marker removal happens before any yad call (line 91-94 of
# the script), so a simple invocation that bails on yad-missing still
# proves the --force path executed. Use the same env-stripped harness
# from T5 plus a pre-existing marker.
HOME_T6="$tmp/home-t6"
mkdir -p "$HOME_T6/.config"
touch "$HOME_T6/.config/shedos-setup-complete"
out=$(env -i \
    PATH="$stub_dir" \
    HOME="$HOME_T6" \
    USER=test_not_calamares \
    XDG_STATE_HOME="$HOME_T6/.local/state" \
    "$tool" --force 2>&1); rc=$?

if (( rc == 0 )) && [[ ! -f "$HOME_T6/.config/shedos-setup-complete" ]]; then
    _ok T6_force_removes_marker
else
    marker_state=$([[ -f "$HOME_T6/.config/shedos-setup-complete" ]] && echo present || echo absent)
    _fail T6_force_removes_marker "rc=$rc marker=$marker_state out=$out"
fi

# Summary
total=$((pass + fail))
echo
echo "welcome: $pass/$total passed"
if (( fail > 0 )); then
    printf '  %s\n' "${failures[@]}" >&2
    exit 1
fi
