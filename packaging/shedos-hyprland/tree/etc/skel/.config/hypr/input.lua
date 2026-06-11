-- ShedOS Hyprland input (keyboard, mouse, touchpad).

hl.config({
    input = {
        kb_layout = "us",
        -- Caps Lock behaves as Caps Lock (explicit default). Alternatives:
        --   kb_options = "caps:escape"        -- Caps Lock → Escape (vim-friendly)
        --   kb_options = "caps:swapescape"    -- Caps Lock ↔ Escape swap
        --   kb_options = "caps:ctrl_modifier" -- Caps Lock → Ctrl
        --   kb_options = "caps:none"          -- Caps Lock disabled
        kb_options = "caps:capslock",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            drag_lock = true,
        },

        sensitivity = 0,
        accel_profile = "flat",
    },
})
