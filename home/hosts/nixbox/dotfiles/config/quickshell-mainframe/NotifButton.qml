import QtQuick
import "components"

Pill {
    id: root
    implicitWidth: Theme.moduleBtnWidth
    implicitHeight: Theme.moduleHeight
    hovered: ma.containsMouse || Globals.notifDrawerOpen

    Text {
        anchors.centerIn: parent
        text: "\uF0F3"
        color: Globals.notifCount > 0 ? Theme.accentHot : Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        font.bold: true
    }

    Rectangle {
        visible: Globals.notifCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 9
        anchors.topMargin: 8
        width: 6
        height: 6
        radius: 0
        color: Theme.danger
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.toggleNotifs()
    }
}
