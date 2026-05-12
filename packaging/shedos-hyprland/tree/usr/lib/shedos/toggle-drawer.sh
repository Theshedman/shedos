#!/bin/bash
# shedos-toggle-drawer — toggle the resident nwg-drawer.
#
# SIGUSR1 is nwg-drawer's "toggle visibility" signal when running in
# -r/resident mode. Used as nwg-dock-hyprland's launcher-button command
# so a click on the launcher icon shows or hides the drawer instantly,
# without re-launching the drawer process.
#
# -x matches /proc/<pid>/comm exactly. We deliberately don't use -f
# (full cmdline) because pkill -f would match its own argv (which
# contains the literal string "nwg-drawer"), self-signal, and die.
# The drawer's comm is exactly "nwg-drawer" (10 chars, within the
# 15-char comm limit) so -x is reliable.
logger -t shedos-toggle-drawer "invoked from PPID=$PPID"
pkill -USR1 -x nwg-drawer
rc=$?
logger -t shedos-toggle-drawer "pkill rc=$rc"
exit $rc
