import Quickshell
import Quickshell.Widgets
import QtQuick
import qs

// One dock slot: oct well, icon, instance dots. Selection is the cluster's
// shared SelectPill so a focus change reads as travel, not two fades.
Item {
    id: root

    property var app: ({})
    property var railRoot: null
    property Item cluster: null
    property Item rail: null

    readonly property var instances: {
        void Globals.toplevelEpoch
        if (root.railRoot)
            void root.railRoot.toplevelEpoch
        return root.railRoot ? root.railRoot.toplevelsFor(root.app) : []
    }
    readonly property int instanceCount: instances.length
    readonly property bool running: instanceCount > 0
    readonly property bool isFocused: {
        void Globals.toplevelEpoch
        if (root.railRoot)
            void root.railRoot.toplevelEpoch
        const list = root.instances
        if (!root.railRoot || !list.length)
            return false
        for (let i = 0; i < list.length; i++) {
            if (root.railRoot.isActivated(list[i]))
                return true
        }
        return false
    }

    // Oct cuts eat `wellCut` on each side — the cell has to be wider than
    // the glyph or the focused well clips the icon against the slants.
    readonly property int wellCut: 5
    readonly property int glyph: 20
    readonly property int dotBand: 8
    readonly property real wellY: 3
    readonly property real wellH: Math.max(glyph + 2 * wellCut, height - wellY - dotBand)

    width: glyph + 2 * wellCut + 12
    height: parent ? parent.height : Theme.railHeight

    function claimSelection() {
        if (root.isFocused && root.cluster)
            root.cluster.selected = root
    }

    onIsFocusedChanged: claimSelection()
    Component.onCompleted: claimSelection()

    function openMenu(mouse) {
        if (!root.railRoot || !root.rail)
            return
        const count = root.instanceCount
        const app = root.app
        const p = mapToItem(root.rail, mouse.x, mouse.y)
        const scr = root.rail.screen
        const y = (scr ? scr.height : 1080) - root.rail.height + p.y
        Globals.openCtxMenu([
            {
                label: count > 0 ? "Focus" : "Open",
                action: () => root.railRoot.activateApp(app)
            },
            {
                label: "New window",
                action: () => root.railRoot.launchApp(app)
            },
            {
                label: count > 1 ? "Close all windows" : "Close",
                visible: count > 0,
                danger: true,
                action: () => root.railRoot.closeAppWindows(app)
            }
        ], p.x, y)
    }

    MfShape {
        x: 0
        y: root.wellY
        width: parent.width
        height: root.wellH
        kind: "oct"
        slant: root.wellCut
        fillColor: root.running
            ? (ma.containsMouse ? Theme.bgSelected : Theme.groupWell)
            : (ma.containsMouse ? Theme.hatch : "transparent")
        strokeColor: "transparent"
        strokeWidth: 0
        shapeOpacity: root.isFocused ? 0 : 1
        visible: shapeOpacity > 0.01

        Behavior on shapeOpacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on fillColor { ColorAnimation { duration: Theme.animFast } }
    }

    Item {
        x: 0
        y: root.wellY
        width: parent.width
        height: root.wellH

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            width: root.glyph
            height: root.glyph
            asynchronous: true
            mipmap: true
            source: root.railRoot ? root.railRoot.iconSource(root.app) : ""
            visible: status === Image.Ready && !!source
        }

        Text {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: String(root.app.label || root.app.className || "?").slice(0, 2).toUpperCase()
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMicro
            font.bold: true
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        visible: root.instanceCount > 0
        spacing: 3
        height: 4

        Repeater {
            model: Math.min(root.instanceCount, 4)
            delegate: Rectangle {
                required property int index
                width: root.instanceCount > 3 ? 4 : 5
                height: 4
                color: root.isFocused ? Theme.accentHot : Theme.accent
                opacity: 0.9
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.ArrowCursor
        onClicked: mouse => {
            if (!root.railRoot)
                return
            if (mouse.button === Qt.MiddleButton)
                root.railRoot.launchApp(root.app)
            else if (mouse.button === Qt.RightButton)
                root.openMenu(mouse)
            else
                root.railRoot.activateApp(root.app)
        }
        onWheel: event => {
            if (!root.railRoot || root.instanceCount <= 0) {
                event.accepted = true
                return
            }
            if (event.angleDelta.y > 0)
                root.railRoot.cycleInstances(root.app, 1)
            else if (event.angleDelta.y < 0)
                root.railRoot.cycleInstances(root.app, -1)
            event.accepted = true
        }
    }
}
