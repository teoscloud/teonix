.pragma library

// 1:1 with nixbox waybar + nwg-dock rice tokens

var fg = "#f7f5ff"
// Qt Text does not parse CSS rgba() — use #AARRGGBB (~45% alpha)
var fgMuted = "#73f7f5ff"
var accent = "#cecad8"
var accentHot = "#e7f5c2"
var danger = "#e87a7a"
var success = "#8fd4a0"
var borderSoft = "#2e3236"

function borderColor() {
    return Qt.rgba(1, 1, 1, 0.24)
}

// Alias used by panels
var border = "#3a3c40"

var fontFamily = "FiraCode Nerd Font Mono"
// Bar scale ~1.10 from compact 36px baseline (theme.js needs qs reload)
var fontSize = 20
var fontSizeSm = 18
var fontSizeLg = 22

var barHeight = 40
// Pill framing (~3px top/bottom)
var moduleHeight = barHeight - 6
// Tray icons (was 24 → 22 → 20)
var trayIcon = 20
var moduleBtnWidth = 52
// ~10% larger than prior 54px icons
var dockIcon = 59
var dockHeight = 79
// Equal *visual* gap: windows↔dock and dock↔screen bottom.
// Hyprland adds gaps_out outside the exclusive zone, so subtract it.
var hyprGapsOut = 12
var dockMarginBottom = 10
var dockPillHeight = dockIcon + 20
var dockExclusive = dockPillHeight + 2 * dockMarginBottom - hyprGapsOut
var dockWindowHeight = dockExclusive + 4
var radius = 18
var radiusSm = 13
var spacing = 8
var pad = 9

var animFast = 120
var animMed = 180

// Waybar window#waybar wash — keep alpha above hypr ignore_alpha (0.08)
function barBg() {
    return Qt.rgba(200 / 255, 200 / 255, 200 / 255, 0.22)
}

// Shared module pills (#window, #tray, #custom-exit, …)
function pillBg() {
    return Qt.rgba(24 / 255, 25 / 255, 29 / 255, 0.5)
}

function pillHoverBg() {
    return Qt.rgba(42 / 255, 44 / 255, 46 / 255, 0.55)
}

// #workspaces container
function wsContainerBg() {
    return Qt.rgba(22 / 255, 24 / 255, 25 / 255, 0.5)
}

// Workspace button gradient fill (approx solid mid)
function wsBtnBg() {
    return Qt.rgba(32 / 255, 34 / 255, 35 / 255, 0.5)
}

// #clock
function clockBg() {
    return Qt.rgba(25 / 255, 26 / 255, 31 / 255, 0.5)
}

// Dock glass — Hyprland layerrule blur + low alpha
function dockBg() {
    return Qt.rgba(22 / 255, 24 / 255, 26 / 255, 0.38)
}

function dockHoverBg() {
    return Qt.rgba(1, 1, 1, 0.055)
}

// Overlay panels — flat frosted glass (Hyprland layer blur shows through)
function panelBg() {
    return Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.55)
}

function toastBg() {
    return Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.60)
}

function cardBg() {
    return Qt.rgba(1, 1, 1, 0.08)
}

function cardHoverBg() {
    return Qt.rgba(1, 1, 1, 0.12)
}

function mediaBg() {
    return Qt.rgba(1, 1, 1, 0.08)
}

var bg = "#161819"
var bgPanel = "#1a1c1e"
var bgElevated = "#2a2c2e"
var bgHover = "#34363a"
