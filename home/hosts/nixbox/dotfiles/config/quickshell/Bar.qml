import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
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

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                opacity: Theme.barOpacity

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad
                    spacing: Theme.spacing

                    ActiveWindow {
                        Layout.preferredWidth: 260
                        Layout.maximumWidth: 340
                        Layout.fillWidth: false
                    }

                    VolumePill {}

                    Item { Layout.fillWidth: true }

                    WorkspaceBar {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillWidth: true }

                    NotifButton {}
                    PowerButton {}

                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                required property var modelData
                                width: 22
                                height: 22
                                Image {
                                    anchors.fill: parent
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
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

                    ClockWidget {}
                }
            }
        }
    }
}
