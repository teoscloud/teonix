pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property bool mixerOpen: false
    property bool notifDrawerOpen: false
    property bool powerMenuOpen: false
    property bool launcherOpen: false
    property bool emojiOpen: false
    property int notifCount: 0

    // Bar + dock only on this Hyprland output (hyprctl monitors)
    property string shellMonitor: "DP-1"

    function isShellMonitor(screen) {
        return !!(screen && screen.name === shellMonitor);
    }

    // Wallpaper-derived glass tint (overlays only — not bar/dock)
    property real wallR: 0.12
    property real wallG: 0.12
    property real wallB: 0.14
    property string wallPath: ""
    // 0 = dark base only, 1 = pure wallpaper tint
    property real wallStrength: 0.68

    // Resolve against the active shell tree (works with qs -p and HM symlink)
    readonly property string buschainWaybar: Quickshell.shellPath("scripts/qs-buschain-waybar.sh")
    readonly property string buschainCtl: Quickshell.shellPath("scripts/qs-buschain-ctl.sh")
    readonly property string wallpaperTintScript: Quickshell.shellPath("scripts/qs-wallpaper-tint.py")
    readonly property string mixerTickPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/buschain-control/mixer.tick`

    // Shared Master HW status for VolumePill / ScrollStrip
    property int hwVolPct: 0
    property bool hwVolMuted: false
    property bool hwVolOnline: false
    property int hwVolEpoch: 0

    // VolumePill geometry (updated from Bar.qml) — strip + mixer anchor
    property string volStripAnchor: "left"
    property int volStripMarginX: 120
    property int volStripWidth: 110
    property int volPillX: 120
    property int volPillWidth: 64
    // ScrollStrip sits above the bar; forward hover so the pill can gray
    property bool volStripHovered: false

    function bumpHwVol() {
        hwVolEpoch++;
    }

    function glassColor(alpha) {
        // Composite: dark glass base × wallpaper average tint
        const s = wallStrength;
        const br = 0.07, bg = 0.07, bb = 0.09;
        return Qt.rgba(
            br * (1 - s) + wallR * s,
            bg * (1 - s) + wallG * s,
            bb * (1 - s) + wallB * s,
            alpha
        );
    }

    function applyTintJson(text) {
        try {
            const j = JSON.parse(String(text || "").trim());
            if (typeof j.r === "number")
                wallR = Math.max(0, Math.min(1, j.r));
            if (typeof j.g === "number")
                wallG = Math.max(0, Math.min(1, j.g));
            if (typeof j.b === "number")
                wallB = Math.max(0, Math.min(1, j.b));
            if (j.path)
                wallPath = String(j.path);
        } catch (e) {
            // keep previous tint
        }
    }

    function refreshWallpaperTint() {
        tintProc.running = false;
        tintProc.running = true;
    }

    Process {
        id: tintProc
        command: ["python3", Globals.wallpaperTintScript]
        stdout: StdioCollector {
            id: tintOut
            waitForEnd: true
            onStreamFinished: Globals.applyTintJson(tintOut.text)
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    // Cache for instant first paint before ffmpeg finishes
    FileView {
        id: tintCache
        path: `${Quickshell.env("HOME")}/.cache/qs-wallpaper-tint.json`
        blockLoading: true
        watchChanges: true
        onLoaded: Globals.applyTintJson(text())
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    Timer {
        interval: 45000
        running: true
        repeat: true
        onTriggered: Globals.refreshWallpaperTint()
    }

    Component.onCompleted: Qt.callLater(() => Globals.refreshWallpaperTint())

    // Refresh when an overlay opens (picks up wallpaper changes quickly)
    onLauncherOpenChanged: if (launcherOpen)
        refreshWallpaperTint()
    onEmojiOpenChanged: if (emojiOpen)
        refreshWallpaperTint()
    onNotifDrawerOpenChanged: if (notifDrawerOpen)
        refreshWallpaperTint()

    function closeOverlays() {
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        launcherOpen = false;
        emojiOpen = false;
    }

    function toggleMixer() {
        mixerOpen = !mixerOpen;
        if (mixerOpen) {
            notifDrawerOpen = false;
            powerMenuOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function openMixer() {
        mixerOpen = true;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        launcherOpen = false;
        emojiOpen = false;
    }

    function closeMixer() {
        mixerOpen = false;
    }

    function toggleNotifs() {
        notifDrawerOpen = !notifDrawerOpen;
        if (notifDrawerOpen) {
            mixerOpen = false;
            powerMenuOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function togglePower() {
        powerMenuOpen = !powerMenuOpen;
        if (powerMenuOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function toggleLauncher() {
        launcherOpen = !launcherOpen;
        if (launcherOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            powerMenuOpen = false;
            emojiOpen = false;
        }
    }

    function openLauncher() {
        launcherOpen = true;
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        emojiOpen = false;
    }

    function closeLauncher() {
        launcherOpen = false;
    }

    function toggleEmoji() {
        emojiOpen = !emojiOpen;
        if (emojiOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            powerMenuOpen = false;
            launcherOpen = false;
        }
    }

    function openEmoji() {
        emojiOpen = true;
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        launcherOpen = false;
    }

    function closeEmoji() {
        emojiOpen = false;
    }
}
