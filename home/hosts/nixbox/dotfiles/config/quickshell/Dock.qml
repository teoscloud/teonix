import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "theme.js" as Theme

Scope {
    readonly property var pinned: [
        { className: "kitty", label: "kitty", exec: "kitty", icon: "kitty" },
        { className: "brave-browser", label: "brave", exec: "brave", icon: "brave-browser" },
        { className: "code-cursor", label: "cursor", exec: "cursor", icon: "cursor" },
        { className: "spotify", label: "spotify", exec: "spotify", icon: "spotify" },
        { className: "discord", label: "discord", exec: "discord", icon: "discord" },
        { className: "signal", label: "signal", exec: "signal-desktop", icon: "signal-desktop" },
        { className: "org.gnome.Nautilus", label: "files", exec: "nautilus", icon: "org.gnome.Nautilus" },
    ]

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dock
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: Theme.dockHeight
            exclusiveZone: Theme.dockHeight
            color: "transparent"

            property var runningClasses: {
                const out = {};
                const tops = Hyprland.toplevels?.values || [];
                for (let i = 0; i < tops.length; i++) {
                    const c = (tops[i].lastIpcObject?.class || tops[i].classname || "").toLowerCase();
                    if (c)
                        out[c] = (out[c] || 0) + 1;
                }
                return out;
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: row.implicitWidth + 28
                height: Theme.dockHeight - 14
                radius: Theme.radius
                color: Qt.rgba(22 / 255, 24 / 255, 25 / 255, 0.82)
                border.color: Theme.border
                border.width: 1

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: pinned
                        delegate: DockIcon {
                            required property var modelData
                            app: modelData
                            running: {
                                const key = String(modelData.className).toLowerCase();
                                const map = dock.runningClasses;
                                return !!(map[key] || map[key.replace(/-/g, "")]);
                            }
                            onActivate: {
                                const cls = modelData.className;
                                Hyprland.dispatch("focuswindow class:" + cls);
                                launch.command = ["sh", "-c",
                                    "hyprctl clients -j | grep -qi '\"" + cls + "\"' || " + modelData.exec + " >/dev/null 2>&1 &"
                                ];
                                launch.running = true;
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 32
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Repeater {
                        model: {
                            const pinnedKeys = pinned.map(p => String(p.className).toLowerCase());
                            const tops = Hyprland.toplevels?.values || [];
                            const seen = {};
                            const extras = [];
                            for (let i = 0; i < tops.length; i++) {
                                const c = (tops[i].lastIpcObject?.class || tops[i].classname || "");
                                const key = c.toLowerCase();
                                if (!key || pinnedKeys.indexOf(key) >= 0 || seen[key])
                                    continue;
                                // Skip shell chrome
                                if (key.indexOf("quickshell") >= 0)
                                    continue;
                                seen[key] = true;
                                extras.push({
                                    className: c,
                                    label: c.split(".").pop(),
                                    exec: c,
                                    icon: c,
                                    toplevel: tops[i]
                                });
                            }
                            return extras;
                        }
                        delegate: DockIcon {
                            required property var modelData
                            app: modelData
                            running: true
                            onActivate: {
                                if (modelData.toplevel?.activate)
                                    modelData.toplevel.activate();
                                else
                                    Hyprland.dispatch("focuswindow class:" + modelData.className);
                            }
                        }
                    }
                }
            }

            Process { id: launch }
        }
    }

    component DockIcon: Item {
        id: icon
        property var app: ({})
        property bool running: false
        signal activate

        width: 48
        height: 48
        scale: ma.containsMouse ? 1.14 : 1.0

        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: ma.containsMouse ? Theme.bgElevated : "transparent"
            border.color: running ? Theme.accent : "transparent"
            border.width: running ? 1 : 0

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: 34
                height: 34
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                source: {
                    try {
                        return Quickshell.iconPath(app.icon || app.className || "", true);
                    } catch (e) {
                        return "";
                    }
                }
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: String(app.label || "?").slice(0, 2).toUpperCase()
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }
        }

        Rectangle {
            visible: running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 5
            height: 5
            radius: 3
            color: Theme.accentHot
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: icon.activate()
        }
    }
}
