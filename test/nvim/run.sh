#!/usr/bin/env bash
# Guard the preprovisioned nvim: architecture in the system runtime, thin
# home shim, shipped plugins matching the lock with no .git, Mason gone,
# and a cold start that installs nothing.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
pkg=$repo_root/packaging/shedos-nvim
runtime=$pkg/tree/usr/share/shedos/nvim/runtime
shim=$pkg/tree/etc/skel/.config/nvim

pass=0; fail=0; failures=()
_ok()   { printf 'ok: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); fail=$((fail + 1)); }
_summary() {
    echo; echo "nvim: $pass/$((pass + fail)) passed"
    if (( fail > 0 )); then printf '  %s\n' "${failures[@]}" >&2; exit 1; fi
    exit 0
}

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# N1: the architecture lives in the runtime; the shim stays thin.
if [[ -f $runtime/init.lua && -f $runtime/lazy-lock.json ]] \
   && ls "$runtime"/lua/shedos/plugins/*.lua >/dev/null 2>&1 \
   && grep -q 'SHEDOS_NVIM_NO_SHIPPED' "$runtime/init.lua" \
   && grep -q 'SHEDOS_NVIM_RUNTIME' "$shim/init.lua" \
   && ! grep -q 'lazy.nvim.git' "$shim/init.lua" \
   && [[ $(wc -l < "$shim/init.lua") -lt 20 ]]; then
    _ok N1_runtime_owns_the_architecture_and_the_shim_is_thin
else
    _fail N1_runtime_owns_the_architecture_and_the_shim_is_thin "layout check"
fi

# N2: no update checker and Tutor is enabled.
if grep -q 'checker = { enabled = false }' "$runtime/init.lua" \
   && ! grep -q '"tutor"' "$runtime/init.lua"; then
    _ok N2_checker_off_and_tutor_enabled
else
    _fail N2_checker_off_and_tutor_enabled "check $runtime/init.lua"
fi

# N3: the materializer stages every locked plugin with a dir override and
# leaves no .git behind. Needs network; opt in explicitly.
if [[ -n ${SHEDOS_NVIM_MATERIALIZE_TEST:-} ]]; then
    if bash "$repo_root/packaging/shedos-nvim/materialize-plugins.sh" \
            "$runtime" "$shim" "$work/out" >"$work/mat.log" 2>&1; then
        missing=$(python3 - "$runtime/lazy-lock.json" "$work/out" <<'PY'
import json, sys, pathlib
lock, out = json.load(open(sys.argv[1])), pathlib.Path(sys.argv[2])
shipped = (out / "shipped.lua").read_text()
bad = [n for n in lock
       if not (out / "plugins" / n).is_dir() or f'/{n}"' not in shipped]
bad += [str(p) for p in out.rglob(".git")]
print("\n".join(bad))
PY
)
        if [[ -z $missing ]]; then
            _ok N3_every_locked_plugin_staged_without_git
        else
            _fail N3_every_locked_plugin_staged_without_git "$missing"
        fi
    else
        _fail N3_every_locked_plugin_staged_without_git "$(tail -3 "$work/mat.log")"
    fi
else
    echo "nvim: SHEDOS_NVIM_MATERIALIZE_TEST unset; N3 skipped (needs network)"
fi

# N4: Mason is gone — no registry fetch, no per-user server downloads.
sp=$runtime/lua/shedos/plugins
if [[ ! -f $sp/mason.lua ]] \
   && grep -q 'mason.nvim", enabled = false' "$sp/lsp-system.lua" \
   && grep -q 'mason-lspconfig.nvim", enabled = false' "$sp/lsp-system.lua" \
   && grep -q 'mason-nvim-dap.nvim", enabled = false' "$sp/dap.lua"; then
    _ok N4_mason_is_disabled_everywhere
else
    _fail N4_mason_is_disabled_everywhere "mason still referenced"
fi

# N5: a cold start with an empty HOME against the installed (read-only)
# tree must not install, clone or fetch anything.
if [[ -d /usr/share/shedos/nvim/plugins ]] && command -v nvim >/dev/null; then
    home=$work/home
    mkdir -p "$home/.config"
    cp -a "$shim" "$home/.config/nvim"
    HOME=$home XDG_CONFIG_HOME=$home/.config XDG_DATA_HOME=$home/.local/share \
    XDG_STATE_HOME=$home/.local/state XDG_CACHE_HOME=$home/.cache \
        timeout 120 nvim --headless +qa >"$work/cold.log" 2>&1
    rc=$?
    if (( rc == 0 )) && ! grep -qiE 'installing|cloning|updating registries' "$work/cold.log" \
       && [[ -z $(ls -A "$home/.local/share/nvim/lazy" 2>/dev/null) ]]; then
        _ok N5_cold_start_installs_nothing
    else
        _fail N5_cold_start_installs_nothing "rc=$rc $(tail -3 "$work/cold.log")"
    fi
else
    echo "nvim: shipped tree not installed; N5 skipped"
fi

# The migration hook has its own suite; run it here so CI's test/*/run.sh
# discovery covers both.
if bash "$here/migrate.sh"; then
    _ok N6_migration_suite
else
    _fail N6_migration_suite "see migrate.sh output above"
fi

_summary
