-- ShedOS Hyprland window rules.

-- Simple floaters (no size/center)
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-nm-connection-editor", match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "float-vlc", match = { class = "^(vlc)$" }, float = true })

-- TUI / management tools; float, size, center
hl.window_rule({ name = "overskride", match = { class = "^(io.github.kaii_lb.Overskride)$" }, float = true, size = { 800, 600 }, center = true })
hl.window_rule({ name = "impala", match = { class = "^(impala)$" }, float = true, size = { 800, 600 }, center = true })
hl.window_rule({ name = "bluetui", match = { class = "^(bluetui)$" }, float = true, size = { 800, 600 }, center = true })
hl.window_rule({ name = "btop", match = { class = "^(btop)$" }, float = true, size = { 800, 600 }, center = true })
hl.window_rule({ name = "shedos-logs", match = { class = "^(shedos-logs)$" }, float = true, size = { 1100, 700 }, center = true })
hl.window_rule({ name = "shedos-upgrade-history", match = { class = "^(shedos-upgrade-history)$" }, float = true, size = { 1000, 650 }, center = true })
hl.window_rule({ name = "shedos-review", match = { class = "^(shedos-review)$" }, float = true, size = { 1600, 1000 }, center = true })
hl.window_rule({ name = "shedos-datetime", match = { class = "^(shedos-datetime)$" }, float = true, size = { 800, 640 }, center = true })

-- yad dialogs (used by `shedman install`). Without this rule Hyprland
-- tiles them fullscreen, ignoring the --width/--height yad requests.
hl.window_rule({ name = "yad", match = { class = "^[Yy]ad$" }, float = true, center = true })

-- Firefox Picture-in-Picture: float + pin
hl.window_rule({ name = "firefox-pip", match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" }, float = true, pin = true })

-- Floating terminal (Super+Shift+Return spawns kitty with this class).
hl.window_rule({ name = "floating-terminal", match = { class = "^(floating-terminal)$" }, float = true, size = { 1100, 700 }, center = true })

-- Terminal / editor opacity (active 0.95, inactive 0.9)
hl.window_rule({ name = "kitty-opacity", match = { class = "^(kitty)$" }, opacity = "0.95 0.9" })
hl.window_rule({ name = "vscode-opacity", match = { class = "^(code-url-handler)$" }, opacity = "0.95 0.9" })
