shedman-screenrecord(1)

# NAME

shedman-screenrecord - start or stop screen recording

# SYNOPSIS

*shedman screenrecord* [*--waybar*]

# DESCRIPTION

Starts a *wf-recorder* capture of the focused output
(*Super+R*); *--stop* (*Super+Shift+R*) ends it. While
recording, the waybar indicator pill shows a stop control; the
finished file lands in *~/Videos*. Invoked again, stops the
recording.

# OPTIONS

*--waybar*
	JSON payload for the waybar indicator (signal 11).

# SEE ALSO

*shedman-keybindings*(1)
