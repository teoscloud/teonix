import Quickshell
import Quickshell.Io
import QtQuick
import "theme.js" as Theme
import "components"

Pill {
    id: root
    implicitHeight: Theme.moduleHeight
    implicitWidth: Math.max(row.implicitWidth + 22, 64)
    hovered: ma.containsMouse || Globals.mixerOpen

    property int pct: Globals.hwVolPct
    property bool muted: Globals.hwVolMuted
    property real accum: 0

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: icon
            text: root.muted ? "󰖁" : (root.pct < 34 ? "󰕿" : (root.pct < 67 ? "󰖀" : "󰕾"))
            color: root.muted ? Theme.danger : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
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
                text: root.pct + "%"
                color: root.muted ? Theme.danger : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.toggleMixer()
        onWheel: event => {
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
            let p = parseInt(j.percentage ?? j.hw_volume_pct ?? 0, 10);
            if (isNaN(p))
                p = 0;
            Globals.hwVolPct = Math.max(0, Math.min(100, p));
            Globals.hwVolMuted = !!j.muted || !!j.hw_mute || j.class === "muted";
        } catch (e) {}
    }

    Process {
        id: statusProc
        command: [Globals.buschainWaybar, "status"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyStatus(text)
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
