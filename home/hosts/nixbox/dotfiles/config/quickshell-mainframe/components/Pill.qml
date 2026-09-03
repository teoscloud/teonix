import qs
import QtQuick

// Hover well — oct plate, not a rounded rectangle.
Item {
    id: root
    property bool hovered: false
    property bool clockCorner: false

    MfShape {
        anchors.fill: parent
        kind: "oct"
        slant: Theme.octCut
        fillColor: root.hovered ? Theme.bgSelected : "transparent"
        strokeColor: "transparent"
        strokeWidth: 0

        Behavior on fillColor { ColorAnimation { duration: Theme.animFast } }
    }
}
