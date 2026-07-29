import Quickshell
import Quickshell.Io
import QtQuick
import "theme.js" as Theme

Rectangle {
    id: root
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 18
    radius: Theme.radius
    color: muted ? Qt.rgba(0.45, 0.2, 0.2, 0.55) : Theme.pillBg()
    border.color: Theme.border
    border.width: 1

    property int pct: 0
    property bool muted: false

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: root.muted ? "󰖁" : "󰕾"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
        }
        Text {
            text: root.pct + "%"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.toggleMixer()
        onWheel: event => {
            if (event.angleDelta.y > 0)
                volUp.running = true;
            else if (event.angleDelta.y < 0)
                volDown.running = true;
        }
    }

    Process {
        id: statusProc
        command: [Globals.buschainWaybar, "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text.trim());
                    let p = parseInt(j.percentage ?? 0, 10);
                    if (isNaN(p))
                        p = 0;
                    root.pct = Math.max(0, Math.min(100, p));
                    root.muted = !!j.muted || j.class === "muted";
                } catch (e) {}
            }
        }
    }

    Process {
        id: volUp
        command: [Globals.buschainWaybar, "up"]
        stdout: StdioCollector { onStreamFinished: statusProc.running = true }
    }

    Process {
        id: volDown
        command: [Globals.buschainWaybar, "down"]
        stdout: StdioCollector { onStreamFinished: statusProc.running = true }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }
}
