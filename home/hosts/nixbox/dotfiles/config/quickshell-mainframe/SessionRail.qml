import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "components"
import "components/appIcons.js" as AppIcons

// Bottom rail — light start | workspace cluster + instances | white tray.
Scope {
    id: root

    property var pinned: []
    property int toplevelEpoch: 0

    readonly property string syncScript: Quickshell.shellPath("scripts/sync-dock-pins.py")
    readonly property string appsPath: `${Quickshell.env("HOME")}/.config/qs-dock-apps.json`

    function refreshToplevelState() {
        try { Hyprland.refreshToplevels() } catch (e) {}
        toplevelEpoch++
        Globals.toplevelEpoch++
    }

    function loadPinned() {
        try {
            const raw = appsFile.text()
            if (!raw || !raw.trim())
                return
            const parsed = JSON.parse(raw)
            if (!Array.isArray(parsed))
                return
            pinned = parsed.map(a => ({
                id: a.id || a.desktopId || "",
                desktopId: a.desktopId || a.id || "",
                className: a.className || a.desktopId || a.id || "",
                label: a.label || a.id || "?",
                exec: a.exec || a.desktopId || a.id || "",
                iconName: a.iconName || a.desktopId || a.id || "",
                iconPath: a.iconPath || ""
            }))
            Globals.pinnedApps = pinned
        } catch (e) {
            console.log("SessionRail: pin parse failed", e)
        }
    }

    function toplevelClass(t) {
        const ipc = t?.lastIpcObject || {}
        return String(ipc.class || ipc.initialClass || t?.classname || "")
    }

    function clientsOnWorkspace(wid) {
        const tops = Hyprland.toplevels?.values || []
        const out = []
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i]
            if (!Globals.isBarToplevel(t))
                continue
            if (Globals.workspaceIdOf(t) === wid)
                out.push(t)
        }
        if (out.length) {
            out.sort((a, b) => Globals.cmpLayout(a, b))
            return out
        }
        const list = Hyprland.workspaces?.values || []
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i].id) !== wid)
                continue
            const nested = list[i].toplevels
            const vals = nested?.values || nested || []
            for (let j = 0; j < vals.length; j++) {
                const t = vals[j]
                if (!Globals.isBarToplevel(t))
                    continue
                out.push(t)
            }
        }
        return out
    }

    function iconSource(appOrClass) {
        return AppIcons.resolve(
            n => Globals.themedIcon(n, Theme.appIconTheme, "app"),
            appOrClass,
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
    }

    // Which cell the marker is on. Set at the moment of the switch — a click,
    // a wheel step, or Hyprland's workspacev2 (emitted when the slide starts) —
    // and kept off the client-list refresh. That refresh returns after the
    // slide and used to rebuild the row, so the marker only started traveling
    // once the switch was already over.
    property int railWorkspace: 0
    property int pendingAim: 0
    property var workspaceIds: []

    function publishWorkspaceIds() {
        const ids = Globals.occupiedWorkspaceIds().slice()
        if (root.railWorkspace > 0 && ids.indexOf(root.railWorkspace) < 0)
            ids.push(root.railWorkspace)
        ids.sort((a, b) => a - b)
        const use = ids.length ? ids : [root.railWorkspace > 0 ? root.railWorkspace : 1]
        const prev = root.workspaceIds || []
        if (prev.length === use.length) {
            let same = true
            for (let i = 0; i < use.length; i++) {
                if (prev[i] !== use[i]) {
                    same = false
                    break
                }
            }
            if (same)
                return
        }
        root.workspaceIds = use
    }

    function aimWorkspace(id, fromEvent) {
        const n = Number(id)
        if (!(n > 0))
            return
        // A fast wheel can request the next cell before the previous event
        // arrives. Drop that stale event so it doesn't pull the marker back.
        if (fromEvent && root.pendingAim > 0 && n !== root.pendingAim)
            return
        if (fromEvent)
            root.pendingAim = 0
        if (n !== root.railWorkspace)
            root.railWorkspace = n
        root.publishWorkspaceIds()
    }

    function switchWorkspace(id) {
        const n = Number(id)
        if (!(n > 0))
            return
        root.pendingAim = n
        aimHold.restart()
        root.aimWorkspace(n, false)
        Globals.switchWorkspace(n)
    }

    function cycleWorkspace(delta) {
        const ids = Globals.occupiedWorkspaceIds()
        if (!ids.length)
            return
        const cur = root.railWorkspace > 0
            ? root.railWorkspace
            : Number(Hyprland.focusedWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1)
        let idx = 0
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === cur) {
                idx = i
                break
            }
        }
        root.switchWorkspace(ids[(idx + delta + ids.length * 8) % ids.length])
    }

    Timer {
        id: aimHold
        interval: 400
        onTriggered: root.pendingAim = 0
    }

    onToplevelEpochChanged: root.publishWorkspaceIds()

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.aimWorkspace(Hyprland.focusedWorkspace?.id, true)
        }
        function onRawEvent(event) {
            const name = event?.name || ""
            if (name === "workspacev2") {
                const parts = event.parse(2)
                root.aimWorkspace(parts[0], true)
                return
            }
            if (name === "focusedmon") {
                const parts = event.parse(2)
                root.aimWorkspace(parts[1], true)
                return
            }
            // Focus itself doesn't move windows. Refreshing clients here comes
            // back after the workspace slide and used to restart the marker.
            if (["openwindow", "closewindow", "movewindow", "movewindowv2"].indexOf(name) >= 0)
                root.refreshToplevelState()
        }
    }

    Component.onCompleted: {
        root.aimWorkspace(Hyprland.focusedWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1, false)
        Qt.callLater(() => root.refreshToplevelState())
    }

    FileView {
        id: appsFile
        path: root.appsPath
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root.loadPinned()
    }

    Process {
        id: syncProc
        running: true
        command: ["python3", root.syncScript]
        onExited: () => {
            appsFile.reload()
            root.loadPinned()
            root.refreshToplevelState()
        }
    }

    Process { id: launchProc }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: rail
            required property var modelData
            screen: modelData
            visible: Globals.isShellMonitor(modelData)
            exclusiveZone: visible ? Theme.railExclusive : 0

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: Theme.railHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell-mainframe:rail"

            Component.onCompleted: Globals.bindShellScreen(modelData)
            onModelDataChanged: Globals.bindShellScreen(modelData)

            Rectangle {
                id: railBody
                anchors.fill: parent
                color: Theme.bg
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.hairline
                opacity: 0.7
            }

            // ── LEFT — start block, wedged into the rail ────────────────────
            Item {
                id: leftZone
                z: 2
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: startWell.width + Theme.wedge + 2 * Theme.pad + 16

                MfShape {
                    anchors.fill: parent
                    kind: "slantRBack"
                    slant: Theme.wedge
                    fillColor: (Globals.startMenuOpen || logoMa.containsMouse)
                        ? Theme.bgSelected : Theme.bgRaised
                    strokeColor: Globals.startMenuOpen ? Theme.accentHot : Theme.hairline
                    strokeWidth: Globals.startMenuOpen ? Theme.strokeActive : Theme.hairlineWidth

                    Behavior on fillColor { ColorAnimation { duration: Theme.animFast } }
                }

                Item {
                    id: startWell
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad + 2
                    width: 50
                    height: parent.height - 2 * Theme.moduleInset

                    MfShape {
                        anchors.fill: parent
                        kind: "oct"
                        slant: Theme.octCut
                        fillColor: {
                            if (Theme.palette === "dark")
                                return (Globals.startMenuOpen || logoMa.containsMouse)
                                    ? Theme.bgSelected : Theme.bg;
                            return (Globals.startMenuOpen || logoMa.containsMouse)
                                ? Theme.trayPlate : Theme.bgRaised;
                        }
                        strokeColor: Globals.startMenuOpen ? Theme.accentHot : Theme.hairline
                        strokeWidth: Globals.startMenuOpen ? Theme.strokeActive : Theme.hairlineWidth

                        Behavior on fillColor { ColorAnimation { duration: Theme.animFast } }
                        Behavior on strokeColor { ColorAnimation { duration: Theme.animFast } }
                    }

                    StartFlake {
                        anchors.centerIn: parent
                        mark: 26
                        ink: Theme.palette === "dark"
                            ? Theme.accentHot
                            : (Globals.startMenuOpen ? Theme.accentHot : Theme.fg)
                        cut: {
                            if (Theme.palette === "dark")
                                return (Globals.startMenuOpen || logoMa.containsMouse)
                                    ? Theme.bgSelected : Theme.bg;
                            return (Globals.startMenuOpen || logoMa.containsMouse)
                                ? Theme.trayPlate : Theme.bgRaised;
                        }
                    }
                }

                MouseArea {
                    id: logoMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor
                    onClicked: Globals.toggleStart()
                }
            }

            // ── CENTER — cluster is centered on the full rail, not the
            // leftover gap between start and tray (those widths differ).
            RailWash {
                z: 0
                anchors.left: leftZone.right
                anchors.right: rightZone.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            MouseArea {
                z: 1
                anchors.left: leftZone.right
                anchors.right: rightZone.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        root.cycleWorkspace(-1)
                    else if (event.angleDelta.y < 0)
                        root.cycleWorkspace(1)
                    event.accepted = true
                }
            }

            Item {
                id: cluster
                z: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: wsRow.implicitWidth + 2 * Theme.pad + Theme.octCut
                property Item selected: null

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animSpring
                                easing.type: Easing.OutCubic
                            }
                        }

                        SelectPill {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: Theme.moduleInset
                            anchors.bottomMargin: Theme.moduleInset
                            targetX: cluster.selected ? wsRow.x + cluster.selected.x : 0
                            targetW: cluster.selected ? cluster.selected.width : 0
                            fillColor: Theme.trayPlate
                            edgeColor: Theme.accentHot
                            ornaments: false
                        }

                        Row {
                            id: wsRow
                            anchors.centerIn: parent
                            height: parent.height
                            spacing: 4

                            Repeater {
                                model: root.workspaceIds

                                delegate: OctPill {
                                    id: wsCell
                                    required property var modelData
                                    required property int index
                                    readonly property int wsId: Number(modelData)
                                    // Clients stay on this binding so a focus change
                                    // doesn't rebuild the cell and postpone the marker.
                                    readonly property var clients: {
                                        void root.toplevelEpoch
                                        return root.clientsOnWorkspace(wsCell.wsId)
                                    }

                                    height: wsRow.height
                                    active: wsCell.wsId === root.railWorkspace
                                    contentW: instRow.implicitWidth
                                    onActivated: root.switchWorkspace(wsCell.wsId)
                                    onWheelUp: root.cycleWorkspace(-1)
                                    onWheelDown: root.cycleWorkspace(1)

                                    function claimSelection() {
                                        if (active)
                                            cluster.selected = wsCell
                                    }

                                    onActiveChanged: claimSelection()
                                    Component.onCompleted: claimSelection()

                                    Row {
                                        id: instRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        MfShape {
                                            visible: !wsCell.clients || wsCell.clients.length === 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: visible ? 9 : 0
                                            height: 9
                                            kind: "oct"
                                            slant: 3
                                            fillColor: wsCell.active ? Theme.accentHot : Theme.fgMuted
                                            strokeColor: "transparent"
                                            strokeWidth: 0
                                        }

                                        Repeater {
                                            model: wsCell.clients

                                            delegate: Item {
                                                required property var modelData
                                                property var client: modelData
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Theme.instanceIcon
                                                height: width

                                                IconImage {
                                                    id: instIcon
                                                    anchors.fill: parent
                                                    asynchronous: true
                                                    mipmap: true
                                                    source: root.iconSource(root.toplevelClass(client))
                                                    readonly property bool ready: status === Image.Ready && !!source
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !instIcon.ready
                                                    text: String(root.toplevelClass(client)).slice(0, 1).toUpperCase()
                                                    color: Theme.fg
                                                    font.pixelSize: Theme.fontSizeMicro
                                                    font.family: Theme.fontFamily
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
            }

            // ── RIGHT — tray cluster, same raised plate as the top-right cap ─
            Item {
                id: rightZone
                z: 2
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: rightRow.implicitWidth + Theme.wedge + 2 * Theme.pad

                MfShape {
                    anchors.fill: parent
                    kind: "slantL"
                    slant: Theme.wedge
                    fillColor: Theme.bgRaised
                    strokeColor: Theme.hairline
                }

                CornerBrackets {
                    anchors.fill: parent
                    markColor: Theme.hatchFg
                    len: 5
                    inset: 3
                    topLeft: false
                }

                PlateDress {
                    anchors.fill: parent
                    clipKind: "slantL"
                    clipSlant: Theme.wedge
                }

                Row {
                    id: rightRow
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad
                    spacing: 0

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            readonly property string iconSource:
                                Globals.trayIconSource(modelData.icon, Theme.iconTheme)

                            width: Theme.trayIcon + 8
                            height: rightRow.height

                            TrayIcon {
                                anchors.centerIn: parent
                                size: Theme.trayIcon
                                source: trayItem.iconSource
                                ink: Theme.palette === "dark" ? Theme.accentHot : Theme.fg
                                // Pixmaps and mid-grey themed names both get measured;
                                // colour marks are left alone, dim mono ones are re-inked.
                                adapt: true
                            }

                            QsMenuAnchor {
                                id: trayMenu
                                menu: trayItem.modelData.menu
                                anchor.window: rail
                                anchor.item: trayItem
                                anchor.edges: Edges.Top
                                anchor.gravity: Edges.Top
                            }

                            function openMenu(mouse) {
                                const item = trayItem.modelData
                                if (item.menu) {
                                    trayMenu.open()
                                    return
                                }
                                if (item.hasMenu) {
                                    const p = mapToItem(railBody, mouse.x, mouse.y)
                                    item.display(rail, Math.round(p.x), Math.round(p.y))
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                onPressed: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        trayItem.openMenu(mouse)
                                        mouse.accepted = true
                                    }
                                }
                                onClicked: mouse => {
                                    const item = trayItem.modelData
                                    if (mouse.button === Qt.RightButton) {
                                        trayItem.openMenu(mouse)
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        item.secondaryActivate()
                                    } else if (item.onlyMenu && item.hasMenu) {
                                        trayItem.openMenu(mouse)
                                    } else {
                                        item.activate()
                                    }
                                }
                                onWheel: event => {
                                    trayItem.modelData.scroll(-event.angleDelta.y, false)
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    VRule {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.sepWidth
                        height: rightRow.height - 2 * Theme.moduleInset
                    }

                    Item {
                        id: volSlot
                        width: volPill.implicitWidth
                        height: rightRow.height

                        VolumePill {
                            id: volPill
                            anchors.centerIn: parent
                        }

                        function reportVol() {
                            const p = volSlot.mapToItem(railBody, 0, 0)
                            Globals.volPillX = Math.round(p.x)
                            Globals.volPillWidth = volSlot.width
                        }

                        onXChanged: reportVol()
                        onWidthChanged: reportVol()
                        Component.onCompleted: reportVol()
                    }

                    VRule {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.sepWidth
                        height: rightRow.height - 2 * Theme.moduleInset
                    }

                    Item {
                        id: ntfSlot
                        // Same footprint empty or unread — badge overlays, never grows the row.
                        width: Theme.moduleBtnWidth
                        height: rightRow.height

                        readonly property bool lit: Globals.notifCount > 0
                        readonly property bool hot: ntfMa.containsMouse || Globals.notifDrawerOpen

                        MfShape {
                            anchors.fill: parent
                            anchors.topMargin: Theme.moduleInset
                            anchors.bottomMargin: Theme.moduleInset
                            kind: "chamfer"
                            slant: Theme.chamfer
                            fillColor: (ntfSlot.hot || ntfSlot.lit) ? Theme.bgSelected : "transparent"
                            strokeColor: ntfSlot.lit ? Theme.accentHot : Theme.hairline

                            Behavior on fillColor { ColorAnimation { duration: Theme.animMed } }
                            Behavior on strokeColor { ColorAnimation { duration: Theme.animMed } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ntfSlot.lit ? "󰂚" : "󰂜"
                            color: (ntfSlot.hot || ntfSlot.lit) ? Theme.fg : Theme.fgMuted
                            font.family: "Symbols Nerd Font Mono, JetBrainsMono Nerd Font, " + Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLg + 2
                        }

                        Item {
                            width: 16
                            height: 16
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 3
                            anchors.topMargin: 5
                            opacity: ntfSlot.lit ? 1 : 0
                            visible: true

                            Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

                            MfShape {
                                anchors.fill: parent
                                kind: "oct"
                                slant: 4
                                fillColor: Theme.accentHot
                                strokeColor: "transparent"
                                strokeWidth: 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Globals.notifCount > 9 ? "9+" : String(Globals.notifCount)
                                color: Theme.bg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBar
                            }
                        }

                        MouseArea {
                            id: ntfMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Globals.toggleNotifs()
                        }
                    }
                }
            }
        }
    }
}
