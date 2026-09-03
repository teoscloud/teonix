.pragma library

// White mainframe — light baseline. Milled-steel gray, not paper white: panels
// read as plates against the darker bar wash.
var bg = "#8a9199"
var bgRaised = "#e8eaee"
var bgSelected = "#9aa2ac"
// Idle oct wells sit lighter than the bar wash; active is near-white.
var groupWell = "#c5cad1"
var trayPlate = "#f4f5f7"
var fg = "#1a1c1e"
var fgMuted = "#5c6168"
var accent = "#2a2e34"
var accentHot = "#3d4450"
var danger = "#a84848"
var success = "#3d7a52"
var hairline = "#7a8088"
var hatch = "#9aa2ac"
var hatchFg = "#3d4248"
// Steel wash (#8a9199) needs dark ink — muted gray disappears on it
var gridInk = "#1a1c1e"
var gridOpacity = 0.2
// Popouts: steel wash, not bar ink. Bars keep gridInk / 0.2.
var overlayGridInk = "#9aa2ac"
var overlayGridOpacity = 0.08
var overlay = "#a8adb4"
var border = "#7a8088"

// Peak is steel; edge is white so RGB actually interpolates (same-RGB
// alpha fades render as a solid slab in Qt gradients).
var shineColor = "#5c6168"
var shineEdge = "#ffffff"
var shineOpacity = 0.2
var shineWidth = 0.28
var shineAngle = 45
var shineSpeed = 9000
var shineEnabled = true

var revealMs = 220
var revealOrigin = "topLeft"
var revealStartScale = 0.55

var iconTheme = "WhiteSur-light"
var appIconTheme = "hicolor"

var fontFamily = "Michroma"
var fontFamilyFallback = "IBM Plex Sans"
var fontSize = 13
var fontSizeSm = 11
var fontSizeLg = 16
