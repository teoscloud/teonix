import QtQuick
import qs

// Workspace cell. Selection is drawn by the cluster's shared SelectPill, so a
// cell only owns its content, hover hint and input — keeping every cell the
// same width no matter which one is focused, which is what lets the marker
// travel cleanly instead of chasing a reflowing row.
Item {
    id: root

    property bool active: false
    property bool compact: false
    readonly property bool hovered: ma.containsMouse
    property real contentW: 20

    default property alias content: slot.data

    signal activated()
    signal wheelUp()
    signal wheelDown()

    implicitWidth: compact
        ? Math.max(18, (parent ? parent.height : Theme.barHeight) - 8)
        : contentW + 2 * Theme.pillPadIdle + Theme.octCut
    implicitHeight: parent ? parent.height : Theme.railHeight
    width: implicitWidth

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Easing.OutCubic
        }
    }

    // Gray well behind each cell so it reads as one workspace's group of
    // windows. The focused cell drops it: the shared marker sits underneath and
    // would be painted over.
    MfShape {
        anchors.fill: parent
        anchors.topMargin: Theme.moduleInset
        anchors.bottomMargin: Theme.moduleInset
        kind: "oct"
        slant: root.compact ? Math.min(5, Theme.octCut) : Theme.octCut
        fillColor: root.hovered ? Qt.lighter(Theme.groupWell, 1.06) : Theme.groupWell
        strokeColor: "transparent"
        strokeWidth: 0
        shapeOpacity: root.active ? 0 : 1
        visible: shapeOpacity > 0.01

        Behavior on shapeOpacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on strokeColor { ColorAnimation { duration: Theme.animFast } }
    }

    Item {
        id: slot
        anchors.centerIn: parent
        width: root.contentW
        height: parent.height
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: 5
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: root.activated()
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.wheelUp()
            else if (event.angleDelta.y < 0)
                root.wheelDown()
            event.accepted = true
        }
    }
}
