import QtQuick
import "theme.js" as Theme

Rectangle {
    implicitWidth: 36
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusSm
    color: Globals.powerMenuOpen ? Theme.bgElevated : "transparent"

    Text {
        anchors.centerIn: parent
        text: ""
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.togglePower()
    }
}
