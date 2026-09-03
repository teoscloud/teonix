import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "components"
import "components/appIcons.js" as AppIcons

// Start menu from the Nix logo — pinned apps + power actions
Scope {
    id: root

    function iconSource(app) {
        return AppIcons.resolve(
            n => Globals.themedIcon(n, Theme.appIconTheme, "app"),
            app,
            n => Globals.iconReady(n, Theme.appIconTheme, "app")
        )
    }

    function launchApp(app) {
        const desktopId = app.desktopId || app.id
        const cmd = desktopId
            ? ("gtk-launch " + desktopId + " 2>/dev/null || " + (app.exec || desktopId))
            : (app.exec || "")
        if (!cmd)
            return
        launchProc.command = ["sh", "-c", "(" + cmd + ") >/dev/null 2>&1 &"]
        launchProc.running = true
        Globals.startMenuOpen = false
    }

    function runPower(argv) {
        Globals.startMenuOpen = false
        run.command = argv
        run.running = true
    }

    Process { id: launchProc }
    Process { id: run }

    PanelWindow {
        screen: Globals.shellScreen
        visible: Globals.startMenuOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        WlrLayershell.namespace: "quickshell-mainframe:start"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Globals.startMenuOpen = false
        }

        MainframeReveal {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            // Overlay content is already above the rail exclusive zone;
            // adding railExclusive here floated the menu a whole bar up.
            anchors.bottomMargin: 2
            width: 320
            height: panelCol.implicitHeight + 20
            revealed: Globals.startMenuOpen
            origin: Item.BottomLeft

            MainframeSurface {
                id: panel
                anchors.fill: parent
                baseColor: Theme.bgRaised
                showBorder: false
                showHatchTop: true
                showHatchBottom: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: {}
                }

                Column {
                    id: panelCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "SESSION"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: Globals.pinnedApps
                            delegate: Item {
                                required property var modelData
                                width: 68
                                height: 64

                                Rectangle {
                                    anchors.fill: parent
                                    color: pinMa.containsMouse ? Theme.bgSelected : "transparent"
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 28
                                        height: 28
                                        asynchronous: true
                                        source: root.iconSource(modelData)
                                        visible: status === Image.Ready && !!source
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 64
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(modelData.label || "?").slice(0, 10)
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                                MouseArea {
                                    id: pinMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.launchApp(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        visible: !Globals.pinnedApps || Globals.pinnedApps.length === 0
                        text: "No pinned apps"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Text {
                        text: "PALETTE"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Row {
                        id: themeRow
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Theme.palettes

                            delegate: Item {
                                required property var modelData
                                readonly property bool selected: Theme.palette === modelData.id

                                width: (themeRow.width - themeRow.spacing * Math.max(0, Theme.palettes.length - 1))
                                    / Math.max(1, Theme.palettes.length)
                                height: 36

                                MfShape {
                                    anchors.fill: parent
                                    kind: "oct"
                                    slant: 5
                                    fillColor: selected ? Theme.trayPlate
                                        : (themeMa.containsMouse ? Qt.lighter(Theme.groupWell, 1.08) : Theme.groupWell)
                                    strokeColor: "transparent"
                                    strokeWidth: 0
                                }

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 12
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.short || modelData.label
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: themeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Theme.setPalette(modelData.id)
                                }
                            }
                        }
                    }

                    Text {
                        text: "POWER"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Lock", danger: false, argv: ["hyprlock"] },
                                { label: "Exit", danger: false, argv: ["hyprctl", "dispatch", "exit"] },
                                { label: "Sleep", danger: false, argv: ["systemctl", "suspend"] },
                                { label: "Reboot", danger: true, argv: ["systemctl", "reboot"] },
                                { label: "Halt", danger: true, argv: ["systemctl", "poweroff"] }
                            ]
                            delegate: Item {
                                required property var modelData
                                width: 56
                                height: 36
                                Rectangle {
                                    anchors.fill: parent
                                    color: pma.containsMouse ? Theme.bgSelected : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: modelData.danger ? Theme.danger : Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: pma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.runPower(modelData.argv)
                                }
                            }
                        }
                    }
                }
            }
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.startMenuOpen
            onActivated: Globals.startMenuOpen = false
        }
    }
}
