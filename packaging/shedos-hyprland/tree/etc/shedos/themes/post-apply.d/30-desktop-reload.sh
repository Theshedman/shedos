#!/usr/bin/env bash
# Apply a theme change to the live desktop after `shedman theme apply`,
# so a new palette or font shows at once without a manual `hyprctl
# reload`. These surfaces read /etc/shedos/themes/current/ once at
# startup and don't re-read on their own:
#   - Hyprland: hyprland.lua dofile()s palette.lua (window borders, shadow)
#   - waybar:   style.css @imports palette.css
#   - the dock: nwg-dock style.css @imports palette.css
# The wallpaper lives in 10-awww.sh and kitty/mako in
# 20-terminal-notifications.sh. walker (a warm --gapplication-service)
# and the drawer are launched on demand and re-read on next open, so
# they need no nudge here.

set -u

# Hyprland is addressed through its instance socket under
# $XDG_RUNTIME_DIR/hypr/<signature>/. An interactive `shedman theme
# apply` inherits HYPRLAND_INSTANCE_SIGNATURE from the session; a sudo
# invocation (the install scriptlet) does not, so discover it. No live
# instance means nothing to reload — skip the hyprctl step quietly.
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} && -d ${XDG_RUNTIME_DIR:-}/hypr ]]; then
    for _inst in "$XDG_RUNTIME_DIR"/hypr/*/; do
        [[ -S ${_inst}.socket.sock ]] || continue
        HYPRLAND_INSTANCE_SIGNATURE=$(basename "$_inst")
        export HYPRLAND_INSTANCE_SIGNATURE
        break
    done
fi
if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    # config-only re-parses the config (picks up the freshly rendered
    # palette.lua) without a monitor re-probe, which would flash the
    # outputs on a recolor. Autostart runs on the hyprland.start event,
    # not exec lines, so a reload does not re-spawn it.
    hyprctl reload config-only >/dev/null 2>&1 || true
fi

# waybar reloads its config + stylesheet on SIGUSR2 (man waybar: SIGUSR2
# "reloads (resets) the bar"), re-reading the @import'd palette.css with
# no restart and no flicker.
pkill -u "$(id -u)" -SIGUSR2 -x waybar 2>/dev/null || true

# The dock keeps its @import'd palette.css from process start; restarting
# the unit is the clean way to re-read it, and systemd brings it right
# back. Guarded on is-active so an apply at boot or from a TTY is a no-op.
if command -v systemctl >/dev/null 2>&1 \
    && systemctl --user is-active --quiet shedos-dock.service 2>/dev/null; then
    systemctl --user restart shedos-dock.service 2>/dev/null || true
fi
