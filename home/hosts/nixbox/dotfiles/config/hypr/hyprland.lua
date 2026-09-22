-- mainframe Hyprland config (Lua). Replaces hyprland.conf (hyprlang is
-- deprecated since 0.55, gone in 0.57). https://wiki.hypr.land/Configuring/Start/
--
-- Everything here is what hyprland.conf used to say, one statement per line
-- of the old file. Comments were carried over where they still explain why.

local home = os.getenv("HOME") or "/home/teodor"
local teonix = home .. "/teonix/home/hosts/nixbox/dotfiles"
local qs = teonix .. "/config/quickshell-mainframe/scripts"
local ipc = "bash " .. qs .. "/qs-live-ipc.sh"
local scripts = home .. "/.config/hypr/scripts"
local displaySafe = scripts .. "/display-safe.sh"
local mainMod = "SUPER"

local G9 = "desc:Samsung Electric Company LC49G95T"
local S27 = "desc:Samsung Electric Company S27E590"
local ASUS = "desc:ASUSTek COMPUTER INC VG245"

----------------
---- MONITORS --
----------------

-- Ports are interchangeable. Monitors are matched by EDID description prefix, never
-- by connector name, so any panel works in any DP/HDMI port. The serial is left off
-- on purpose: some panels report a different serial per port (the S27E590 gives
-- HTQGA01931 on DP but 0x304D4645 on HDMI). Get the prefix from `hyprctl monitors`
-- and drop the trailing serial.
--
-- mainframe: what the G9 may be driven at depends on the fitted card, so the limits
-- are not in here. teonix-gpu-profile writes TEONIX_MAX_PIXEL_RATE_MPS and
-- TEONIX_MAX_REFRESH_MULTI_OUTPUT per boot and display-safe.sh enforces them.
-- Arc A750 (i915 6.18): 5120x1440@240 is the startup mode below — the panel's
-- own preferred mode, no EDID override. It needs two display pipes ("bigjoiner"),
-- which only works when the G9 is in the card's LAST DisplayPort connector so the
-- next pipe is free (verified clean 2026-09-21 with the two 1080p outputs lit;
-- see hosts/mainframe/gpu.nix for why cabling is part of the config). If it ever
-- comes up as a magnified top-left quarter or fails to light, Super+Ctrl+S drops
-- to the single-pipe 5120x1440@120 and works blind. See hosts/mainframe/GPU.md.
--
-- Changing the primary display means updating the G9 prefix above and the
-- workspace rules below.
hl.monitor({ output = G9, mode = "5120x1440@240", position = "0x0", scale = 1, bitdepth = 8 })
-- Samsung 27" stays ABOVE the G9 (top-right corner). ASUS sits to the RIGHT of
-- the G9, bottom edges flush — Super+Esc toggles main between those two. Positions
-- match the 5120-wide full-mode default; when the G9's width changes they are
-- re-anchored by display-safe.sh plan_secondaries — via Super+S / Super+D, and
-- automatically by the `follow` loop when the G9 toggles PIP (2560 wide).
-- desc: only — any port.
hl.monitor({ output = S27, mode = "preferred", position = "3200x-1080", scale = 1, bitdepth = 8 })
-- 60 not preferred (75): each Hz on any output is one more full compositor pass
-- per second on Hyprland's single render thread. 15 fewer passes/s for a 24"
-- side panel. See GPU.md "Compositor core".
hl.monitor({ output = ASUS, mode = "1920x1080@60", position = "5120x360", scale = 1, bitdepth = 8 })
-- Catch-all: any other panel, in any port, gets its preferred mode placed to the
-- right automatically. Keep this last.
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = 1, bitdepth = 8 })

-- All workspaces live on the primary display, matched by description so they follow
-- it to whichever port it is plugged into.
for i = 1, 17 do
    hl.workspace_rule({ workspace = tostring(i), monitor = G9, default = (i == 1) })
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
-- Follow GTK/gsettings (Adwaita icons). Do not use kde — that pulls Breeze.
-- qt6ct without a config collapsed Qt to hicolor-only checkerboards.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("HYPRCURSOR_SIZE", "24")

-- BusChain — prefer Quickshell mixer + scroll strip (skip GTK strip)
hl.env("BUSCHAIN_CONTROL_QS_MIXER", "1")
hl.env("BUSCHAIN_CONTROL_QS_STRIP", "1")
-- Scroll strip overlays bar volume pill (left of title). Bar syncs margin via Globals.
hl.env("BUSCHAIN_CONTROL_SCROLL_ANCHOR", "left")
hl.env("BUSCHAIN_CONTROL_SCROLL_MARGIN_TOP", "1")
hl.env("BUSCHAIN_CONTROL_SCROLL_MARGIN_X", "120")
hl.env("BUSCHAIN_CONTROL_SCROLL_WIDTH", "110")
hl.env("BUSCHAIN_CONTROL_SCROLL_HEIGHT", "38")

----------------
---- START -----
----------------

-- Session plumbing (environment export, graphical-session.target) is UWSM's job:
-- pick "Hyprland (UWSM)" in GDM. Everything long-lived is launched through
-- `uwsm app --`, which hands it to systemd-run as its own scope under
-- app-graphical.slice (-s b: background-graphical.slice). On mainframe those
-- slices carry a cpuset that excludes the compositor's reserved core, so nothing
-- started from here inherits Hyprland's CPU pinning (hosts/mainframe/
-- compositor-core.nix). `uwsm app` is plain systemd-run underneath and works in
-- the non-UWSM "Hyprland" session too. Short one-shot commands (hyprctl,
-- brightnessctl, gsettings, playerctl, ...) stay bare.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor macOS 24")
    -- GNOME Keyring secret service (Mailspring, etc.) — not KWallet
    hl.exec_cmd("uwsm app -s b -- gnome-keyring-daemon --start")
    -- Wallpaper: hyprpaper only (swww + hyprpaper together is redundant and extra compositor load)
    -- Shell rice — White Mainframe (never bare `quickshell`, which follows a stale glass symlink).
    -- Quiet broken WhiteSur SVG paint warnings from tray icons (e.g. Obsidian)
    hl.exec_cmd("uwsm app -a quickshell -- bash -lc 'export QT_LOGGING_RULES=\"qt.svg.warning=false\"; exec bash "
        .. qs .. "/qsmainframe.sh'")
    -- BusChain Control — standalone ~/Projects/buschain-control (cargo / nix develop)
    -- hl.exec_cmd("buschain-control --hidden")
    hl.exec_cmd("uwsm app -s b -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -s b -- lxqt-policykit-agent")
    hl.exec_cmd("brightnessctl set 100%")
    hl.exec_cmd("brightnessctl -d '*::kbd_backlight' set 100%")
    hl.exec_cmd("uwsm app -s b -- gammastep -O 7500")
    hl.exec_cmd("uwsm app -s b -- bash -lc hyprpaper")
    hl.exec_cmd("uwsm app -s b -- bash -lc hypridle")
    -- Display watchdog: if every output ever ends up dark, recover in-session instead
    -- of needing a reboot (which on mainframe cannot clear a wedged GPU anyway).
    hl.exec_cmd("uwsm app -s b -a display-watchdog -- bash -lc '" .. displaySafe .. " watchdog'")
    -- Layout follower: the G9 toggling PIP is a DP reconnect with a smaller EDID
    -- (2560x1440@120 max); Hyprland falls back to that mode but leaves the secondaries
    -- at their 5120-wide anchors below. After every monitoradded burst this re-runs
    -- the ultrawide placement, so PIP and full mode both get a contiguous layout.
    hl.exec_cmd("uwsm app -s b -a display-follow -- bash -lc '" .. displaySafe .. " follow'")
    -- lan-mouse: send this keyboard/mouse to the Windows PC (UDP 4242)
    -- hl.exec_cmd("lan-mouse daemon")
    -- hyprlux: started by NixOS module (programs.hyprlux); do not start here (double-start causes conflicts)
    hl.exec_cmd("uwsm app -s b -- blueman-applet")
    -- Mullvad GUI (tray) — daemon is system-wide via services.mullvad-vpn
    hl.exec_cmd("uwsm app -- mullvad-vpn")
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences audible-bell false")
    hl.exec_cmd("flatpak override --filesystem=~/.themes:ro --filesystem=~/.icons:ro --user")
    -- udiskie: managed by Home Manager (tray=never); do NOT start here — tray popups crash Hyprland (CPopup::onCommit)
    -- scrolling-promote-new-window.sh: disabled, promote via mainMod+Shift+mouse:276
end)

-- Ran on every config (re)load, like the old `exec =`.
hl.exec_cmd('gsettings set org.gnome.desktop.interface icon-theme "WhiteSur-system"')
-- GTK / portal light-dark follows last White/Charcoal (qs writes ~/.config/qs-mainframe-theme)
hl.exec_cmd("bash " .. qs .. "/qs-system-appearance.sh")

----------------
---- OPTIONS ---
----------------

hl.config({
    ecosystem = { no_update_news = true },

    -- For all categories, see https://wiki.hypr.land/Configuring/Config-Options/
    input = {
        kb_layout = "us,se",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",

        follow_mouse = 1,
        mouse_refocus = false,

        force_no_accel = true,

        -- Force discrete wheel notches (1 click → 1 axis event). Auto(1) can leave
        -- hi-res SMOOTH deltas that Waybar coalesces into one on-scroll (missed %).
        -- Not a Waybar fork — compositor input only. 0=off 1=auto 2=force.
        emulate_discrete_scroll = 2,

        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            clickfinger_behavior = true,
            middle_button_emulation = false,
            tap_to_click = false,
            scroll_factor = 0.2,
        },

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
    },

    -- Official: no automatic pointer warp on focus / keybinds. Bar tabs and
    -- workspace clicks stay under the cursor. Super+` still teleports because
    -- cyclemon.sh calls movecursor itself.
    cursor = {
        no_warps = true,
        -- Explicit hardware cursor plane (not auto): a cursor move must never cost
        -- the render thread a full frame.
        no_hardware_cursors = false,
    },

    render = {
        -- A fullscreen window (Netflix, mpv, games) is scanned out straight from
        -- its own buffer; that output costs the compositor nothing while fullscreen.
        direct_scanout = true,
    },

    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border = { colors = { "rgba(141417ee)", "rgba(FFFFFFee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        layout = "scrolling",
    },

    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            xray = false,
            -- false: layer alpha participates in frost (needed for Quickshell glass)
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
        -- Hover-follow only for a real peek (partial column). Fully on-screen
        -- columns stay put. Super+arrows / clicks always follow.
        follow_min_visible = 0.25,
        focus_fit_method = 1,
    },

    master = { smart_resizing = true },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },

    xwayland = { force_zero_scaling = true },
})

-- Animations. borderangle loop: active window only, infinite on purpose.
hl.curve("linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "loop" })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

----------------
---- RULES -----
----------------

-- Wallpaper is hyprpaper's job (hyprpaper.conf).

-- Quickshell frost. Namespaces are RE2 full-match — quickshell.* not ^(quickshell).
-- ignore_alpha: skip blur only for near-clear pixels (rounded corners). Must be
-- BELOW the glass alphas in theme.js (bar≈0.17, dock≈0.38, panels≈0.55).
-- (The old `blurls` lines are gone: layer rules cover it.)
hl.layer_rule({
    name = "qs-blur",
    match = { namespace = "^(quickshell.*)$" },
    blur = true,
    xray = false,
    ignore_alpha = 0.08,
})
hl.layer_rule({
    name = "qs-blur-popups",
    match = { namespace = "^(quickshell.*)$" },
    blur_popups = true,
})
hl.layer_rule({
    name = "qs-no-blur-dismiss",
    match = { namespace = "^(quickshell:.*-dismiss)$" },
    blur = false,
})
hl.layer_rule({
    name = "qs-no-blur-mixer",
    match = { namespace = "^(quickshell:mixer-strip)$" },
    blur = false,
})

-- Pinned floating windows: distinct border color so they stand out
hl.window_rule({
    name = "pinned-border",
    match = { pin = true },
    border_color = { colors = { "rgb(F57676)", "rgb(F58B76)" } },
})

-- BusChain Control: Super+Q / window close → soft close (CancelClose + tray withdraw).
-- --hidden starts with no window (tray only); Show creates the UI. Avoid forcekill.

----------------
---- BINDS -----
----------------

local function key(mods, k)
    if mods == "" then return k end
    return mods .. " + " .. k
end
local M = mainMod
local MS = mainMod .. " + SHIFT"
local MC = mainMod .. " + CTRL"
local MA = mainMod .. " + ALT"

-- screenshot utils
hl.bind(key(MS, "S"), hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- system essentials
-- Power menu — Quickshell (fallback: wlogout)
hl.bind(key(M, "O"), hl.dsp.exec_cmd(ipc .. " power toggle"))
-- Notifications drawer — Quickshell
hl.bind(key(M, "N"), hl.dsp.exec_cmd(ipc .. " notifs toggle"))
hl.bind(key(M, "L"), hl.dsp.exec_cmd("uwsm app -a listentomb -- sh " .. home .. "/.config/hypr/listentomb.sh"))
hl.bind(key(MS, "L"), hl.dsp.exec_cmd(scripts .. "/audio-transmit-toggle.sh ssh"))
-- hl.bind(key(MS, "semicolon"), hl.dsp.exec_cmd(scripts .. "/audio-transmit-toggle.sh udp"))

-- Display modes. No connector names here on purpose: display-safe.sh discovers the
-- outputs, picks the primary by pixel count and verifies every modeset against
-- sysfs, so any panel works in any DP/HDMI port. Banned modes (over the pixel-rate
-- budget, e.g. 5120x1440@240 on the Arc, 5120x1440@120 on the RX 580) are never
-- requested by any of these. See hosts/mainframe/GPU.md.
--
--   Super+S        ultrawide: primary at its largest allowed mode at its fastest
--                  refresh (Arc: 5120x1440@240, the default; RX 580: 5120x1440@60),
--                  all other outputs stay on. Reverts itself if it goes dark.
--   Super+Ctrl+S   single-pipe fallback: the same, under a 900 Mpx/s budget passed
--                  in the environment (display-safe.sh honours the override), which
--                  admits only one-pipe modes -> 5120x1440@120 on the Arc. For when
--                  the two-pipe 240 comes up wrong; works blind.
--   Super+D        high refresh: primary at its fastest allowed mode (Arc: also
--                  5120x1440@240 now — same as Super+S; RX 580: 2560x1440@120).
--   Super+Shift+D  panic button: collapse to one known-good output.
hl.bind(key(M, "S"), hl.dsp.exec_cmd(displaySafe .. " ultrawide"))
hl.bind(key(MC, "S"), hl.dsp.exec_cmd("TEONIX_MAX_PIXEL_RATE_MPS=900 " .. displaySafe .. " ultrawide"))
hl.bind(key(M, "D"), hl.dsp.exec_cmd(displaySafe .. " highrefresh"))
hl.bind(key(MS, "D"), hl.dsp.exec_cmd(displaySafe .. " safe"))

-- Move "main" to another output: the bar, dock, overlays and every workspace
-- pinned to main follow along. Purely a designation change — no monitor's mode is
-- touched, so it is independent of resolution. Toggle bounces the G9 and the
-- ASUS to its right; `next` still walks every output.
hl.bind(key(M, "ESCAPE"), hl.dsp.exec_cmd(scripts .. "/main-monitor.sh toggle"))
hl.bind(key(MS, "ESCAPE"), hl.dsp.exec_cmd(scripts .. "/main-monitor.sh next"))

-- lan-mouse: Super+Ctrl enters Windows. One bind only — two binds double-fire.
-- hl.bind(key(MC, "code:37"), hl.dsp.exec_cmd(scripts .. "/lan-mouse-enter.sh"))

hl.bind(key(M, "SPACE"), hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind(key(M, "period"), hl.dsp.exec_cmd(ipc .. " emoji toggle"))
-- Legacy: wofi --show drun / wofi-emoji

-- Terminal: cool-retro-term, via a launcher that first pushes the current
-- qs-mainframe palette + zsh into its settings DB (it only reads that at
-- startup, and re-saves stale in-memory settings on close).
hl.bind(key(M, "T"), hl.dsp.exec_cmd("uwsm app -a cool-retro-term -- bash " .. home .. "/.config/quickshell/scripts/qs-retro-term-launch.sh"))
hl.bind(key(M, "Q"), hl.dsp.window.close())
hl.bind(key(M, "N"), hl.dsp.exec_cmd("uwsm app -- codium ~/myprojects/teonix-unstable/ && uwsm app -- codium ~/.config/"))
hl.bind(key(M, "C"), function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(key(M, "P"), hl.dsp.window.pin())
hl.bind(key(MS, "F"), hl.dsp.window.fullscreen())

-- Scrolling layout: swap active window's column with neighbor right/left
hl.bind(key(M, "TAB"), hl.dsp.layout("swapcol r"))
hl.bind(key(MS, "TAB"), hl.dsp.layout("swapcol l"))
-- Super+`: walk every output (left-to-right, wrap) and put the cursor on
-- that monitor's current workspace. Not the main-monitor designation.
hl.bind(key(M, "grave"), hl.dsp.exec_cmd("sh " .. home .. "/.config/hypr/cyclemon.sh"))

hl.bind(key(MA, "C"), hl.dsp.exec_cmd("uwsm app -- mpv av://v4l2:/dev/video1"))

-- Move focus with mainMod + arrow keys (layout focus for scrolling layout; works in-column and wraps)
hl.bind(key(M, "left"), hl.dsp.layout("focus l"))
hl.bind(key(M, "right"), hl.dsp.layout("focus r"))
hl.bind(key(M, "up"), hl.dsp.layout("focus u"))
hl.bind(key(M, "down"), hl.dsp.layout("focus d"))

hl.bind(key(MA, "a"), hl.dsp.layout("focus l"))
hl.bind(key(MA, "d"), hl.dsp.layout("focus r"))
hl.bind(key(MA, "w"), hl.dsp.layout("focus u"))
hl.bind(key(MA, "s"), hl.dsp.layout("focus d"))

hl.bind(key(M, "b"), hl.dsp.exec_cmd("uwsm app -- blueman-manager"))
hl.bind(key(M, "v"), hl.dsp.exec_cmd("uwsm app -- looking-glass-client -m KEY_GRAVE"))

-- Mullvad: Super+u disconnect | Super+i Stockholm | Super+Shift+i US
hl.bind(key(M, "u"), hl.dsp.exec_cmd("mullvad disconnect"))
hl.bind(key(M, "i"), hl.dsp.exec_cmd("mullvad relay set location se sto && mullvad connect"))
hl.bind(key(MS, "i"), hl.dsp.exec_cmd("mullvad relay set location us && mullvad connect"))

-- Switch workspaces with mainMod + [0-9], move the active window with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local k = tostring(i % 10)
    hl.bind(key(M, k), hl.dsp.focus({ workspace = i }))
    hl.bind(key(MS, k), hl.dsp.window.move({ workspace = i }))
end
local extraWs = { { "Z", 11 }, { "X", 12 }, { "A", 13 }, { "G", 14 }, { "W", 15 }, { "E", 16 }, { "R", 17 } }
for _, pair in ipairs(extraWs) do
    hl.bind(key(M, pair[1]), hl.dsp.focus({ workspace = pair[2] }))
    hl.bind(key(MS, pair[1]), hl.dsp.window.move({ workspace = pair[2] }))
end

-- Scrolling layout: mainMod + mouse4/5 = focus right/left, then lock the
-- pointer to that window's centre. cursor:no_warps leaves every other bind
-- still; only this script calls movecursor.
hl.bind(key(M, "mouse:275"), hl.dsp.exec_cmd(scripts .. "/focus-column.sh r"))
hl.bind(key(M, "mouse:276"), hl.dsp.exec_cmd(scripts .. "/focus-column.sh l"))
-- Scrolling layout: mainMod+Shift+mouse:276 = promote window to own column
hl.bind(key(MS, "mouse:276"), hl.dsp.layout("promote"))
-- Workspace: mainMod + mouse back/forward (all workspaces live on the primary)
-- Scroll up = higher workspace (1→2), scroll down = lower
hl.bind(key(M, "mouse_down"), hl.dsp.focus({ workspace = "m+1" }))
hl.bind(key(M, "mouse_up"), hl.dsp.focus({ workspace = "m-1" }))
-- Super+Shift+wheel: fluid pan. follow_focus off for the move so hover-fit
-- does not snap the tape back. (was: bindel + hyprctl --batch keyword/dispatch)
local function pan(px)
    return function()
        hl.config({ scrolling = { follow_focus = false } })
        hl.dispatch(hl.dsp.layout("move " .. px))
        hl.config({ scrolling = { follow_focus = true } })
    end
end
hl.bind(key(MS, "mouse_up"), pan("-400"), { repeating = true, locked = true })
hl.bind(key(MS, "mouse_down"), pan("+400"), { repeating = true, locked = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(key(M, "mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key(M, "mouse:273"), hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"))

-- Romanian: Right Alt + [ ] \ ; ' — full path: Hyprland exec PATH often has no `bash`.
-- systemctl --user enable --now ydotoold
local ro = "/run/current-system/sw/bin/bash " .. scripts .. "/ro-type.sh "
local roChars = {
    { "ALT_R + bracketleft", "i" }, { "SHIFT + ALT_R + bracketleft", "I" },
    { "ALT_R + bracketright", "a" }, { "SHIFT + ALT_R + bracketright", "A" },
    { "ALT_R + backslash", "u" }, { "SHIFT + ALT_R + backslash", "U" },
    { "ALT_R + semicolon", "s" }, { "SHIFT + ALT_R + semicolon", "S" },
    { "ALT_R + apostrophe", "t" }, { "SHIFT + ALT_R + apostrophe", "T" },
}
for _, pair in ipairs(roChars) do
    hl.bind(pair[1], hl.dsp.exec_cmd(ro .. pair[2]))
end
