import QtQuick
import "theme.js" as Theme
import "components"

Pill {
    id: root
    implicitWidth: Theme.moduleBtnWidth
    implicitHeight: Theme.moduleHeight
    hovered: ma.containsMouse || Globals.powerMenuOpen

    Text {
        anchors.centerIn: parent
        text: "\uF011"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
        font.bold: true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.togglePower()
    }
}
