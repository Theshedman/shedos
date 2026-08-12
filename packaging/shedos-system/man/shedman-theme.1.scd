shedman-theme(1)

# NAME

shedman-theme - inspect and switch the system theme

# SYNOPSIS

*shedman theme* {*list*|*get*}++
*shedman theme* *set* _key_ _value_++
*shedman theme* *apply*

# DESCRIPTION

Manages the *[theme]* section of */etc/shedos/system.toml* and
re-renders */etc/shedos/themes/current/* — the outputs every themed
surface reads (hyprland borders, waybar, walker, kitty, mako, fzf,
the greeter, lock and power overlays, GTK). After *set*/*apply*,
running surfaces reload live via the post-apply hooks.

# COMMANDS

*list*
	Available palettes under */etc/shedos/themes/palettes/*.

*get*
	Current *[theme]* values.

*set* _key_ _value_
	Set *palette*, *wallpaper* (absolute path), *font_ui*, or
	*font_mono*; re-renders automatically.

*apply*
	Re-render without changing values.

# SEE ALSO

*shedman*(1), *shedman-apply*(1)
