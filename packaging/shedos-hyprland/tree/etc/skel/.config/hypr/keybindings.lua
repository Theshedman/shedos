-- ShedOS Hyprland keybindings.

local mainMod = "SUPER"

-- Applications
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("shedman launcher"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("nautilus -w"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("postman"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("shedman browser"))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty --class=floating-terminal"))
hl.bind(mainMod .. " + ALT + J", hl.dsp.exec_cmd("kitty --class=shedos-logs -e shedman logs"))
hl.bind(mainMod .. " + ALT + K", hl.dsp.exec_cmd("shedman keybindings"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("kitty --class=shedos-upgrade-history -e shedman update --history"))

-- Dock: Super+T toggles, Super+ALT+{B,L,R} moves it to an edge.
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("shedman dock toggle"))
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("shedman dock position bottom"))
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("shedman dock position left"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("shedman dock position right"))

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- Split orientation; O for "orientation" (J belongs to vim focus below).
hl.bind(mainMod .. " + O", hl.dsp.layout("togglesplit"))

-- Focus: arrows and full vim hjkl.
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Move windows: SHIFT + arrows / hjkl.
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Resize: CTRL + arrows / hjkl.
local function resize(x, y)
    return hl.dsp.window.resize({ x = x, y = y, relative = true })
end
hl.bind(mainMod .. " + CTRL + left",  resize(-50, 0))
hl.bind(mainMod .. " + CTRL + right", resize(50, 0))
hl.bind(mainMod .. " + CTRL + up",    resize(0, -50))
hl.bind(mainMod .. " + CTRL + down",  resize(0, 50))
hl.bind(mainMod .. " + CTRL + H", resize(-50, 0))
hl.bind(mainMod .. " + CTRL + L", resize(50, 0))
hl.bind(mainMod .. " + CTRL + K", resize(0, -50))
hl.bind(mainMod .. " + CTRL + J", resize(0, 50))

-- Workspaces: Super+[1-0] focuses, Super+SHIFT+[1-0] moves the window.
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,            hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,    hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots. The helper creates the save dir, aborts quietly when
-- the slurp selection is cancelled, and notifies on save.
hl.bind("Print", hl.dsp.exec_cmd("/usr/lib/shedos/screenshot region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("/usr/lib/shedos/screenshot full"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("/usr/lib/shedos/screenshot save"))

-- Screen recording; shedman screenrecord toggles via walker prompt;
-- Super+Shift+R stops the active recording (idempotent if none).
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("/usr/bin/shedman screenrecord"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/usr/bin/shedman screenrecord --stop"))

-- Color picker
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))

-- Clipboard history. Two `wl-paste --watch cliphist store` entries in
-- autostart.lua feed the store; walker's elephant-clipboard provider
-- renders the picker.
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("walker --provider clipboard"))

-- Alt-Tab: MRU strip with app icons; hold Alt, Tab cycles, release
-- switches. The walker "$" prefix stays as the fuzzy-search path;
-- SUPER+Tab keeps the spatial overview.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("shedos-switcher"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("shedos-switcher --prev"))

-- Lock screen
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("/usr/libexec/shedman/lock"))

-- System controls. The exit fallback uses the Lua dispatch syntax —
-- the pre-0.55 `hyprctl dispatch exit` form no longer parses.
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd([[sh -c 'command -v uwsm >/dev/null 2>&1 && exec uwsm stop; command -v hyprshutdown >/dev/null 2>&1 && exec hyprshutdown; hyprctl dispatch "hl.dsp.exit()"']]))
-- Config reload; on Ctrl+Shift+R to leave Super+Shift+R for
-- `shedman screenrecord --stop` (a chord users hit far more often).
hl.bind(mainMod .. " + SHIFT + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Night Light
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("/usr/bin/toggle-hyprsunset.sh"))

-- Do Not Disturb; toggles mako's dnd mode. Critical alerts still show.
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("/usr/lib/shedos/osd dnd"))

-- Audio. locked = works on the lock screen; repeating = ramps on hold.
-- The osd helper wraps pamixer and shows a mako popup with a progress
-- fill.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/usr/lib/shedos/osd volume up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/usr/lib/shedos/osd volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("/usr/lib/shedos/osd volume mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("/usr/lib/shedos/osd volume mic"),  { locked = true, repeating = true })

-- Brightness (same repeat-on-hold + locked behavior)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("/usr/lib/shedos/osd brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("/usr/lib/shedos/osd brightness down"), { locked = true, repeating = true })

-- Media: locked, one-shot (no repeat).
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
