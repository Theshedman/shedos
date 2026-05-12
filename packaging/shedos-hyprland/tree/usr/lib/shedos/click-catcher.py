#!/usr/bin/env python3
"""shedos-click-catcher — full-screen invisible layer-shell surface that
closes the drawer when the user clicks anywhere outside its visible area.

How it works:

- nwg-drawer renders on the layer-shell ``overlay`` layer.
- This catcher renders on the ``top`` layer (one below overlay).
- The compositor delivers each pointer click to the topmost surface that
  occupies that screen coordinate. Clicks in the drawer's visible area
  hit the drawer (overlay). Clicks anywhere else fall through to us.
- On click, we send the drawer's hide signal and become invisible
  until the drawer opens again.

State is driven by Hyprland's ``socket2.sock`` event stream:
``openlayer>>nwg-drawer`` shows the catcher, ``closelayer>>nwg-drawer``
hides it. The catcher is invisible+inactive when the drawer is closed,
so it never interferes with normal pointer use.

Replaces the activewindow-based watcher (which fired on focus-follows-
mouse motion, not actual clicks).
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gtk, GtkLayerShell  # noqa: E402


DRAWER_NAMESPACE = "nwg-drawer"
DRAWER_CLOSE_SIGNAL = "-37"  # SIGRTMIN+3 — nwg-drawer's hide signal


def _close_drawer() -> None:
    subprocess.run(
        ["pkill", DRAWER_CLOSE_SIGNAL, "-x", "nwg-drawer"],
        check=False,
    )


class Catcher:
    def __init__(self) -> None:
        self.win = Gtk.Window()
        self.win.set_app_paintable(True)
        # Honour the screen's RGBA visual so the window is truly
        # transparent — no GTK theme background paints over the wallpaper.
        screen = self.win.get_screen()
        visual = screen.get_rgba_visual()
        if visual is not None:
            self.win.set_visual(visual)

        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.TOP)
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(self.win, edge, True)
        GtkLayerShell.set_namespace(self.win, "shedos-click-catcher")
        # No keyboard interactivity — we never want focus.
        GtkLayerShell.set_keyboard_mode(
            self.win, GtkLayerShell.KeyboardMode.NONE
        )

        self.win.set_decorated(False)
        self.win.connect("button-press-event", self._on_click)
        # Start hidden — only show while the drawer is visible.

    def _on_click(self, _widget, _event) -> bool:
        _close_drawer()
        # Hide ourselves immediately too; the closelayer event will
        # follow and is idempotent.
        self.hide()
        return True

    def show(self) -> None:
        self.win.show_all()

    def hide(self) -> None:
        self.win.hide()


def _hyprland_listener(catcher: Catcher) -> None:
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not (instance and runtime):
        print(
            "shedos-click-catcher: HYPRLAND_INSTANCE_SIGNATURE or "
            "XDG_RUNTIME_DIR unset",
            file=sys.stderr,
        )
        return
    sock_path = f"{runtime}/hypr/{instance}/.socket2.sock"
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(sock_path)
    except OSError as e:
        print(
            f"shedos-click-catcher: cannot connect to {sock_path}: {e}",
            file=sys.stderr,
        )
        return

    open_prefix = f"openlayer>>{DRAWER_NAMESPACE}"
    close_prefix = f"closelayer>>{DRAWER_NAMESPACE}"
    with sock.makefile("r") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith(open_prefix):
                GLib.idle_add(catcher.show)
            elif line.startswith(close_prefix):
                GLib.idle_add(catcher.hide)


def main() -> int:
    catcher = Catcher()
    listener = threading.Thread(
        target=_hyprland_listener, args=(catcher,), daemon=True
    )
    listener.start()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
