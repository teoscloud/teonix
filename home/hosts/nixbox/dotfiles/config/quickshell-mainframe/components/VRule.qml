import QtQuick
import qs

// Straight module divider — hairline with short tick caps.
Item {
    id: root

    property color lineColor: Theme.hairline
    property color capColor: Theme.hatchFg
    property int capLen: 5

    implicitWidth: Theme.sepWidth
    implicitHeight: 20

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: root.lineColor
        opacity: 0.7
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.capLen
        height: 1
        color: root.capColor
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.capLen
        height: 1
        color: root.capColor
    }
}
