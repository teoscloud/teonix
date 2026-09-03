import QtQuick
import qs

// Four L-shaped corner marks — targeting-reticle detail on active modules.
Item {
    id: root

    property color markColor: Theme.accentHot
    property int len: 5
    property int thick: 1
    property real inset: 2
    property bool topLeft: true
    property bool topRight: true
    property bool bottomLeft: true
    property bool bottomRight: true

    Repeater {
        model: [
            { on: root.topLeft,     ox: 0, oy: 0, dx:  1, dy:  1 },
            { on: root.topRight,    ox: 1, oy: 0, dx: -1, dy:  1 },
            { on: root.bottomLeft,  ox: 0, oy: 1, dx:  1, dy: -1 },
            { on: root.bottomRight, ox: 1, oy: 1, dx: -1, dy: -1 }
        ]

        Item {
            required property var modelData
            visible: !!modelData.on
            anchors.fill: parent

            // horizontal leg
            Rectangle {
                color: root.markColor
                width: root.len
                height: root.thick
                x: modelData.ox === 0 ? root.inset : parent.width - root.inset - width
                y: modelData.oy === 0 ? root.inset : parent.height - root.inset - height
            }
            // vertical leg
            Rectangle {
                color: root.markColor
                width: root.thick
                height: root.len
                x: modelData.ox === 0 ? root.inset : parent.width - root.inset - width
                y: modelData.oy === 0 ? root.inset : parent.height - root.inset - height
            }
        }
    }
}
