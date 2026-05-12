shedman-dock(1) "ShedOS" "User Commands"

# NAME

shedman-dock - manage the ShedOS application dock

# SYNOPSIS

*shedman dock* [_subcommand_] [_args ..._]

# DESCRIPTION

*shedman dock* is the user-facing control surface for the ShedOS
application dock — a Hyprland-native pinned-app dock backed by
*nwg-dock-hyprland*(1) and *nwg-drawer*(1). The dock runs under the
*shedos-dock.service* systemd user unit; mutating commands restart
the unit so changes take effect immediately.

The dock reads two files:

	~/.config/shedos/dock.toml
		Position, icon size, and the command bound to the dock's
		launcher button. Managed by this subcommand; see
		*shedos-dock*(5) for the schema. Edits via this CLI
		preserve hand-added comments.

	~/.cache/nwg-dock-pinned
		One application id per line (matched against window
		class names). Manipulated by *shedman dock pin* /
		*unpin*; the dock's own right-click menu writes here
		too. This is a cache-dir path because the dock treats
		pinned state as runtime cache, not user configuration.

# SUBCOMMANDS

*toggle*
	Show or hide the running dock (sends _SIGRTMIN+1_ to
	*nwg-dock-hyprland*). If the unit is stopped, starts it.

*position* {*bottom*|*top*|*left*|*right*}
	Move the dock to that edge of the screen. Updates _dock.toml_
	and restarts the unit. Position changes are sub-second.

*pin* _app_
	Append _app_ to the pinned list and restart the unit. _app_ is
	the window class name (e.g. _firefox_) or a _.desktop_ file
	basename without the suffix (e.g. _org.gnome.Nautilus_).

*unpin* _app_
	Remove _app_ from the pinned list and restart the unit.

*pinned*
	Print the current pinned list, one entry per line.

*restart*
	*systemctl --user restart shedos-dock.service*. Useful after
	editing _dock.toml_ by hand.

*status* (default)
	Print whether the unit is active, the current position, and
	the pinned list.

# KEYBINDINGS

The shipped Hyprland config binds:

	*Super+T*			*shedman dock toggle*
	*Super+ALT+B*		*shedman dock position bottom*
	*Super+ALT+L*		*shedman dock position left*
	*Super+ALT+R*		*shedman dock position right*

# EXIT STATUS

*0*
	Command succeeded (or no-op).

*1*
	Pinned-app not found (*unpin*), or systemctl restart failed.

*2*
	Invalid argument (e.g. unknown position).

# FILES

~/.config/shedos/dock.toml
	Dock configuration. See *shedos-dock*(5).

~/.cache/nwg-dock-pinned
	Pinned-app list, one entry per line. Cache-dir path because
	the dock owns this file as runtime state.

~/.config/nwg-dock-hyprland/style.css
	GTK CSS for the dock surface. Imports the active palette from
	_/etc/shedos/themes/current/palette.css_.

~/.config/nwg-drawer/drawer.css
	GTK CSS for the app drawer (full-screen grid with search and
	category filtering).

# SEE ALSO

*shedman*(1), *nwg-dock-hyprland*(1), *nwg-drawer*(1).
