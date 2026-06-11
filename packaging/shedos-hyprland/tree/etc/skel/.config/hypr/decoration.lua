-- ShedOS Hyprland decoration, animations, and layer rules.

hl.config({
    decoration = {
        rounding = 10,

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            xray = true,
        },

        shadow = {
            enabled = true,
            range = 20,
            render_power = 3,
            -- Live-themed; see SHEDOS_THEME in hyprland.lua.
            color = SHEDOS_THEME.shadow,
        },
    },

    animations = { enabled = true },
})

hl.curve("overshot",  { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve("smoothIn",  { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5,  bezier = "overshot",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4,  bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,  bezier = "default" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5,  bezier = "smoothIn" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 5,  bezier = "smoothIn" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "overshot",  style = "slide" })

-- Layer rules (wlr-layer-shell: walker, waybar, mako, etc.)

-- Frosted backdrop for the walker launcher and its popovers
hl.layer_rule({ match = { namespace = "walker" }, blur = true, ignore_alpha = 0.6 })
-- Waybar + notifications also benefit from blur
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "mako" }, blur = true })
