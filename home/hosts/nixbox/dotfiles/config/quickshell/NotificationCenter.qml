import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "theme.js" as Theme

Scope {
    NotificationServer {
        id: server
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            Globals.notifCount = server.trackedNotifications.values.length;
        }
    }

    Component.onCompleted: Globals.notifCount = server.trackedNotifications.values.length

    PanelWindow {
        id: toastWin
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        visible: toastCol.children.length > 0 && !Globals.notifDrawerOpen

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + 8
            right: 12
        }

        implicitWidth: 340
        implicitHeight: toastCol.implicitHeight

        Column {
            id: toastCol
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: Math.max(64, bodyCol.implicitHeight + 20)
                    radius: Theme.radiusSm
                    color: Theme.panelBg()
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: bodyCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        Text {
                            text: modelData.summary || "Notification"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.body || ""
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.dismiss)
                                modelData.dismiss();
                        }
                    }

                    Timer {
                        interval: 6000
                        running: true
                        onTriggered: {
                            if (modelData.dismiss)
                                modelData.dismiss();
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: drawer
        visible: Globals.notifDrawerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + 8
            right: 12
        }

        implicitWidth: 360
        implicitHeight: 480

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.panelBg()
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Notifications"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Clear"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const vals = server.trackedNotifications.values;
                                for (let i = vals.length - 1; i >= 0; i--) {
                                    if (vals[i].dismiss)
                                        vals[i].dismiss();
                                }
                            }
                        }
                    }
                    Text {
                        text: "✕"
                        color: Theme.fgMuted
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Globals.notifDrawerOpen = false
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: server.trackedNotifications
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: Math.max(56, dcol.implicitHeight + 16)
                        radius: Theme.radiusSm
                        color: Theme.bgElevated
                        border.color: Theme.border
                        border.width: 1
                        Column {
                            id: dcol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            Text {
                                text: modelData.summary || "Notification"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.body || ""
                                color: Theme.fgMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.dismiss)
                                    modelData.dismiss();
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: server.trackedNotifications.values.length === 0
                        text: "No notifications"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
