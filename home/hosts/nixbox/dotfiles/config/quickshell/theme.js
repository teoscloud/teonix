.pragma library

// Shared theme — importable from any subdirectory (Quickshell 0.3)
var bg = "#161819"
var bgPanel = "#1a1c1e"
var bgElevated = "#2a2c2e"
var bgHover = "#34363a"
var border = "#2e3236"
var fg = "#f7f5ff"
var fgMuted = "#9a9aa8"
var accent = "#cecad8"
var accentHot = "#e7f5c2"
var danger = "#e87a7a"
var success = "#8fd4a0"

var barOpacity = 0.92
var panelOpacity = 0.94
var pillOpacity = 0.55

var fontFamily = "FiraCode Nerd Font Mono"
var fontSize = 13
var fontSizeSm = 11
var fontSizeLg = 15

var barHeight = 36
var dockHeight = 70
var radius = 16
var radiusSm = 12
var spacing = 8
var pad = 10

var animFast = 120
var animMed = 180

function pillBg() {
    return Qt.rgba(22 / 255, 24 / 255, 25 / 255, pillOpacity)
}

function panelBg() {
    return Qt.rgba(26 / 255, 28 / 255, 30 / 255, panelOpacity)
}
