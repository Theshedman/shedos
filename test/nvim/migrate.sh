#!/usr/bin/env bash
# Guard the preprovision hook: every ShedOS config generation is swapped
# with a backup, a hand-built config is untouched, OS-owned plugin clones
# are reclaimed, user plugins survive, and it runs exactly once.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
tool=$repo_root/packaging/shedos-nvim/tree/usr/lib/shedos/nvim-preprovision
shim_src=$repo_root/packaging/shedos-nvim/tree/etc/skel/.config/nvim

pass=0; fail=0; failures=()
_ok()   { printf 'ok: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); fail=$((fail + 1)); }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/shipped/plugins/blink.cmp" "$work/shipped/plugins/lazy.nvim" \
         "$work/shipped/defaults/.config"
cp -a "$shim_src" "$work/shipped/defaults/.config/nvim"

_run() {  # $1=home
    HOME=$1 XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_STATE_HOME= \
    SHEDOS_NVIM_SHIPPED_ROOT="$work/shipped" \
    SHEDOS_NVIM_DEFAULTS="$work/shipped/defaults/.config/nvim" \
        bash "$tool" >>"$work/out" 2>&1
}
_mkhome() {  # $1=home — data dir with one shipped clone, one user plugin, mason
    mkdir -p "$1/.config" "$1/.local/share/nvim/lazy/blink.cmp/.git" \
             "$1/.local/share/nvim/lazy/my-own-plugin" "$1/.local/share/nvim/mason" \
             "$1/.local/share/nvim/lazy/mason.nvim"
}

# M1/M2: current generation (pre-shim shipped config) is swapped + backed up.
h=$work/h1; _mkhome "$h"; mkdir -p "$h/.config/nvim/lua/config" "$h/.config/nvim/lua/plugins"
printf 'require("config.lazy")\n' > "$h/.config/nvim/init.lua"
printf -- '-- clone https://github.com/folke/lazy.nvim.git\n' > "$h/.config/nvim/lua/config/lazy.lua"
: > "$h/.config/nvim/lua/plugins/lsp-system.lua"
_run "$h"
if compgen -G "$h/.config/nvim.shedos-bak-*" >/dev/null \
   && grep -q 'shedos/nvim/runtime' "$h/.config/nvim/init.lua"; then
    _ok M1_current_generation_swapped_with_backup
else
    _fail M1_current_generation_swapped_with_backup "no swap or no backup"
fi
if [[ ! -d $h/.local/share/nvim/lazy/blink.cmp && -d $h/.local/share/nvim/lazy/my-own-plugin \
      && ! -d $h/.local/share/nvim/mason && ! -d $h/.local/share/nvim/lazy/mason.nvim ]]; then
    _ok M2_reclaims_shipped_keeps_user_removes_mason
else
    _fail M2_reclaims_shipped_keeps_user_removes_mason "data dir wrong"
fi

# M3: old generation (features dir fingerprint) is swapped too.
h=$work/h2; _mkhome "$h"; mkdir -p "$h/.config/nvim/lua/config/features"
_run "$h"
if grep -q 'shedos/nvim/runtime' "$h/.config/nvim/init.lua" 2>/dev/null; then
    _ok M3_old_generation_swapped
else
    _fail M3_old_generation_swapped "old gen not recognized"
fi

# M4: a hand-built config with no ShedOS fingerprint is untouched, data too.
h=$work/h3; _mkhome "$h"; mkdir -p "$h/.config/nvim"
printf -- '-- my very own config\n' > "$h/.config/nvim/init.lua"
_run "$h"
if [[ $(cat "$h/.config/nvim/init.lua") == '-- my very own config' ]] \
   && [[ -d $h/.local/share/nvim/lazy/blink.cmp ]] \
   && ! compgen -G "$h/.config/nvim.shedos-bak-*" >/dev/null; then
    _ok M4_hand_built_config_untouched
else
    _fail M4_hand_built_config_untouched "custom config was modified"
fi

# M5: no config at all gets the shim.
h=$work/h4; _mkhome "$h"; rm -rf "$h/.config/nvim"
_run "$h"
if grep -q 'shedos/nvim/runtime' "$h/.config/nvim/init.lua" 2>/dev/null; then
    _ok M5_missing_config_gets_the_shim
else
    _fail M5_missing_config_gets_the_shim "shim not deployed"
fi

# M6: already-shim home only reclaims; no backup churn.
h=$work/h5; _mkhome "$h"
cp -a "$shim_src" "$h/.config/nvim"
_run "$h"
if ! compgen -G "$h/.config/nvim.shedos-bak-*" >/dev/null \
   && [[ ! -d $h/.local/share/nvim/lazy/blink.cmp ]]; then
    _ok M6_shim_home_reclaims_without_backup
else
    _fail M6_shim_home_reclaims_without_backup "unexpected backup or no reclaim"
fi

# M7: absent shipped tree → untouched, no marker, retried next login.
h=$work/h6; _mkhome "$h"
HOME=$h XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_STATE_HOME= \
SHEDOS_NVIM_SHIPPED_ROOT="$work/nowhere" \
SHEDOS_NVIM_DEFAULTS="$work/shipped/defaults/.config/nvim" bash "$tool" >>"$work/out" 2>&1
if [[ -d $h/.local/share/nvim/mason && ! -f $h/.local/state/shedos/.nvim-preprovisioned ]]; then
    _ok M7_absent_shipped_tree_is_a_retryable_noop
else
    _fail M7_absent_shipped_tree_is_a_retryable_noop "acted without the tree"
fi

# M8: second run is a no-op.
h=$work/h1
snap=$(find "$h" | sort | md5sum)
_run "$h"
if [[ $(find "$h" | sort | md5sum) == "$snap" ]]; then
    _ok M8_idempotent
else
    _fail M8_idempotent "second run changed the home"
fi

echo; echo "nvim-migrate: $pass/$((pass + fail)) passed"
if (( fail > 0 )); then printf '  %s\n' "${failures[@]}" >&2; exit 1; fi
