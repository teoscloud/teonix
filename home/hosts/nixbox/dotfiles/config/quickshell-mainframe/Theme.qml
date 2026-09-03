pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "theme/tokens-light.js" as Light
import "theme/tokens-dark.js" as Dark
import "theme/registry.js" as Registry
import "theme/geometry.js" as Geo

Singleton {
    id: root

    property string palette: "light"
    readonly property string mode: palette
    property bool motionOff: false

    readonly property var pack: palette === "dark" ? Dark : Light
    readonly property var palettes: Registry.palettes

    readonly property color bg: pack.bg
    readonly property color bgRaised: pack.bgRaised
    readonly property color bgSelected: pack.bgSelected
    readonly property color fg: pack.fg
    readonly property color fgMuted: pack.fgMuted
    readonly property color accent: pack.accent
    readonly property color accentHot: pack.accentHot
    readonly property color danger: pack.danger
    readonly property color success: pack.success
    readonly property color hairline: pack.hairline
    readonly property color hatch: pack.hatch
    readonly property color hatchFg: pack.hatchFg
    // Idle workspace / tab well. Active highlight is the lighter bgRaised.
    readonly property color groupWell: pack.groupWell
    readonly property color trayPlate: pack.trayPlate
    readonly property color overlay: pack.overlay
    readonly property color border: pack.border

    readonly property color shineColor: pack.shineColor
    readonly property color shineEdge: pack.shineEdge
    readonly property real shineOpacity: pack.shineOpacity
    readonly property real shineWidth: pack.shineWidth
    readonly property real shineAngle: pack.shineAngle
    readonly property int shineSpeed: pack.shineSpeed
    readonly property bool shineEnabled: !motionOff && !!pack.shineEnabled

    readonly property int revealMs: pack.revealMs
    readonly property real revealStartScale: pack.revealStartScale

    // Icon theme that matches the palette — Qt's own theme is dark on this host,
    // so light mode would otherwise show white-on-white tray glyphs.
    readonly property string iconTheme: pack.iconTheme
    readonly property string appIconTheme: pack.appIconTheme

    // Inject the TTF into Qt's font DB. A family-name lookup misses in
    // this qs wrap (it does not see ~/.local/share/fonts).
    FontLoader {
        id: crtFace
        source: Qt.resolvedUrl("fonts/Michroma-Regular.ttf")
    }
    readonly property string fontFamily: crtFace.status === FontLoader.Ready
        ? crtFace.name
        : pack.fontFamily
    readonly property string fontFamilyUi: fontFamily
    readonly property int fontSize: pack.fontSize
    readonly property int fontSizeSm: pack.fontSizeSm
    readonly property int fontSizeLg: pack.fontSizeLg

    readonly property int barHeight: Geo.barHeight
    readonly property int railHeight: Geo.railHeight
    readonly property int railExclusive: Geo.railExclusive
    readonly property int moduleInset: Geo.moduleInset
    readonly property int pinIcon: Geo.pinIcon
    readonly property int instanceIcon: Geo.instanceIcon
    readonly property int powerLogo: Geo.powerLogo
    readonly property int trayIcon: Geo.trayIcon
    readonly property int tabSlice: Geo.tabSlice
    readonly property int octCut: Geo.octCut
    readonly property int chamfer: Geo.chamfer
    readonly property int tickLen: Geo.tickLen
    readonly property int wedge: Geo.wedge
    readonly property int hairlineWidth: Geo.hairlineWidth
    readonly property real strokeActive: Geo.strokeActive
    readonly property int hatchPitch: Geo.hatchPitch
    readonly property int gridPitch: Geo.gridPitch
    readonly property real hatchFieldOpacity: Geo.hatchFieldOpacity
    readonly property color gridInk: pack.gridInk
    readonly property real gridOpacity: pack.gridOpacity
    readonly property color overlayGridInk: pack.overlayGridInk
    readonly property real overlayGridOpacity: pack.overlayGridOpacity
    readonly property int edgeScalePitch: Geo.edgeScalePitch
    readonly property int cornerRadius: Geo.cornerRadius
    readonly property int spacing: Geo.spacing
    readonly property int pad: Geo.pad
    readonly property int sepWidth: Geo.sepWidth
    readonly property int pillPadIdle: Geo.pillPadIdle
    readonly property int pillPadActive: Geo.pillPadActive
    readonly property int tabGap: Geo.tabGap
    readonly property int tabMaxWidth: Geo.tabMaxWidth
    readonly property int tabMinWidth: Geo.tabMinWidth
    readonly property int fontSizeBar: Geo.fontSizeBar
    readonly property int fontSizeMicro: Geo.fontSizeMicro
    readonly property int animFast: Geo.animFast
    readonly property int animMed: Geo.animMed
    readonly property int animSpring: Geo.animSpring

    // Shared shine clock 0..1 for all MainframeSurface instances
    property real shinePhase: 0

    NumberAnimation on shinePhase {
        from: 0
        to: 1
        duration: Math.max(2000, root.shineSpeed)
        loops: Animation.Infinite
        running: root.shineEnabled
    }

    readonly property string themeStatePath: `${Quickshell.env("HOME")}/.config/qs-mainframe-theme`

    function setPalette(id) {
        const p = Registry.find(id)
        palette = p.id
        persist()
        applySystemAppearance()
    }

    function toggle() {
        setPalette(Registry.nextId(palette))
    }

    function persist() {
        themeWrite.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config\" && printf '%s\\n' '" + palette + "' > '" + themeStatePath + "'"
        ]
        themeWrite.running = true
    }

    function loadPersisted() {
        try {
            const raw = themeFile.text().trim()
            const first = raw.split("\n")[0].trim()
            if (first && first.indexOf("motion=") !== 0)
                palette = Registry.find(first).id
            if (raw.indexOf("motion=off") >= 0)
                motionOff = true
        } catch (e) {
        }
        applySystemAppearance()
    }

    readonly property string systemAppearanceScript: Quickshell.shellPath("scripts/qs-system-appearance.sh")

    function applySystemAppearance() {
        const mode = palette === "dark" ? "dark" : "light"
        sysTheme.command = ["bash", root.systemAppearanceScript, mode]
        sysTheme.running = true
        applyHyprBorders()
    }

    // Spinning active-window border. Speed 22 ≈ 2.2s/rev (glass is 30).
    function applyHyprBorders() {
        const active = palette === "dark"
            ? "rgba(101214ee) rgba(f0f2f6f0) 45deg"
            : "rgba(2a2e34ee) rgba(fffffff0) 45deg"
        const inactive = palette === "dark"
            ? "rgba(4a5058aa)"
            : "rgba(9aa0a8aa)"
        hyprDeco.command = ["hyprctl", "--batch",
            "keyword decoration:rounding 9;" +
            "keyword decoration:rounding_power 1;" +
            "keyword general:border_size 1;" +
            "keyword general:col.active_border " + active + ";" +
            "keyword general:col.inactive_border " + inactive + ";" +
            "keyword bezier linear,0,0,1,1;" +
            "keyword animation borderangle,1,22,linear,loop"]
        hyprDeco.running = true
    }

    FileView {
        id: themeFile
        path: root.themeStatePath
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root.loadPersisted()
        Component.onCompleted: reload()
    }

    Process { id: themeWrite }
    Process { id: sysTheme }
    Process { id: hyprDeco }

    // Compat shims used by ported glass files
    function barBg() { return bg }
    function panelBg() { return bgRaised }
    function dockBg() { return bg }
    function pillBg() { return bgRaised }
    function pillHoverBg() { return bgSelected }
    function glassColor(a) { return Qt.rgba(0.1, 0.1, 0.12, a) }

    property real radius: 0
    property real radiusSm: 0
    property int moduleHeight: barHeight - 4
    property int moduleBtnWidth: 44
    property int dockIcon: pinIcon
    property int dockHeight: railHeight
    property int dockExclusive: railExclusive
    property int dockWindowHeight: railExclusive + 4
    property int dockMarginBottom: 4
    property int dockPillHeight: railHeight - 8
    property int hyprGapsOut: 0
}
