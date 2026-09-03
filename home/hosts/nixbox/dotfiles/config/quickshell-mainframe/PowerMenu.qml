import Quickshell
import Quickshell.Io
import QtQuick
import "components"

Scope {
    PanelWindow {
        id: powerWin
        visible: Globals.powerMenuOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0.1, 0.1, 0.12, 0.45)
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

        MainframeReveal {
            anchors.centerIn: parent
            width: panel.width
            height: panel.height
            revealed: Globals.powerMenuOpen

            MainframeSurface {
                id: panel
                width: row.implicitWidth + 48
                height: 140
                showHatchTop: true
                showHatchBottom: true
                baseColor: Theme.bgRaised

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 16

                    PowerAction {
                        label: "Lock"
                        icon: "LOCK"
                        onActivate: {
                            Globals.powerMenuOpen = false
                            run.command = ["hyprlock"]
                            run.running = true
                        }
                    }
                    PowerAction {
                        label: "Logout"
                        icon: "EXIT"
                        onActivate: {
                            Globals.powerMenuOpen = false
                            run.command = ["hyprctl", "dispatch", "exit"]
                            run.running = true
                        }
                    }
                    PowerAction {
                        label: "Suspend"
                        icon: "SLEEP"
                        onActivate: {
                            Globals.powerMenuOpen = false
                            run.command = ["systemctl", "suspend"]
                            run.running = true
                        }
                    }
                    PowerAction {
                        label: "Reboot"
                        icon: "REBOOT"
                        danger: true
                        onActivate: {
                            Globals.powerMenuOpen = false
                            run.command = ["systemctl", "reboot"]
                            run.running = true
                        }
                    }
                    PowerAction {
                        label: "Shutdown"
                        icon: "HALT"
                        danger: true
                        onActivate: {
                            Globals.powerMenuOpen = false
                            run.command = ["systemctl", "poweroff"]
                            run.running = true
                        }
                    }
                }
            }
        }

        Process { id: run }

        component PowerAction: Item {
            property string label: ""
            property string icon: ""
            property bool danger: false
            signal activate

            width: 88
            height: 96

            Rectangle {
                anchors.fill: parent
                color: ma.containsMouse ? Theme.bgSelected : "transparent"
                border.color: Theme.hairline
                border.width: 1
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: icon
                    color: danger ? Theme.danger : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: label
                    color: danger ? Theme.danger : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onClicked: activate()
            }
        }
    }
}
