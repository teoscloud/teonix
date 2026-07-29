import QtQuick
import "theme.js" as Theme

Rectangle {
    id: root
    implicitWidth: 36
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusSm
    color: Globals.notifDrawerOpen ? Theme.bgElevated : "transparent"
    border.color: Globals.notifDrawerOpen ? Theme.border : "transparent"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: ""
        color: Globals.notifCount > 0 ? Theme.accentHot : Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        font.bold: true
    }

    Rectangle {
        visible: Globals.notifCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        anchors.topMargin: 4
        width: 7
        height: 7
        radius: 4
        color: Theme.danger
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Globals.toggleNotifs()
    }
}
