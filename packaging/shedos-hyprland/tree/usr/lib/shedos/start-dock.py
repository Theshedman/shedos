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

The wrapper supervises the spawned child processes. Docks are
long-lived: any child exit — clean or not — leaves a monitor
dockless, so the first exit outside a systemd stop tears down the
rest and fails the unit; Restart=on-failure brings the full set
back on every monitor.
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
        # ShedOS-branded launcher button: a Catppuccin-lavender 9-circle
        # grid SVG shipped by this package, in place of the icon-theme
        # default which inherits whatever Papirus-Dark assigns. -ico
        # takes an absolute path; -lp (which sounds similar) is the
        # launcher *position* and would silently drop the button.
        "-ico", "/usr/share/shedos-hyprland/launcher.svg",
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


# Set by the SIGTERM/SIGINT handler: child exits during a systemd stop
# are expected and must not fail the unit.
_stopping = False


def _terminate_all(children: list[subprocess.Popen]) -> None:
    for child in children:
        try:
            child.terminate()
        except ProcessLookupError:
            pass


def _wait_supervised(children: list[subprocess.Popen]) -> int:
    """Block until ANY child exits (os.waitpid(-1) — not just the
    first in the list, which left sibling crashes unnoticed). A dock
    exiting for any reason leaves its monitor dockless, so outside a
    stop the whole set is torn down and the unit fails; systemd's
    Restart=on-failure respawns a dock on every monitor."""
    while children:
        try:
            pid, status = os.waitpid(-1, 0)
        except ChildProcessError:
            return 0
        exited = next((c for c in children if c.pid == pid), None)
        if exited is None:
            continue
        children.remove(exited)
        if _stopping:
            continue
        rc = os.waitstatus_to_exitcode(status)
        print(f"shedos-start-dock: child pid={pid} exited rc={rc}; "
              f"restarting the dock set", file=sys.stderr)
        _terminate_all(children)
        while children:
            try:
                pid2, _ = os.waitpid(-1, 0)
            except ChildProcessError:
                break
            children[:] = [c for c in children if c.pid != pid2]
        return rc if rc != 0 else 1
    return 0


def _install_signal_passthrough(children: list[subprocess.Popen]) -> None:
    """Forward SIGTERM / SIGRTMIN+1 to every child so systemd-stop
    and `shedman dock toggle` work even with multiple dock instances."""
    def _term(_sig, _frame):
        global _stopping
        _stopping = True
        _terminate_all(children)

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
