-- ShedOS Hyprland general behavior, layouts, and misc settings.

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,

        -- Colors come from the live theme (SHEDOS_THEME, hyprland.lua);
        -- `shedman theme apply` recolors borders on the next reload.
        col = {
            active_border = {
                colors = { SHEDOS_THEME.active_border1, SHEDOS_THEME.active_border2 },
                angle = 45,
            },
            inactive_border = SHEDOS_THEME.inactive_border,
        },

        layout = "dwindle",
        allow_tearing = false,
    },

    dwindle = {
        preserve_split = true,
        force_split = 2,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- Suppresses the cosmetic "started without start-hyprland"
        -- warning. greetd execs Hyprland directly, bypassing the
        -- wrapper; only the crash-recovery watchdog is impacted.
        disable_watchdog_warning = true,
        -- Lets a new lock client take over after one crashes; without
        -- this, the seat is bricked until reboot.
        allow_session_lock_restore = true,
    },
})
