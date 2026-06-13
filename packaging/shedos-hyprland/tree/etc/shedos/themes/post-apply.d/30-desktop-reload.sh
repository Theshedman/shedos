#!/usr/bin/env bash
# Apply a theme change to the live desktop after `shedman theme apply`.
# Hyprland re-reads its config on a config-only reload, with no flicker,
# so window borders and shadow recolor at once (it dofile()s the freshly
# rendered palette.lua). The wallpaper lives in 10-awww.sh and kitty/mako
# in 20-terminal-notifications.sh — all of those re-read and repaint in
# place.
#
# waybar and the dock are deliberately left out: neither can recolor in
# place. waybar's only reload (SIGUSR2) tears the bar down and rebuilds
# it, and nwg-dock has no reload signal at all, so re-reading its palette
# means restarting the process. Both flicker visibly on every apply, so
# they pick up the new colors on their next restart (a logout/login or
# monitor change) instead. walker and the drawer launch on demand and
# re-read on next open, so they need no nudge.

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
