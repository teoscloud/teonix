import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

Pill {
    id: root
    implicitHeight: Theme.moduleHeight
    implicitWidth: Math.min(Math.max(label.implicitWidth + 36, 100), 396)
    hovered: ma.containsMouse

    property string title: {
        const t = Hyprland.activeToplevel || Hyprland.focusedToplevel;
        if (!t)
            return " NixOS ";
        const s = t.title || t.lastIpcObject?.title || t.classname || t.lastIpcObject?.class || "";
        if (!s || s.length === 0)
            return " NixOS ";
        return s.length > 30 ? s.slice(0, 28) + "…" : s;
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        elide: Text.ElideRight
        text: root.title
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
        font.bold: true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}

