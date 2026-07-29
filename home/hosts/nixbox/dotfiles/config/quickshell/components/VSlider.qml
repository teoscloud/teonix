import QtQuick
import "../theme.js" as Theme

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    signal moved

    implicitWidth: 22
    implicitHeight: 120

    function setFromPos(y) {
        // top = max, bottom = min (mixer fader)
        const t = 1.0 - Math.max(0, Math.min(1, y / Math.max(1, track.height)));
        const raw = from + t * (to - from);
        const stepped = stepSize > 0 ? Math.round(raw / stepSize) * stepSize : raw;
        value = Math.max(from, Math.min(to, stepped));
        moved();
    }

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        radius: 3
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from))) * parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: 0.85
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: Theme.fg
        border.color: Theme.border
        border.width: 1
        anchors.horizontalCenter: track.horizontalCenter
        y: (1.0 - Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))) * (track.height - height)
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onPressed: root.setFromPos(mouse.y)
        onPositionChanged: if (pressed) root.setFromPos(mouse.y)
    }
}
