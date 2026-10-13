---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "fuzzel"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- General Keybinds:
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W",      hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("google-chrome-stable"))

-- Script Keybinds:
hl.bind(mainMod .. " + ESCAPE",   hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh toggle"))
hl.bind(mainMod .. " + SUPER_L",  hl.dsp.exec_cmd("~/.config/eww/scripts/start.sh toggle"), { release = true })
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/eww/scripts/screenshot.sh"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Z",      hl.dsp.exec_cmd("~/.config/hypr/screensaver/screensaver.sh start"))
hl.bind(mainMod .. " + TAB",    hl.dsp.exec_cmd("~/.config/eww/scripts/dash.sh toggle"))
hl.bind(mainMod .. " + T",      hl.dsp.exec_cmd("~/.config/eww/scripts/themes.sh toggle"))

-- Inactive Opacity: SUPER + = / -
local function inactiveOpacity(step)
    local o = hl.get_config("decoration.inactive_opacity") + step
    hl.config({ decoration = { inactive_opacity = math.max(0.1, math.min(1, o)) } })
end
hl.bind(mainMod .. " + EQUAL", function() inactiveOpacity(0.05) end,  { repeating = true })
hl.bind(mainMod .. " + MINUS", function() inactiveOpacity(-0.05) end, { repeating = true })

-- ETC Keybinds:
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh ask logout"))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh ask lock"))
hl.bind(mainMod .. " + F",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + J",      hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + C",		hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }))
hl.bind(mainMod .. " + V",		hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))


-- Window Focus:
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces: SUPER + SHIFT + [NUM] move window
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Media + brightness (laptop)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Power Panel Confirm Function
hl.define_submap("power-confirm", function()
    hl.bind("RETURN",   hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh confirm"))
    hl.bind("KP_Enter", hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh confirm"))
    hl.bind("ESCAPE",   hl.dsp.exec_cmd("~/.config/eww/scripts/panel.sh disarm"))
end)

-- Dashboard Open: ESC backs out of stargazing / closes, SUPER + TAB closes
hl.define_submap("dash", function()
    hl.bind("ESCAPE",          hl.dsp.exec_cmd("~/.config/eww/scripts/dash.sh esc"))
    hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.config/eww/scripts/dash.sh close"))
    hl.bind("XF86AudioNext",   hl.dsp.exec_cmd("playerctl next"))
    hl.bind("XF86AudioPlay",   hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioPause",  hl.dsp.exec_cmd("playerctl play-pause"))
    hl.bind("XF86AudioPrev",   hl.dsp.exec_cmd("playerctl previous"))
end)
-- Theme Picker Open: ESC / SUPER + T close it
hl.define_submap("themes", function()
    hl.bind("ESCAPE",          hl.dsp.exec_cmd("~/.config/eww/scripts/themes.sh close"))
    hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/eww/scripts/themes.sh close"))
end)
-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Theme Colors: written by ~/.local/bin/theme, mono if it hasn't run yet
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.cache/theme/hypr.lua")
if not ok or type(theme) ~= "table" then
    theme = { active = "rgba(d0d0d0ff)", inactive = "rgba(2a2a2aff)" }
end

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 10,
        border_size = 1,

        col = {
            active_border   = theme.active,
            inactive_border = theme.inactive,
        },

        layout = "dwindle",
    },

    decoration = {
        rounding       = 4,
        rounding_power = 2,

		active_opacity   = 0.99,
        inactive_opacity = 0.9,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        focus_on_activate       = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},  {0.32, 1}  } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},     {1, 1}     } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1}  } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},  {0.1, 1}   } })
hl.curve("easy",         { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
     -- Boot Into Lock Screen + Idle:
     hl.exec_cmd("hyprlock")
     hl.exec_cmd("hypridle")
     hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
     hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
     hl.exec_cmd("mako")
	 -- theme restore first: it writes eww's colors.scss + starts swaybg
	 hl.exec_cmd("~/.local/bin/theme restore; eww daemon && eww open bar --id bar0 --arg monitor=0; eww open bar --id bar1 --arg monitor=1")
end)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Eww Power Panel: On GPU
hl.layer_rule({
    name      = "eww-panel-slide",
    match     = { namespace = "^eww-panel$" },
    animation = "slide right",
})

-- Eww Tray Dropdown:
hl.layer_rule({
    name      = "eww-tray-pop",
    match     = { namespace = "^eww-tray$" },
    animation = "popin 90%",
})

-- Eww Start Panel:
hl.layer_rule({
    name      = "eww-start-slide",
    match     = { namespace = "^eww-start$" },
    animation = "slide left",
})

-- Eww Dashboard: Fade + Blur Behind
hl.layer_rule({
    name         = "eww-dash-fade",
    match        = { namespace = "^eww-dash$" },
    animation    = "fade",
    blur         = true,
    ignore_alpha = 0.3,
})

-- Eww Theme Picker:
hl.layer_rule({
    name      = "eww-themes-pop",
    match     = { namespace = "^eww-themes$" },
    animation = "popin 90%",
})

-- Stargazing (sky.py over the dashboard):
hl.layer_rule({
    name      = "eww-sky-fade",
    match     = { namespace = "^eww-sky$" },
    animation = "fade",
})

-- Joke Screensaver: Fullscreen + Slide
hl.window_rule({
    name       = "screensaver",
    match      = { class = "^screensaver$" },
    fullscreen = true,
    float      = true,
    animation  = "slide",
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,

        
        accel_profile = "flat",
        sensitivity   = -0.375,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "12")
hl.env("HYPRCURSOR_SIZE", "12")

------------------
---- MONITORS ----
------------------

-- For Laptop
hl.monitor({
	output	 = "eDP-1",
	mode	 = "preferred",
	position = "0x0",
	scale 	 = 1,
})

hl.monitor({
    output   = "desc:HP Inc. HP E273",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
	output	 = "desc:HP Inc. OMEN X 27",
	mode	 = "1920x1080@239.76",
	position = "1920x0",
	scale    = 1,
})
-----------------------
----- PERMISSIONS -----
-----------------------

hl.config({
    ecosystem = {
        enforce_permissions = true,
    },
})

-- Permissions for Screencopy
hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprlock", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")