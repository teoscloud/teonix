import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

// Occupied workspaces only (+ focused), scroll with wraparound.
// Visual pill stays original; hitbox uses full bar height for easier scroll.
Item {
    id: root
    implicitHeight: Theme.barHeight
    implicitWidth: pill.width + 16

    property var workspaceIds: {
        const ids = {};
        const list = Hyprland.workspaces.values || [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            const id = ws.id;
            if (!(id > 0))
                continue;
            let n = 0;
            if (ws.lastIpcObject?.windows !== undefined)
                n = Number(ws.lastIpcObject.windows) || 0;
            if (n <= 0) {
                const tops = ws.toplevels;
                if (tops?.values)
                    n = tops.values.length;
                else if (tops?.length !== undefined)
                    n = tops.length;
            }
            if (n > 0)
                ids[id] = true;
        }
        const focused = Hyprland.focusedWorkspace?.id;
        if (focused > 0)
            ids[focused] = true;
        const sorted = Object.keys(ids).map(k => Number(k)).sort((a, b) => a - b);
        return sorted.length ? sorted : [focused > 0 ? focused : 1];
    }

    function switchRelative(delta) {
        const ids = root.workspaceIds;
        if (!ids.length)
            return;
        const cur = Hyprland.focusedWorkspace?.id;
        let idx = ids.indexOf(cur);
        if (idx < 0)
            idx = 0;
        const next = ids[(idx + delta + ids.length * 8) % ids.length];
        Hyprland.dispatch("workspace " + next);
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitHeight: Theme.moduleHeight
        height: Theme.moduleHeight
        width: Math.max(row.implicitWidth + 28, 70)
        radius: Theme.radius
        color: Theme.wsContainerBg()

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.workspaceIds
                delegate: Item {
                    id: ws
                    required property var modelData
                    property int wsId: modelData
                    property var workspace: {
                        const list = Hyprland.workspaces.values || [];
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].id === wsId)
                                return list[i];
                        }
                        return null;
                    }
                    property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                    property bool urgent: !!(workspace?.lastIpcObject?.urgent
                        || workspace?.urgent)

                    width: isActive ? 33 : 24
                    height: 22

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animMed
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.wsBtnBg()
                        opacity: isActive ? 1.0 : 0.55

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animMed }
                        }

                        Text {
                            anchors.centerIn: parent
                            // Nerd Font circle glyphs sit slightly high — nudge down
                            anchors.verticalCenterOffset: 1
                            text: urgent && !isActive ? "\uF05A" : (isActive ? "\uF192" : "\uF111")
                            color: urgent && !isActive ? Theme.accentHot : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            opacity: isActive ? 1.0 : 0.85
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("workspace " + wsId)
                        onWheel: event => {
                            if (event.angleDelta.y > 0)
                                root.switchRelative(1);
                            else if (event.angleDelta.y < 0)
                                root.switchRelative(-1);
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    // Full bar-height wheel target (extends past pill padding)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        z: -1
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.switchRelative(1);
            else if (event.angleDelta.y < 0)
                root.switchRelative(-1);
            event.accepted = true;
        }
    }
}
