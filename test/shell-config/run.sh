#!/usr/bin/env bash
# Guard the shipped shell configs: both shells lint, the ble.sh/starship
# ordering holds, user overrides survive, and no shipped rc shadows a
# core command (the standing alias policy).
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
skel=$repo_root/packaging/shedos-hyprland/tree/etc/skel

pass=0; fail=0; failures=()
_ok()   { printf 'ok: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); fail=$((fail + 1)); }
_summary() {
    echo; echo "shell-config: $pass/$((pass + fail)) passed"
    if (( fail > 0 )); then printf '  %s\n' "${failures[@]}" >&2; exit 1; fi
    exit 0
}

# --- files exist -----------------------------------------------------------
for f in .bashrc .bash_profile .zshrc .zprofile; do
    if [[ -f $skel/$f ]]; then _ok "S1_ships_$f"; else _fail "S1_ships_$f" "missing"; fi
done
if [[ ! -e $skel/.p10k.zsh ]]; then
    _ok S2_p10k_config_gone
else
    _fail S2_p10k_config_gone "still shipped"
fi

# --- both shells lint ------------------------------------------------------
for f in .bashrc .bash_profile; do
    if bash -n "$skel/$f" 2>"$here/.err"; then _ok "S3_bash_lints_$f"; else _fail "S3_bash_lints_$f" "$(cat "$here/.err")"; fi
done
if command -v zsh >/dev/null; then
    for f in .zshrc .zprofile; do
        if zsh -n "$skel/$f" 2>"$here/.err"; then _ok "S3_zsh_lints_$f"; else _fail "S3_zsh_lints_$f" "$(cat "$here/.err")"; fi
    done
else
    echo "shell-config: zsh not installed; zsh lints skipped"
fi
rm -f "$here/.err"

# --- ordering: ble.sh before starship, ble-attach last ---------------------
if [[ -f $skel/.bashrc ]]; then
    ble_line=$(grep -n 'blesh/ble.sh --noattach' "$skel/.bashrc" | head -1 | cut -d: -f1)
    ship_line=$(grep -n 'starship init bash' "$skel/.bashrc" | head -1 | cut -d: -f1)
    if [[ -n $ble_line && -n $ship_line ]] && (( ble_line < ship_line )); then
        _ok S4_ble_sourced_before_starship
    else
        _fail S4_ble_sourced_before_starship "ble=$ble_line starship=$ship_line"
    fi
    last=$(grep -vE '^\s*(#|$)' "$skel/.bashrc" | tail -1)
    if [[ $last == *ble-attach* ]]; then
        _ok S5_ble_attach_is_last
    else
        _fail S5_ble_attach_is_last "last effective line: $last"
    fi
fi

# --- STARSHIP_CONFIG respects an existing value ----------------------------
for f in .bashrc .zshrc; do
    if grep -q 'STARSHIP_CONFIG="${STARSHIP_CONFIG:-' "$skel/$f" 2>/dev/null; then
        _ok "S6_${f}_keeps_user_starship_config"
    else
        _fail "S6_${f}_keeps_user_starship_config" "no :- default form"
    fi
done

# --- alias policy: no core-command shadowing -------------------------------
for f in .bashrc .zshrc; do
    shadowed=$(grep -oE '^\s*alias (ls|cat|cd|find|du|df|ps|top|grep|rm|cp|mv|mkdir)=' "$skel/$f" 2>/dev/null | head -3)
    if [[ -z $shadowed ]]; then
        _ok "S7_${f}_shadows_nothing"
    else
        _fail "S7_${f}_shadows_nothing" "$shadowed"
    fi
done

# --- .bash_profile: XDG_DATA_DIRS + sources .bashrc ------------------------
if [[ -f $skel/.bash_profile ]] \
   && grep -q 'XDG_DATA_DIRS' "$skel/.bash_profile" \
   && grep -q '\.bashrc' "$skel/.bash_profile"; then
    _ok S8_bash_profile_exports_and_chains
else
    _fail S8_bash_profile_exports_and_chains "missing export or chain"
fi

# --- the zsh rewrite really dropped the old stack --------------------------
if [[ -f $skel/.zshrc ]] && ! grep -qE 'oh-my-zsh|p10k|powerlevel10k|instant-prompt' "$skel/.zshrc"; then
    _ok S9_zshrc_free_of_the_old_stack
else
    _fail S9_zshrc_free_of_the_old_stack "old stack references remain"
fi

_summary
