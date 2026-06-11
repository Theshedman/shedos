-- ShedOS Hyprland configuration (Lua, Hyprland 0.55+).
--
-- Each concern lives in a focused module alongside this file. Edit the
-- module you want without touching the rest; add one by dropping a
-- .lua file here and requiring it below. Modules are error-isolated:
-- a mistake in one never takes down the others. If binds fail to load,
-- Hyprland provides emergency keys (SUPER+Q terminal, SUPER+R run,
-- SUPER+M exit).

-- Live theme palette, shared by general/decoration below. `shedman
-- theme apply` regenerates the palette; Catppuccin Mocha is the
-- fallback when it is missing (fresh installs, broken renders).
SHEDOS_THEME = {
    active_border1  = "rgba(89b4faee)",
    active_border2  = "rgba(cba6f7ee)",
    inactive_border = "rgba(585b70aa)",
    shadow          = "rgba(1e1e2eee)",
}
local ok, pal = pcall(dofile, "/etc/shedos/themes/current/palette.lua")
if ok and type(pal) == "table" then
    for k, v in pairs(pal) do SHEDOS_THEME[k] = v end
end

require("env")
require("monitors")
require("autostart")
require("input")
require("general")
require("decoration")
require("windowrules")
require("keybindings")
require("gestures")
