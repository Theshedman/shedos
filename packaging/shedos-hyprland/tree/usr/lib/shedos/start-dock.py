#!/usr/bin/env python3
"""shedos-start-dock — bring up one nwg-dock-hyprland instance per Hyprland monitor.

ExecStart for shedos-dock.service. Reads ~/.config/shedos/dock.toml
for the user-facing knobs (position, icon size, launcher command),
queries `hyprctl monitors -j` for the live output list, then spawns
one `nwg-dock-hyprland -o <output> -m` per monitor so the dock
renders on every screen, not just the focused one.

The default pinned-app list lives in /usr/share/shedos/hyprland/
nwg-dock-pinned-default; on first run we seed
~/.cache/nwg-dock-hyprland/nwg-dock-pinned from it if the user
doesn't already have one. Subsequent right-click pin/unpin in the
dock UI (or `shedman dock pin/unpin`) overwrites that file —
we never clobber an existing list.

The wrapper supervises the spawned child processes and waits on
them. If any exits, we propagate the worst exit code so systemd
treats it as a failure and Restart=on-failure kicks the unit.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import tomllib
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME",
                             str(Path.home() / ".config"))) / "shedos" / "dock.toml"

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME",
                                str(Path.home() / ".cache")))
# Path verified by strace against the live nwg-dock-hyprland binary:
# it opens "$XDG_CACHE_HOME/nwg-dock-pinned" directly (no subdir).
PINNED_FILE = CACHE_DIR / "nwg-dock-pinned"

DEFAULT_PINNED_SRC = Path("/usr/share/shedos/hyprland/nwg-dock-pinned-default")

DEFAULTS = {
    "position": "bottom",
    "icon_size": 32,
    # The drawer runs resident as shedos-drawer.service; this wrapper
    # sends SIGUSR1 (toggle visibility). Instant open/close.
    "launcher_cmd": "/usr/lib/shedos/toggle-drawer.sh",
}


def _load_config() -> dict:
    cfg = DEFAULTS.copy()
    try:
        with open(CONFIG, "rb") as f:
            cfg.update(tomllib.load(f))
    except FileNotFoundError:
        pass
    except (OSError, tomllib.TOMLDecodeError) as e:
        print(f"shedos-start-dock: {CONFIG} unreadable ({e}); "
              f"using defaults", file=sys.stderr)
    if cfg["position"] not in {"bottom", "top", "left", "right"}:
        print(f"shedos-start-dock: invalid position {cfg['position']!r}; "
              f"falling back to 'bottom'", file=sys.stderr)
        cfg["position"] = "bottom"
    return cfg


def _seed_pinned() -> None:
    """Ensure ~/.cache/nwg-dock-hyprland/nwg-dock-pinned exists with the
    shipped defaults (Firefox, VSCode, Files, Terminal). Never overwrites
    an existing file — once the user pins/unpins, their choices win."""
    if PINNED_FILE.exists():
        return
    if not DEFAULT_PINNED_SRC.exists():
        print(f"shedos-start-dock: no default pinned list at "
              f"{DEFAULT_PINNED_SRC}; skipping seed", file=sys.stderr)
        return
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(DEFAULT_PINNED_SRC, PINNED_FILE)


def _monitors() -> list[str]:
    """Names of all currently-connected Hyprland outputs."""
    try:
        r = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, check=True,
        )
        outputs = json.loads(r.stdout)
        return [m["name"] for m in outputs if "name" in m]
    except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as e:
        print(f"shedos-start-dock: hyprctl monitors failed ({e}); "
              f"falling back to single instance with no -o", file=sys.stderr)
        return []


def _dock_argv(cfg: dict, output: str | None) -> list[str]:
    argv = [
        "/usr/bin/nwg-dock-hyprland",
        "-r",                          # resident, always visible
        "-x",                          # exclusive zone — windows make room for the dock
        "-m",                          # allow multiple instances (one per monitor)
        "-p", cfg["position"],
        "-l", "overlay",
        "-i", str(cfg["icon_size"]),
        "-c", cfg["launcher_cmd"],
    ]
    if output:
        argv += ["-o", output]
    return argv


def _spawn_all(cfg: dict, monitors: list[str]) -> list[subprocess.Popen]:
    children: list[subprocess.Popen] = []
    targets = monitors or [None]
    for output in targets:
        argv = _dock_argv(cfg, output)
        print(f"shedos-start-dock: spawn: {shlex.join(argv)}", file=sys.stderr)
        children.append(subprocess.Popen(argv))
    return children


def _wait_supervised(children: list[subprocess.Popen]) -> int:
    """Wait on every child. If any exits non-zero, terminate the rest
    and return that exit code so systemd treats the unit as failed."""
    worst = 0
    try:
        while children:
            for child in list(children):
                rc = child.poll()
                if rc is None:
                    continue
                children.remove(child)
                if rc != 0:
                    worst = max(worst, rc)
                    print(f"shedos-start-dock: child pid={child.pid} exited "
                          f"rc={rc}; tearing down siblings", file=sys.stderr)
                    for other in children:
                        try:
                            other.terminate()
                        except ProcessLookupError:
                            pass
            # Block on the first remaining child to avoid busy-looping.
            if children:
                children[0].wait()
    except KeyboardInterrupt:
        for child in children:
            try:
                child.terminate()
            except ProcessLookupError:
                pass
        return 130
    return worst


def _install_signal_passthrough(children: list[subprocess.Popen]) -> None:
    """Forward SIGTERM / SIGRTMIN+1 to every child so systemd-stop
    and `shedman dock toggle` work even with multiple dock instances."""
    def _term(_sig, _frame):
        for c in children:
            try:
                c.terminate()
            except ProcessLookupError:
                pass

    def _toggle(_sig, _frame):
        for c in children:
            try:
                c.send_signal(signal.SIGRTMIN + 1)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGTERM, _term)
    signal.signal(signal.SIGINT, _term)
    signal.signal(signal.SIGRTMIN + 1, _toggle)


def main() -> int:
    cfg = _load_config()
    _seed_pinned()
    monitors = _monitors()
    children = _spawn_all(cfg, monitors)
    _install_signal_passthrough(children)
    return _wait_supervised(children)


if __name__ == "__main__":
    sys.exit(main())
