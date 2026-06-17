"""Shared ShedOS palette loader for terminal UIs.

Reads the live named palette from ``/etc/shedos/themes/current/palette.conf``
(written by the theme reconciler and swapped atomically on ``shedman theme
set``) so Textual TUIs can colour themselves to match the rest of the desktop
and re-theme live when the palette changes. Pure Python, no Textual import, so
it stays cheap to unit-test on its own.
"""

import os
import re

CURRENT_DIR = "/etc/shedos/themes/current"
PALETTE_CONF = CURRENT_DIR + "/palette.conf"
SENTINEL = CURRENT_DIR + "/.applied-at"

# Catppuccin Mocha — the fallback when the theme dir is missing or garbled,
# matching shedos_prompt_ui::Theme::load_or_default so the TUIs default to the
# same colours as the GUIs.
MOCHA = {
    "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b",
    "text": "#cdd6f4", "subtext0": "#a6adc8", "subtext1": "#bac2de",
    "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
    "overlay0": "#6c7086", "overlay1": "#7f849c", "overlay2": "#9399b2",
    "blue": "#89b4fa", "lavender": "#b4befe", "sapphire": "#74c7ec",
    "sky": "#89dceb", "teal": "#94e2d5", "green": "#a6e3a1",
    "yellow": "#f9e2af", "peach": "#fab387", "maroon": "#eba0ac",
    "red": "#f38ba8", "mauve": "#cba6f7", "pink": "#f5c2e7",
    "flamingo": "#f2cdcd", "rosewater": "#f5e0dc",
    "accent": "#a6e3a1", "accent_secondary": "#94e2d5",
}

# `$name = rgba(RRGGBBaa)` -> (name, RRGGBB); alpha is dropped.
_LINE = re.compile(r"^\$(\w+)\s*=\s*rgba\(([0-9a-fA-F]{6})[0-9a-fA-F]{2}\)")


def load():
    """Return ``{name: '#rrggbb'}`` from the live palette.

    Starts from the Mocha fallback and overlays whatever ``palette.conf``
    defines, so every Mocha key is always present (callers can index freely)
    and a missing or garbled file degrades to plain Mocha rather than raising.
    """
    pal = dict(MOCHA)
    try:
        with open(PALETTE_CONF, "r", encoding="utf-8") as fh:
            for line in fh:
                m = _LINE.match(line.strip())
                if m:
                    pal[m.group(1)] = "#" + m.group(2).lower()
    except OSError:
        return dict(MOCHA)
    return pal


def applied_stamp():
    """mtime of the apply sentinel, or ``None``. Compare it across polls to
    notice a live ``shedman theme set``."""
    try:
        return os.stat(SENTINEL).st_mtime
    except OSError:
        return None
