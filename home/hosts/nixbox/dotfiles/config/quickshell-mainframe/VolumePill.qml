import Quickshell
import Quickshell.Io
import QtQuick
import "components"

// Visual pill stays module-height; hitbox uses full bar height (same as WorkspaceBar).
Item {
    id: root
    implicitHeight: Theme.barHeight
    implicitWidth: pill.width + 16

    readonly property int pillW: pill.width
    property int pct: Globals.hwVolPct
    property bool muted: Globals.hwVolMuted
    property bool online: Globals.hwVolOnline
    property real accum: 0

    Pill {
        id: pill
        anchors.centerIn: parent
        implicitHeight: Theme.moduleHeight
        implicitWidth: Math.max(row.implicitWidth + 22, 64)
        // Strip layer sits above the bar and steals hover — include Globals.volStripHovered
        hovered: hitMa.containsMouse || Globals.volStripHovered || Globals.mixerOpen

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            opacity: root.online ? 1 : 0.85

            Text {
                id: icon
                text: !root.online ? "󰕦" : (root.muted ? "󰖁" : (root.pct < 34 ? "󰕿" : (root.pct < 67 ? "󰖀" : "󰕾")))
                color: !root.online ? Theme.danger : (root.muted ? Theme.danger : Theme.fg)
                font.family: "Symbols Nerd Font Mono, JetBrainsMono Nerd Font, " + Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg + 4
                verticalAlignment: Text.AlignVCenter
            }

            // Digits sit high in FiraCode NF vs nerd icons — pin to icon line box + nudge down
            Item {
                width: pctLabel.implicitWidth
                height: icon.height
                Text {
                    id: pctLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: root.online ? (root.pct + "%") : "—"
                    color: !root.online ? Theme.danger : (root.muted ? Theme.danger : Theme.fg)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Soft danger wash when daemon is down
        Rectangle {
            anchors.fill: parent
            radius: 0
            visible: !root.online
            color: Qt.rgba(0.55, 0.18, 0.18, 0.28)
            z: -1
        }
    }

    // Full bar-height click / wheel / hover target (extends past pill padding)
    MouseArea {
        id: hitMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.toggleMixer()
        onWheel: event => {
            if (!root.online) {
                event.accepted = true;
                return;
            }
            root.accum += event.angleDelta.y;
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
            if (notches !== 0) {
                const times = Math.abs(notches);
                const dir = notches > 0 ? "up" : "down";
                const cmds = [];
                for (let i = 0; i < times; i++)
                    cmds.push(Globals.buschainCtl + " hw-vol " + dir);
                poke.command = ["sh", "-c", cmds.join("; ")];
                poke.running = true;
            }
            event.accepted = true;
        }
    }

    function applyStatus(text) {
        try {
            const j = JSON.parse(String(text || "").trim());
            const cls = String(j.class || "");
            const online = cls === "online" || cls === "normal" || cls === "muted";
            Globals.hwVolOnline = online;
            if (!online) {
                Globals.hwVolPct = 0;
                Globals.hwVolMuted = false;
                return;
            }
            let p = parseInt(j.percentage ?? j.hw_volume_pct ?? 0, 10);
            if (isNaN(p))
                p = 0;
            Globals.hwVolPct = Math.max(0, Math.min(100, p));
            Globals.hwVolMuted = !!j.muted || !!j.hw_mute || cls === "muted";
        } catch (e) {
            Globals.hwVolOnline = false;
        }
    }

    Process {
        id: statusProc
        command: [Globals.buschainWaybar, "status"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyStatus(text)
        }
        onExited: code => {
            if (code !== 0)
                Globals.hwVolOnline = false;
        }
    }

    Process {
        id: poke
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: statusProc.running = true
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: statusProc.running = true
    }

    FileView {
        path: Globals.mixerTickPath
        watchChanges: true
        onFileChanged: {
            reload();
            statusProc.running = true;
        }
    }

    Connections {
        target: Globals
        function onHwVolEpochChanged() {
            statusProc.running = true;
        }
        function onMixerOpenChanged() {
            if (!Globals.mixerOpen)
                statusProc.running = true;
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }
}
