shedos-dock(5)

# NAME

shedos-dock - dock configuration file

# SYNOPSIS

*~/.config/shedos/dock.toml*

# DESCRIPTION

Configuration consumed by the dock launcher and edited by
*shedman-dock*(1) (the supported path; hand edits work but skip the
live restart).

# KEYS

*position* = "bottom" | "top" | "left" | "right"
	Screen edge the dock docks to.

*icon_size* = _integer_
	Icon size in pixels.

*launcher_cmd* = _string_
	Command the launcher button runs.

# SEE ALSO

*shedman-dock*(1)
