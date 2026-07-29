import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

Rectangle {
    id: root
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 16
    radius: Theme.radius
    color: Theme.pillBg()
    border.color: Theme.border
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: 10
            delegate: Item {
                id: ws
                required property int index
                property int wsId: index + 1
                property var workspace: {
                    const list = Hyprland.workspaces.values;
                    for (let i = 0; i < list.length; i++) {
                        if (list[i].id === wsId)
                            return list[i];
                    }
                    return null;
                }
                property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                property bool exists: workspace !== null

                width: isActive ? 30 : 18
                height: 18
                scale: ma.containsMouse ? 1.08 : 1.0

                Behavior on width {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: isActive ? Theme.bgElevated : (exists ? Theme.bgElevated : "transparent")
                    opacity: isActive ? 1.0 : (exists ? 0.55 : 0.3)
                    border.color: isActive ? Theme.accent : (exists ? Theme.border : "transparent")
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: isActive ? "" : ""
                        color: isActive ? Theme.accentHot : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        opacity: isActive ? 1.0 : (exists ? 0.85 : 0.4)
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y > 0)
                Hyprland.dispatch("workspace e-1");
            else if (event.angleDelta.y < 0)
                Hyprland.dispatch("workspace e+1");
        }
    }
}
