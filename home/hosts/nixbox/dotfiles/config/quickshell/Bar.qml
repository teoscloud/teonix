import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "theme.js" as Theme
import "components"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            // Main monitor only — no exclusive zone on other outputs
            visible: Globals.isShellMonitor(modelData)
            exclusiveZone: visible ? Theme.barHeight : 0

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.barHeight
            // Layer-surface alpha enables Hyprland blur (namespace: quickshell)
            color: Theme.barBg()
            WlrLayershell.namespace: "quickshell"
            // barHeight lives in theme.js (.pragma library) — full qs reload applies it

            Rectangle {
                id: barBg
                anchors.fill: parent
                color: "transparent"

                // True screen-center (independent of left/right module widths)
                WorkspaceBar {
                    id: workspaces
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1
                }

                // LEFT — capped so it never eats into the centered strip
                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, workspaces.x - Theme.pad - Theme.spacing)
                    height: Theme.moduleHeight
                    clip: true

                    ActiveWindow {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // RIGHT (before flush clock)
                Row {
                    id: rightRow
                    anchors.right: clock.left
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing
                    z: 1

                    NotifButton {}
                    PowerButton {}

                    Pill {
                        id: trayPill
                        implicitHeight: Theme.moduleHeight
                        implicitWidth: Math.max(trayRow.implicitWidth + 22, 40)
                        hovered: trayMa.containsMouse
                        visible: SystemTray.items.values.length > 0
                            || (SystemTray.items.length !== undefined && SystemTray.items.length > 0)

                        Row {
                            id: trayRow
                            anchors.centerIn: parent
                            spacing: 8
                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    required property var modelData
                                    // Hitbox slightly larger than glyph for easier clicks
                                    width: Theme.trayIcon + 2
                                    height: Theme.moduleHeight
                                    // IconImage + 2× sourceSize = sharp downscale (Waybar-like)
                                    IconImage {
                                        id: trayGlyph
                                        anchors.centerIn: parent
                                        implicitSize: Theme.trayIcon
                                        width: Theme.trayIcon
                                        height: Theme.trayIcon
                                        source: modelData.icon
                                        asynchronous: false
                                        mipmap: false
                                        // Ask SNI/provider for denser pixels, then display smaller
                                        backer.sourceSize.width: Math.round(Theme.trayIcon * Screen.devicePixelRatio * 2)
                                        backer.sourceSize.height: Math.round(Theme.trayIcon * Screen.devicePixelRatio * 2)
                                        backer.smooth: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton)
                                                modelData.activate();
                                            else if (mouse.button === Qt.MiddleButton)
                                                modelData.secondaryActivate();
                                            else if (modelData.hasMenu)
                                                modelData.display(bar, width / 2, height);
                                        }
                                        onWheel: event => {
                                            modelData.scroll(-(event.angleDelta.y), false);
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            z: -1
                        }
                    }
                }

                // Flush top-right — no margin from screen edges
                ClockWidget {
                    id: clock
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    z: 2
                }
            }
        }
    }
}
