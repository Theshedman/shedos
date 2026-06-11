-- ShedOS Hyprland touchpad gestures.
--
-- Two-finger swipes stay reserved for libinput (scroll / right-click);
-- two-finger pinch drives cursor zoom — the accessibility-zoom analog
-- the hyprlang config could not express.

-- 3-finger horizontal — switch workspaces. Carries any window
-- currently being dragged with Super+LMB.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 3-finger pinch — toggle fullscreen / float on the active window.
hl.gesture({ fingers = 3, direction = "pinchin",  action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "pinchout", action = "float" })

-- 2-finger pinch — cursor zoom in/out (macOS accessibility zoom).
hl.gesture({ fingers = 2, direction = "pinchout", action = "cursorZoom", zoom_level = 2.0 })
hl.gesture({ fingers = 2, direction = "pinchin",  action = "cursorZoom", zoom_level = 1.0 })

-- 4-finger horizontal — move the active window to the prev/next
-- workspace.
hl.gesture({ fingers = 4, direction = "left",  action = function() hl.dispatch(hl.dsp.window.move({ workspace = "e-1" })) end })
hl.gesture({ fingers = 4, direction = "right", action = function() hl.dispatch(hl.dsp.window.move({ workspace = "e+1" })) end })

-- 4-finger pinch out — show desktop (toggles the `minimized` special
-- workspace; pinch out again restores).
hl.gesture({ fingers = 4, direction = "pinchout", action = function() hl.dispatch(hl.dsp.workspace.toggle_special("minimized")) end })

-- 4-finger pinch in — launcher.
hl.gesture({ fingers = 4, direction = "pinchin", action = function() hl.exec_cmd("shedman launcher") end })

-- ---- Hyprspace plugin: workspace overview --------------------------
-- macOS-Mission-Control strip with live window thumbnails; autoDrag
-- lets users drag windows between workspaces inside the overview.
hl.plugin.load("/usr/lib/hyprland/Hyprspace.so")

hl.config({
    plugin = {
        overview = {
            centerAligned = 1,        -- macOS-style horizontal alignment
            onBottom = 0,             -- panel at the top (Mission Control)
            panelHeight = 250,
            workspaceMargin = 12,
            workspaceBorderSize = 1,
            affectStrut = 1,          -- reserve top 250px; tiled windows reflow below
            autoDrag = 1,             -- drag-window-between-workspaces
            switchOnDrop = 1,         -- follow the window to its new workspace
            exitOnClick = 1,          -- click outside to close
            exitOnSwitch = 1,         -- close when the workspace switches
        },
    },
})

-- The overview actions come from our Hyprspace fork's Lua functions
-- (hl.plugin.hyprspace.*) — legacy plugin dispatchers are unreachable
-- from the Lua config. The functions register after the plugin loads,
-- so guard each call; up/down are paired opposites: direction matches
-- result regardless of state.
local function overview(action)
    return function()
        local hs = hl.plugin.hyprspace
        if hs and hs[action] then hs[action]() end
    end
end

hl.gesture({ fingers = 3, direction = "up",   action = overview("open") })
hl.gesture({ fingers = 3, direction = "down", action = overview("close") })
hl.gesture({ fingers = 4, direction = "up",   action = overview("open") })
hl.gesture({ fingers = 4, direction = "down", action = overview("close") })

-- Keyboard parity: Super+Tab toggles the overview.
hl.bind("SUPER + Tab", overview("toggle"))
