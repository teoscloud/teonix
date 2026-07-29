import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

Item {
    id: root
    implicitHeight: Theme.barHeight - 8

    property string title: {
        const t = Hyprland.activeToplevel || Hyprland.focusedToplevel;
        if (!t)
            return "NixOS";
        const s = t.title || t.lastIpcObject?.title || t.classname || t.lastIpcObject?.class || "";
        if (!s || s.length === 0)
            return "NixOS";
        return s.length > 36 ? s.slice(0, 34) + "…" : s;
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: parent.width
        elide: Text.ElideRight
        text: root.title
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
}
