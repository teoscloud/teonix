import QtQuick
import qs

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    signal moved

    implicitHeight: 18
    implicitWidth: 120
    // Keep hit-testing inside the slider so mute icons beside it aren't stolen
    clip: false

    function setFromPos(x) {
        const t = Math.max(0, Math.min(1, x / Math.max(1, track.width)));
        const raw = from + t * (to - from);
        const stepped = stepSize > 0 ? Math.round(raw / stepSize) * stepSize : raw;
        value = Math.max(from, Math.min(to, stepped));
        moved();
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 0
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            width: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from))) * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: 0.85
        }
    }

    Rectangle {
        id: handle
        width: 14
        height: 14
        radius: 0
        color: Theme.fg
        border.color: Theme.border
        border.width: 1
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from))) * (track.width - width)

        Behavior on x {
            NumberAnimation { duration: 60 }
        }
    }

    MouseArea {
        anchors.fill: parent
        // Vertical forgiveness only — never spill into neighboring mute/% controls
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            const p = mapToItem(track, mouse.x, mouse.y);
            root.setFromPos(p.x);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(track, mouse.x, mouse.y);
            root.setFromPos(p.x);
        }
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? 1 : -1;
            root.value = Math.max(root.from, Math.min(root.to, root.value + dir * root.stepSize));
            root.moved();
        }
    }
}
