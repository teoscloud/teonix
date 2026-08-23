import Quickshell
import Quickshell.Io
import QtQuick
import "theme.js" as Theme

Scope {
    PanelWindow {
        id: powerWin
        visible: Globals.powerMenuOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, 0.55)
        aboveWindows: true

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Globals.powerMenuOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: row.implicitWidth + 48
            height: 132
            radius: Theme.radius
            color: Theme.panelBg()
            border.color: Theme.border
            border.width: 1

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 16

                PowerAction {
                    label: "Lock"
                    icon: ""
                    onActivate: {
                        Globals.powerMenuOpen = false;
                        run.command = ["hyprlock"];
                        run.running = true;
                    }
                }
                PowerAction {
                    label: "Logout"
                    icon: "󰍃"
                    onActivate: {
                        Globals.powerMenuOpen = false;
                        run.command = ["hyprctl", "dispatch", "exit"];
                        run.running = true;
                    }
                }
                PowerAction {
                    label: "Suspend"
                    icon: "󰤄"
                    onActivate: {
                        Globals.powerMenuOpen = false;
                        run.command = ["systemctl", "suspend"];
                        run.running = true;
                    }
                }
                PowerAction {
                    label: "Reboot"
                    icon: "󰜉"
                    danger: true
                    onActivate: {
                        Globals.powerMenuOpen = false;
                        run.command = ["systemctl", "reboot"];
                        run.running = true;
                    }
                }
                PowerAction {
                    label: "Shutdown"
                    icon: ""
                    danger: true
                    onActivate: {
                        Globals.powerMenuOpen = false;
                        run.command = ["systemctl", "poweroff"];
                        run.running = true;
                    }
                }
            }
        }

        Process { id: run }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.powerMenuOpen
            onActivated: Globals.powerMenuOpen = false
        }
    }

    component PowerAction: Column {
        id: act
        signal activate
        property string label: ""
        property string icon: ""
        property bool danger: false
        spacing: 8

        Rectangle {
            width: 68
            height: 68
            radius: Theme.radiusSm
            color: ma.containsMouse ? Theme.bgHover : Theme.bgElevated
            border.color: act.danger && ma.containsMouse ? Theme.danger : Theme.border
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Text {
                anchors.centerIn: parent
                text: act.icon
                color: act.danger ? Theme.danger : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 24
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: act.activate()
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: act.label
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
        }
    }
}
