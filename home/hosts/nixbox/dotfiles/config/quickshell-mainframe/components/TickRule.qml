import QtQuick
import qs

// Measurement-rule rice detail: every third tick runs long.
Row {
    id: root

    property int ticks: 5
    property color tickColor: Theme.hatchFg
    property int shortLen: Theme.tickLen
    property int longLen: Theme.tickLen + 3
    property real tickOpacity: 0.8

    spacing: 3
    height: longLen

    Repeater {
        model: root.ticks

        Item {
            required property int index
            width: 1
            height: root.height

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: (parent.index % 3 === 0) ? root.longLen : root.shortLen
                color: root.tickColor
                opacity: root.tickOpacity
            }
        }
    }
}
