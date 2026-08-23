import QtQuick
import "../theme.js" as Theme

// Flush top-right corner module (no screen offset)
Pill {
    id: root
    clockCorner: true
    color: Theme.clockBg()
    implicitHeight: Theme.barHeight
    implicitWidth: label.implicitWidth + 24

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.right: parent.right
        anchors.rightMargin: 9
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        font.bold: true
        text: clockText()

        function clockText() {
            return Qt.formatDateTime(new Date(), "ddd MMM dd hh:mm AP");
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: label.text = label.clockText()
        }
    }
}
