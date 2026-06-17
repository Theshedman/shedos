-- ShedOS Hyprland window rules.

-- The config-review merge TUI wants as much room as the panel allows, but a
-- fixed size clips the bars on smaller screens. Size it from the active
-- monitor, leaving a fixed margin for the top bar + dock — they're fixed
-- pixels, so subtracting a constant scales correctly across resolutions, and
-- their reserved areas aren't queryable here (nor set this early) anyway.
local function review_size()
  local m = hl.get_active_monitor()
  if not m then return { 1000, 650 } end
  local scale = m.scale or 1.0
  local w = math.min(math.floor(m.width / scale) - 120, 1600)
  local h = math.min(math.floor(m.height / scale) - 150, 1000)
  return { math.max(w, 800), math.max(h, 450) }
end

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
hl.window_rule({ name = "shedos-review", match = { class = "^(shedos-review)$" }, float = true, size = review_size(), center = true })
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
