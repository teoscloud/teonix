import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "theme.js" as Theme

// Transparent Master HW hit target over the bar volume pill.
// Geometry: BUSCHAIN_CONTROL_SCROLL_* env (see HANDOVER-QUICKSHELL.md).
Scope {
    id: root

    // Prefer Bar-tracked pill geometry (Globals); env remains a fallback/override.
    readonly property int stripW: Math.max(40, Globals.volStripWidth || Number(Quickshell.env("BUSCHAIN_CONTROL_SCROLL_WIDTH") || 110))
    readonly property int stripH: Math.max(24, Number(Quickshell.env("BUSCHAIN_CONTROL_SCROLL_HEIGHT") || 38))
    readonly property int marginTop: Number(Quickshell.env("BUSCHAIN_CONTROL_SCROLL_MARGIN_TOP") || 1)
    readonly property int marginX: Globals.volStripMarginX >= 0
        ? Globals.volStripMarginX
        : Number(Quickshell.env("BUSCHAIN_CONTROL_SCROLL_MARGIN_X") || 120)
    readonly property string anchor: String(Globals.volStripAnchor || Quickshell.env("BUSCHAIN_CONTROL_SCROLL_ANCHOR") || "left").toLowerCase()

    property real accum: 0

    function notchesFromWheel(angleY) {
        root.accum += angleY;
        let notches = 0;
        while (root.accum >= 120) {
            notches += 1;
            root.accum -= 120;
        }
        while (root.accum <= -120) {
            notches -= 1;
            root.accum += 120;
        }
        if (notches > 2)
            notches = 2;
        if (notches < -2)
            notches = -2;
        return notches;
    }

    function applyNotches(n) {
        if (n === 0)
            return;
        const times = Math.abs(n);
        const dir = n > 0 ? "up" : "down";
        // Fire sequentially via single shell poke (max 2)
        const cmds = [];
        for (let i = 0; i < times; i++)
            cmds.push(Globals.buschainCtl + " hw-vol " + dir);
        poke.command = ["sh", "-c", cmds.join("; ")];
        poke.running = true;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: Globals.isShellMonitor(modelData)
            exclusiveZone: -1
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            aboveWindows: true
            WlrLayershell.namespace: "quickshell:mixer-strip"
            WlrLayershell.layer: WlrLayer.Top

            implicitWidth: root.stripW
            implicitHeight: root.stripH

            anchors {
                top: true
                left: root.anchor !== "right"
                right: root.anchor === "right"
            }

            margins {
                top: root.marginTop
                left: root.anchor !== "right" ? root.marginX : 0
                right: root.anchor === "right" ? root.marginX : 0
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: Globals.toggleMixer()
                onWheel: event => {
                    const n = root.notchesFromWheel(event.angleDelta.y);
                    root.applyNotches(n);
                    event.accepted = true;
                }
            }
        }
    }

    Process {
        id: poke
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: Globals.bumpHwVol()
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: Globals.bumpHwVol()
    }
}
