-- applenix Hyprland config (Lua). Replaces deprecated hyprland.conf (gone in 0.57).
-- https://wiki.hypr.land/Configuring/Start/

local home = os.getenv("HOME") or "/home/teodorstan"
local ipc = "bash " .. home .. "/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe/scripts/qs-live-ipc.sh"
local ro = home .. "/.config/hypr/scripts/ro-type.sh"
local mainMod = "SUPER"

----------------
---- MONITORS --
----------------

-- 1.6 is required on this panel (2560×1600 integer logical pixels). Do not drop to 1.
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1.6,
})
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "eDP-1",
        default = (i == 1),
    })
end

----------------
---- ENV -------
----------------

hl.env("NIXOS_OZONE_WL", "1")
hl.env("NIXPKGS_ALLOW_UNFREE", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("WLR_XCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "macOS")
hl.env("WLR_XCURSOR_THEME", "macOS")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("HYPRCURSOR_SIZE", "24")

----------------
---- LOOK ------
----------------

hl.config({
    ecosystem = {
        no_update_news = true,
    },

    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border = { colors = { "rgba(2a2e34ee)", "rgba(fffffff0)" }, angle = 45 },
            inactive_border = "rgba(9aa0a8aa)",
        },
        layout = "scrolling",
    },

    decoration = {
        rounding = 9,
        rounding_power = 1,
        shadow = { enabled = false },
        blur = {
            enabled = false,
            size = 4,
            passes = 2,
            xray = false,
            ignore_opacity = false,
            noise = 0.01,
            contrast = 0.9,
            brightness = 0.88,
            vibrancy = 0.1,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    scrolling = {
        column_width = 0.66,
        follow_focus = true,
        follow_min_visible = 0,
        focus_fit_method = 1,
    },

    master = { smart_resizing = true },

    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_invert = true,
        workspace_swipe_cancel_ratio = 0.3,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_create_new = true,
        workspace_swipe_direction_lock = true,
        workspace_swipe_forever = false,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgb(1a1024)",
    },

    xwayland = { force_zero_scaling = true },

    input = {
        kb_layout = "us,se",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",
        follow_mouse = 1,
        mouse_refocus = false,
        force_no_accel = false,
        emulate_discrete_scroll = 2,
        sensitivity = 0.3,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            clickfinger_behavior = true,
            middle_button_emulation = false,
            tap_to_click = false,
            scroll_factor = 0.15,
        },
    },
})

hl.curve("mfEase", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "mfEase", style = "popin 55%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "mfEase", style = "popin 55%" })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "mfEase", style = "popin 55%" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 22, bezier = "linear", style = "loop" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

hl.device({
    name = "apple-spi-trackpad",
    sensitivity = 0.3,
    scroll_factor = 0.15,
    natural_scroll = true,
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

----------------
---- RULES -----
----------------

hl.layer_rule({
    name = "qs-blur",
    match = { namespace = "^quickshell.*$" },
    blur = true,
    xray = false,
    ignore_alpha = 0.08,
})
hl.layer_rule({
    name = "qs-blur-popups",
    match = { namespace = "^quickshell.*$" },
    blur_popups = true,
})
hl.layer_rule({
    name = "qs-no-blur-dismiss",
    match = { namespace = "^quickshell:.*-dismiss$" },
    blur = false,
})
hl.layer_rule({
    name = "qs-no-blur-mixer",
    match = { namespace = "^quickshell:mixer-strip$" },
    blur = false,
})

hl.window_rule({
    name = "pinned-border",
    match = { pin = true },
    -- amber so pinned floats stand out
    border_color = { colors = { "rgb(F57676)", "rgb(F58B76)" } },
})

-- Steam's Add/Browse popups are empty-title 0×0 X11 windows. Without a
-- minsize they never appear. stayfocused can freeze Hyprland — skip it.
hl.window_rule({
    name = "steam-ghost-popups",
    match = { class = "^[Ss]team$", title = "^$" },
    min_size = { 1, 1 },
})
hl.window_rule({
    name = "steam-add-nonsteam",
    match = { title = "Add Non-Steam Game" },
    float = true,
})

-- Battle.net / Wine CEF: no blur, no fade, no rounding. Those punch black
-- holes through XWayland surfaces on the 1.6 scaled panel.
hl.window_rule({
    name = "battlenet-surfaces",
    match = { class = "^steam_app_battlenet$" },
    rounding = 0,
    border_size = 1,
})
hl.window_rule({
    name = "battlenet-login",
    match = { title = "Battle.net Login" },
    float = true,
    rounding = 0,
})
hl.window_rule({
    name = "battlenet-setup",
    match = { title = "^Battle.net Setup$" },
    float = true,
    rounding = 0,
})

----------------
---- START -----
----------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor macOS 24")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")
    hl.exec_cmd("teonix-secrets-ensure")
    hl.exec_cmd("env QT_LOGGING_RULES=qt.svg.warning=false quickshell")
    hl.exec_cmd("bash " .. home .. "/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe/scripts/qs-system-appearance.sh")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("lxqt-policykit-agent")
    hl.exec_cmd("brightnessctl set 100%")
    hl.exec_cmd("brightnessctl -d '*::kbd_backlight' set 100%")
    hl.exec_cmd("gammastep -O 7500")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("mullvad-vpn")
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences audible-bell false")
    hl.exec_cmd("flatpak override --filesystem=~/.themes:ro --filesystem=~/.icons:ro --user")
    hl.exec_cmd(home .. "/.config/hypr/scripts/hyprflow-restore-on-login.sh")
end)

----------------
---- BINDS -----
----------------

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(ipc .. " power toggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(ipc .. " notifs toggle"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(ipc .. " emoji toggle"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("codium ~/myprojects/teonix-unstable/ && codium ~/.config/"))
hl.bind(mainMod .. " + C", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(mainMod .. " + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + TAB", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("sh " .. home .. "/.config/hypr/cyclemon.sh"))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("mpv av://v4l2:/dev/video1"))

hl.bind(mainMod .. " + left", hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + right", hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + up", hl.dsp.layout("focus u"))
hl.bind(mainMod .. " + down", hl.dsp.layout("focus d"))
hl.bind(mainMod .. " + ALT + A", hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + ALT + D", hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.layout("focus u"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.layout("focus d"))

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("mullvad disconnect"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("mullvad relay set location se sto && mullvad connect"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("mullvad relay set location us && mullvad connect"))

local extraWs = { Z = 11, X = 12, A = 13, G = 14, W = 15, E = 16, R = 17 }
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
for key, ws in pairs(extraWs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

hl.bind(mainMod .. " + mouse:275", hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + mouse:276", hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + SHIFT + mouse:276", hl.dsp.layout("promote"))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true })

local roChars = {
    { "ALT_R + bracketleft", "i" },
    { "SHIFT + ALT_R + bracketleft", "I" },
    { "ALT_R + bracketright", "a" },
    { "SHIFT + ALT_R + bracketright", "A" },
    { "ALT_R + backslash", "u" },
    { "SHIFT + ALT_R + backslash", "U" },
    { "ALT_R + semicolon", "s" },
    { "SHIFT + ALT_R + semicolon", "S" },
    { "ALT_R + apostrophe", "t" },
    { "SHIFT + ALT_R + apostrophe", "T" },
}
for _, pair in ipairs(roChars) do
    hl.bind(pair[1], hl.dsp.exec_cmd("bash " .. ro .. " " .. pair[2]))
end
