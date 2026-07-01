-- ShedOS Hyprland environment variables.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_DATA_DIRS", "/usr/local/share:/usr/share")

-- Locale comes from /etc/locale.conf (the installer's choice); forcing
-- it here would clobber that for every GUI app.

-- Qt
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- GTK
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("GTK_THEME", "catppuccin-mocha-blue-standard+default")

-- GPU render env (AQ_DRM_DEVICES + nvidia vars) is written by the installer to
-- /etc/uwsm/env from detected hardware; it must load before Hyprland, so it
-- can't live in this config.

hl.config({
    xwayland = { force_zero_scaling = true },
    -- Suppress ecosystem update + donation prompts on session start.
    ecosystem = { no_update_news = true, no_donation_nag = true },
})
