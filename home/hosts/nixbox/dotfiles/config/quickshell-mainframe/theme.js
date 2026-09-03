.pragma library
// Light mainframe defaults for files that `import "theme.js" as Theme`
// (avoids shadowing issues; TopStrip/SessionRail use qmldir singleton Theme)
var bg = "#e8e9eb"
var bgRaised = "#f4f5f6"
var bgSelected = "#d0d2d6"
var fg = "#1a1c1e"
var fgMuted = "#6a6e74"
var accent = "#2a2e34"
var accentHot = "#3d4450"
var danger = "#a84848"
var success = "#3d7a52"
var hairline = "#9aa0a8"
var hatch = "#c8ccd2"
var hatchFg = "#8a9098"
var overlay = "#c0c4c8"
var border = "#9aa0a8"
var borderSoft = "#9aa0a8"
var fontFamily = "Michroma"
var fontFamilyUi = fontFamily
var fontSize = 13
var fontSizeSm = 11
var fontSizeLg = 16
var barHeight = 36
var moduleHeight = 32
var trayIcon = 18
var moduleBtnWidth = 44
var dockIcon = 40
var dockHeight = 52
var hyprGapsOut = 0
var dockMarginBottom = 4
var dockPillHeight = 56
var dockExclusive = 56
var dockWindowHeight = 60
var radius = 0
var radiusSm = 0
var spacing = 6
var pad = 8
var animFast = 120
var animMed = 180
var cornerRadius = 0
var pinIcon = 40
var instanceIcon = 22
var powerLogo = 34
var paraSlant = 16
var railHeight = 52
var railExclusive = 56
var hairlineWidth = 1
var hatchPitch = 6
var tabMaxWidth = 220
var tabMinWidth = 72
var shineEnabled = true
var shineOpacity = 0.16
var shineWidth = 0.28
var shineAngle = 45
var shineSpeed = 9000
var shineColor = "#5c6168"
var shineEdge = "#ffffff"
var shinePhase = 0
var revealMs = 220
var revealStartScale = 0.55

function borderColor() { return border }
function barBg() { return bg }
function pillBg() { return bgRaised }
function pillHoverBg() { return bgSelected }
function wsContainerBg() { return bgRaised }
function wsBtnBg() { return bgSelected }
function clockBg() { return bgRaised }
function panelBg() { return bgRaised }
function dockBg() { return bg }
function glassColor(a) { return Qt.rgba(0.95, 0.95, 0.96, a) }
