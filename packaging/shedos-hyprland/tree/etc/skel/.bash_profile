# shellcheck shell=bash
# Login-shell environment. The graphical session gets its env from uwsm
# and Hyprland's env.lua; this file only covers TTY logins and the
# terminal chain.
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# shellcheck source=/dev/null
[[ -f ~/.bashrc ]] && . ~/.bashrc
