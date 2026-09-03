import QtQuick
import qs

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    // Optional snap target (e.g. 100 UI ≈ 0 dB). NaN = off.
    property real snapAt: Number.NaN
    property real snapEpsilon: 4
    property string valueText: ""
    signal moved

    // Room for floating label beside the knob
    implicitWidth: 44
    implicitHeight: 120

    readonly property real tNorm: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))

    function clamp(raw) {
        const stepped = stepSize > 0 ? Math.round(raw / stepSize) * stepSize : raw;
        return Math.max(from, Math.min(to, stepped));
    }

    function maybeSnap(v) {
        if (!isNaN(snapAt) && Math.abs(v - snapAt) <= snapEpsilon)
            return snapAt;
        return v;
    }

    function setFromPos(y) {
        const t = 1.0 - Math.max(0, Math.min(1, y / Math.max(1, track.height)));
        value = maybeSnap(clamp(from + t * (to - from)));
        moved();
    }

    function nudge(dir) {
        const step = stepSize > 0 ? stepSize : 1;
        const onSnap = !isNaN(snapAt) && Math.abs(value - snapAt) < 0.01;
        let next = clamp(value + dir * step);
        // Leaving 0 dB: do not re-snap back onto the notch
        if (onSnap)
            value = next;
        else
            value = maybeSnap(next);
        moved();
    }

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: valueText.length ? -8 : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        radius: 0
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.tNorm * parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: 0.85
        }

        // Subtle 0 dB / snap tick
        Rectangle {
            visible: !isNaN(root.snapAt)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            height: 2
            radius: 0
            color: Theme.accentHot
            opacity: 0.55
            y: (1.0 - Math.max(0, Math.min(1, (root.snapAt - root.from) / Math.max(0.0001, root.to - root.from)))) * parent.height - 1
        }
    }

    Item {
        id: knob
        width: 14
        height: 14
        anchors.horizontalCenter: track.horizontalCenter
        y: (1.0 - root.tNorm) * (track.height - height)

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: Theme.fg
            border.color: Theme.border
            border.width: 1
        }

        Text {
            visible: root.valueText.length > 0
            anchors.left: parent.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.setFromPos(mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFromPos(mouse.y);
        }
        onWheel: event => {
            // nudge() already applies stepSize once — do not multiply here (was 5×5=25)
            const dir = event.angleDelta.y > 0 ? 1 : -1;
            root.nudge(dir);
            event.accepted = true;
        }
    }
}
