#!/usr/bin/env bash
# Reload the awww wallpaper daemon after `shedman theme apply` so the
# new wallpaper takes effect immediately. awww caches the image at
# process start (autostart.conf:exec-once); without this hook the
# desktop keeps showing the old image until next Hyprland restart.

set -u

if ! command -v awww >/dev/null 2>&1; then
    exit 0
fi

# Skip silently if no awww daemon is running in this user session
# (e.g., the renderer was invoked from a TTY or pre-Hyprland boot).
# The daemon binary is `awww-daemon`; the `awww` invocation here is
# the client.
if ! pgrep -u "$(id -u)" -x awww-daemon >/dev/null 2>&1; then
    exit 0
fi

awww img /etc/shedos/themes/current/wallpaper.png
