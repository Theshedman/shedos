#!/usr/bin/env bash
# Guard the keybindings dialog's display metadata against the shipped
# Hyprland config. Every shipped bind/gesture must have a meta entry
# (or it renders under "Other" with a raw command), and every meta
# entry must match a shipped bind (or it silently never shows). This
# is the drift class behind ledger D9/D10.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)

python3 - "$repo_root" <<'EOF'
import importlib.machinery
import importlib.util
import re
import sys
import types
from pathlib import Path

repo = Path(sys.argv[1])
hypr = repo / "packaging/shedos-hyprland/tree/etc/skel/.config/hypr"
dialog = repo / "packaging/shedos-hyprland/tree/usr/libexec/shedman/keybindings"
meta = repo / "packaging/shedos-hyprland/tree/usr/share/shedos-hyprland/keybindings-meta.toml"

# The dialog imports GTK at module level; stub it so the parsers load
# in a headless CI container.
gi = types.ModuleType("gi")
gi.require_version = lambda *a, **k: None
repository = types.ModuleType("gi.repository")
for name in ("GLib", "Gtk", "Gdk"):
    mod = types.SimpleNamespace()
    setattr(repository, name, mod)
# Gtk.Application / Gtk.ApplicationWindow are subclassed at module level.
repository.Gtk.Application = type("Application", (), {"__init__": lambda self, **k: None})
repository.Gtk.ApplicationWindow = type("ApplicationWindow", (), {"__init__": lambda self, **k: None})
gi.repository = repository
sys.modules["gi"] = gi
sys.modules["gi.repository"] = repository

loader = importlib.machinery.SourceFileLoader("kb", str(dialog))
spec = importlib.util.spec_from_loader("kb", loader)
kb = importlib.util.module_from_spec(spec)
loader.exec_module(kb)

failures = []

shipped_binds = set(kb.parse_bind_hints(hypr))
# The workspace binds are loop-generated in keybindings.lua and not
# statically parseable; assert the loop exists, then expand it.
kblua = (hypr / "keybindings.lua").read_text()
if re.search(r"for i = 1, 10 do", kblua):
    for i in list(range(1, 10)) + [0]:
        shipped_binds.add(f"SUPER+{i}")
        shipped_binds.add(f"SUPER+SHIFT+{i}")
else:
    failures.append("workspace bind loop missing from keybindings.lua")

shipped_gestures = set(kb.parse_gestures(hypr))
bind_meta, gesture_meta = kb.load_meta(meta)

for keys in sorted(bind_meta):
    if keys not in shipped_binds:
        failures.append(f"meta bind {keys!r} matches no shipped bind")
for keys in sorted(shipped_binds):
    if keys not in bind_meta:
        failures.append(f"shipped bind {keys!r} has no meta entry (renders under Other)")
for gid in sorted(gesture_meta):
    if gid not in shipped_gestures:
        failures.append(f"meta gesture {gid!r} matches no shipped gesture")
for gid in sorted(shipped_gestures):
    if gid not in gesture_meta:
        failures.append(f"shipped gesture {gid!r} has no meta entry")

checked = len(bind_meta) + len(shipped_binds) + len(gesture_meta) + len(shipped_gestures)
if failures:
    for f in failures:
        print(f"FAIL: {f}", file=sys.stderr)
    print(f"keybindings: {len(failures)} failures", file=sys.stderr)
    sys.exit(1)
print(f"ok: meta ↔ shipped config consistent "
      f"({len(bind_meta)} binds, {len(gesture_meta)} gestures)")
EOF
