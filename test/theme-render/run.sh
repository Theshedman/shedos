#!/usr/bin/env bash
# Guard the theme renderer's outputs — presently the two prompt-facing
# ones: starship.toml (the cross-shell prompt) and fzf.bash. Rendering
# runs against a scratch etc-root, never the live system.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
renderer=$repo_root/packaging/shedos-system/tree/usr/lib/shedos/theme_renderer.py
palettes=$repo_root/packaging/shedos-system/tree/etc/shedos/themes/palettes

pass=0; fail=0; failures=()
_ok()   { printf 'ok: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); fail=$((fail + 1)); }
_summary() {
    echo; echo "theme-render: $pass/$((pass + fail)) passed"
    if (( fail > 0 )); then printf '  %s\n' "${failures[@]}" >&2; exit 1; fi
    exit 0
}

command -v python3 >/dev/null || { echo "theme-render: SKIP (no python3)"; exit 0; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# Scratch etc-root with every shipped palette + a wallpaper stand-in.
mkdir -p "$work/etc/shedos/themes/palettes" "$work/wall"
cp "$palettes"/*.toml "$work/etc/shedos/themes/palettes/"
magick -size 8x8 xc:black "$work/wall/w.png" 2>/dev/null \
    || { echo "theme-render: SKIP (magick unavailable)"; exit 0; }

render_one() {  # $1=palette-name $2=outdir-name
    python3 - "$renderer" "$work/etc" "$1" "$work/wall/w.png" <<'PY'
import importlib.util, sys
from pathlib import Path
renderer, etc_root, palette, wallpaper = sys.argv[1:5]
spec = importlib.util.spec_from_file_location("theme_renderer", renderer)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
doc = {"theme": {"palette": palette, "wallpaper": wallpaper}}
out = mod.render_theme(doc, etc_root=Path(etc_root), dry_run=True)
print(out)
PY
}

for pal in "$palettes"/*.toml; do
    name=$(basename "$pal" .toml)
    out=$(render_one "$name" 2>"$work/err") || {
        _fail "R1_render_${name}" "$(tail -2 "$work/err")"
        continue
    }
    if [[ -f $out/starship.toml && -f $out/fzf.bash ]]; then
        _ok "R1_render_${name}_emits_prompt_outputs"
    else
        _fail "R1_render_${name}_emits_prompt_outputs" "missing starship.toml or fzf.bash in $out"
        continue
    fi

    # Real-parser proof + palette closure: every color name the format
    # references must exist in the palette block.
    if python3 - "$out/starship.toml" <<'PY'
import sys, tomllib, re
cfg = tomllib.load(open(sys.argv[1], "rb"))
assert cfg.get("palette") == "shedos", "palette key"
pal = cfg["palettes"]["shedos"]
text = open(sys.argv[1]).read()
used = set(re.findall(r'(?:fg|bg):([a-z_]+)', text))
missing = used - set(pal)
assert not missing, f"palette missing: {missing}"
PY
    then
        _ok "R2_${name}_palette_covers_format"
    else
        _fail "R2_${name}_palette_covers_format" "tomllib/palette check failed"
    fi

    if bash -n "$out/fzf.bash" 2>/dev/null && grep -q 'FZF_DEFAULT_OPTS' "$out/fzf.bash"; then
        _ok "R3_${name}_fzf_bash_is_bash"
    else
        _fail "R3_${name}_fzf_bash_is_bash" "bash -n or content check failed"
    fi
    rm -rf "$out"
done

# starship itself must accept the rendered config (real parser, not tomllib).
# print-config exits 0 on bad module keys and only warns on stderr, so an
# empty stderr is part of the contract.
if command -v starship >/dev/null; then
    out=$(render_one "catppuccin-mocha-blue" 2>/dev/null)
    if [[ -f $out/starship.toml ]] \
       && STARSHIP_CONFIG="$out/starship.toml" starship print-config >/dev/null 2>"$work/serr" \
       && [[ ! -s $work/serr ]]; then
        _ok R4_starship_accepts_the_rendered_config
    else
        _fail R4_starship_accepts_the_rendered_config "$(tail -2 "$work/serr")"
    fi
    rm -rf "$out"
else
    echo "theme-render: starship not installed; R4 skipped"
fi

_summary
