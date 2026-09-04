import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "components"
import "components/appIcons.js" as AppIcons

// Top strip — interlocking angular window tabs, wedged status cluster right.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: strip
            required property var modelData
            screen: modelData
            visible: Globals.isShellMonitor(modelData)
            exclusiveZone: visible ? Theme.barHeight : 0

            // Tab that currently owns the sliding marker
            property Item activeTab: null

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.barHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell-mainframe:top"

            Component.onCompleted: Globals.bindShellScreen(modelData)
            onModelDataChanged: Globals.bindShellScreen(modelData)

            function formatAddress(addr) {
                if (addr === undefined || addr === null || addr === "")
                    return ""
                let s = String(addr).trim()
                if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0)
                    return s
                if (/^[0-9]+$/.test(s))
                    return "0x" + Number(s).toString(16)
                if (/^[0-9a-fA-F]+$/.test(s))
                    return "0x" + s
                return s
            }

            function workspaceIdOf(t) {
                const ipc = t?.lastIpcObject || {}
                const ws = ipc.workspace ?? t?.workspace
                if (ws === undefined || ws === null)
                    return -1
                if (typeof ws === "number")
                    return Number(ws)
                if (typeof ws === "object") {
                    if (ws.id !== undefined && ws.id !== null)
                        return Number(ws.id)
                    if (ws.name !== undefined) {
                        const n = Number(String(ws.name).replace(/[^0-9-]/g, ""))
                        if (n > 0)
                            return n
                    }
                }
                const n = Number(ws)
                return n > 0 ? n : -1
            }

            function toplevelClass(t) {
                const ipc = t?.lastIpcObject || {}
                return String(ipc.class || ipc.initialClass || t?.classname || "")
            }

            function toplevelTitle(t) {
                const ipc = t?.lastIpcObject || {}
                return String(ipc.title || t?.title || toplevelClass(t) || "window")
            }

            function focusToplevel(t) {
                const addr = formatAddress(t.address || t.lastIpcObject?.address)
                if (addr)
                    Globals.dispatchKeepCursor("focuswindow address:" + addr)
            }

            function cycleTab(delta) {
                const tabs = strip.workspaceTabs
                if (!tabs || !tabs.length)
                    return
                const cur = Hyprland.focusedToplevel || Hyprland.activeToplevel
                const activeAddr = formatAddress(cur?.address || cur?.lastIpcObject?.address)
                let idx = 0
                for (let i = 0; i < tabs.length; i++) {
                    const a = formatAddress(tabs[i].address || tabs[i].lastIpcObject?.address)
                    if (a && a === activeAddr) {
                        idx = i
                        break
                    }
                }
                const next = tabs[(idx + delta + tabs.length * 8) % tabs.length]
                focusToplevel(next)
            }

            function iconForClass(cls) {
                return AppIcons.resolve(
                    n => Globals.themedIcon(n, Theme.appIconTheme, "app"),
                    cls,
                    n => Globals.iconReady(n, Theme.appIconTheme, "app")
                )
            }

            function heat(pct) {
                if (pct >= 90)
                    return Theme.danger
                if (pct >= 75)
                    return Theme.accentHot
                return Theme.fg
            }

            component StatCell: Item {
                property string tag: ""
                property string value: ""
                property color valueColor: Theme.fg

                width: statRow.implicitWidth + 10
                height: parent ? parent.height : Theme.barHeight

                Row {
                    id: statRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tag
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMicro
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: value
                        color: valueColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMicro
                    }
                }
            }

            function batHeat(pct) {
                if (pct <= 15)
                    return Theme.danger
                if (pct <= 30)
                    return Theme.accentHot
                return Theme.success
            }

            component BatteryCell: Item {
                id: batRoot
                property int pct: 0
                property bool charging: false
                property bool onMains: false
                property color fillColor: strip.batHeat(pct)

                readonly property int cells: 8
                readonly property int lit: Math.max(0, Math.min(cells, Math.round(pct * cells / 100)))
                readonly property color chrome: charging ? Theme.success : Theme.hairline

                visible: Globals.batPresent
                width: visible ? batRow.implicitWidth + 10 : 0
                height: parent ? parent.height : Theme.barHeight

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 5

                    // Filled + pulse = charging. Hollow = on battery / holding.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7

                        Rectangle {
                            id: chargeMark
                            anchors.centerIn: parent
                            width: 5
                            height: 5
                            rotation: 45
                            color: batRoot.charging ? Theme.success : "transparent"
                            border.width: 1
                            border.color: batRoot.charging ? Theme.success : Theme.fgMuted
                            opacity: batRoot.charging && !Theme.motionOff ? chargePulse.phase : 1

                            SequentialAnimation {
                                id: chargePulse
                                property real phase: 1
                                running: batRoot.charging && !Theme.motionOff
                                loops: Animation.Infinite
                                NumberAnimation {
                                    target: chargePulse
                                    property: "phase"
                                    from: 1
                                    to: 0.3
                                    duration: 700
                                }
                                NumberAnimation {
                                    target: chargePulse
                                    property: "phase"
                                    from: 0.3
                                    to: 1
                                    duration: 700
                                }
                            }
                        }
                    }

                    Item {
                        id: can
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 12

                        Rectangle {
                            id: body
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 12
                            color: "transparent"
                            border.color: batRoot.chrome
                            border.width: 1
                        }

                        Rectangle {
                            anchors.left: body.right
                            anchors.verticalCenter: body.verticalCenter
                            width: 2
                            height: 5
                            color: batRoot.chrome
                        }

                        Row {
                            anchors.centerIn: body
                            spacing: 1

                            Repeater {
                                model: batRoot.cells

                                Rectangle {
                                    required property int index
                                    width: 2
                                    height: 8
                                    color: index < batRoot.lit ? batRoot.fillColor : Theme.hatch
                                    opacity: index < batRoot.lit ? 1 : 0.45
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pct + "%"
                        color: batRoot.charging ? Theme.success : fillColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMicro
                    }
                }
            }

            readonly property int focusedWs: Number(Hyprland.focusedWorkspace?.id
                ?? Hyprland.activeWorkspace?.id ?? 0)

            readonly property int tabCount: workspaceTabs.length

            readonly property real tabSlotWidth: {
                const n = tabCount
                if (n <= 0)
                    return Theme.tabMinWidth
                const gaps = Theme.tabGap * Math.max(0, n - 1)
                const share = Math.floor((tabFlick.width - gaps) / n)
                return Math.min(Theme.tabMaxWidth, Math.max(Theme.tabMinWidth, share))
            }

            readonly property real tabRemnant: Math.max(0, tabFlick.width - tabsRow.implicitWidth)

            readonly property var workspaceTabs: {
                void Globals.toplevelEpoch
                void Globals.layoutEpoch
                const focused = Hyprland.focusedWorkspace?.id
                    ?? Hyprland.activeWorkspace?.id
                    ?? -1
                const tops = Hyprland.toplevels?.values || []
                const list = []
                for (let i = 0; i < tops.length; i++) {
                    const t = tops[i]
                    if (!Globals.isBarToplevel(t))
                        continue
                    if (workspaceIdOf(t) !== focused && focused !== -1)
                        continue
                    list.push(t)
                }
                list.sort((a, b) => Globals.cmpLayout(a, b))
                return list
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
            }

            HatchField {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 4
                opacityMul: 0.3
            }

            EdgeScale {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.tickLen + 3
                edge: "bottom"
                tickOpacity: 0.55
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.hairline
                opacity: 0.7
            }

            // ── LEFT CAP — workspace readout, square end; wheel cycles ──
            Item {
                id: leftCap
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: capRow.implicitWidth + 2 * Theme.pad

                MfShape {
                    anchors.fill: parent
                    kind: "rect"
                    fillColor: Theme.bgRaised
                    strokeColor: Theme.hairline
                }

                PlateDress {
                    anchors.fill: parent
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1
                    color: Theme.hairline
                }

                Row {
                    id: capRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad
                    spacing: 5

                    MfShape {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11
                        height: 11
                        kind: "oct"
                        slant: 3
                        fillColor: Theme.accentHot
                        strokeColor: "transparent"
                        strokeWidth: 0
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WS" + String(strip.focusedWs).padStart(2, "0")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBar
                    }

                    TickRule {
                        anchors.verticalCenter: parent.verticalCenter
                        ticks: 4
                        tickColor: Theme.hatchFg
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor
                    acceptedButtons: Qt.NoButton
                    onWheel: event => {
                        if (event.angleDelta.y > 0)
                            Globals.cycleWorkspace(-1)
                        else if (event.angleDelta.y < 0)
                            Globals.cycleWorkspace(1)
                        event.accepted = true
                    }
                }
            }

            // ── TABS — square, top-left corner sliced ───────────────────────
            Flickable {
                id: tabFlick
                anchors.left: leftCap.right
                anchors.leftMargin: Theme.tabGap
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: rightZone.left
                anchors.rightMargin: Theme.tabGap
                clip: true
                contentWidth: tabsRow.implicitWidth
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onWheel: event => {
                        if (event.angleDelta.y > 0)
                            strip.cycleTab(-1)
                        else if (event.angleDelta.y < 0)
                            strip.cycleTab(1)
                        event.accepted = true
                    }
                }

                Item {
                    visible: strip.tabRemnant > 40 && !tabFlick.interactive
                    x: tabsRow.implicitWidth
                    width: strip.tabRemnant
                    height: tabFlick.height
                    z: 0

                    HatchField {
                        anchors.fill: parent
                        opacityMul: 0.22
                    }
                }

                Row {
                    id: tabsRow
                    height: tabFlick.height
                    spacing: Theme.tabGap
                    z: 1

                    Repeater {
                        model: strip.workspaceTabs

                        delegate: AngularTab {
                            id: tab
                            required property var modelData
                            required property int index

                            height: tabsRow.height
                            slotWidth: strip.tabSlotWidth
                            title: strip.toplevelTitle(modelData)
                            iconPath: strip.iconForClass(strip.toplevelClass(modelData))
                            fallbackGlyph: String(strip.toplevelClass(modelData)).slice(0, 1).toUpperCase()
                            isActive: {
                                const addr = strip.formatAddress(modelData.address || modelData.lastIpcObject?.address)
                                const cur = Hyprland.focusedToplevel || Hyprland.activeToplevel
                                const activeAddr = strip.formatAddress(cur?.address || cur?.lastIpcObject?.address)
                                return !!(addr && activeAddr && addr === activeAddr)
                            }
                            z: isActive ? 500 : (200 - index)
                            onActivated: strip.focusToplevel(modelData)

                            function claimMarker() {
                                if (isActive)
                                    strip.activeTab = tab
                            }

                            onIsActiveChanged: claimMarker()
                            Component.onCompleted: claimMarker()
                        }
                    }
                }

                // One marker for the whole row — it travels to the focused tab
                // instead of each tab lighting its own rail independently.
                Item {
                    id: tabMarker
                    height: 2
                    y: tabFlick.height - height
                    x: strip.activeTab ? tabsRow.x + strip.activeTab.x : 0
                    width: strip.activeTab ? strip.activeTab.width : 0
                    opacity: width > 1 ? 1 : 0
                    visible: opacity > 0.01
                    z: 900

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.motionOff ? 0 : Theme.animSpring
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.6
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionOff ? 0 : Theme.animSpring
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.accentHot
                    }

                    Repeater {
                        model: 2

                        Rectangle {
                            required property int index
                            width: 2
                            height: 5
                            y: -height
                            x: index === 0 ? 0 : tabMarker.width - width
                            color: Theme.accentHot
                        }
                    }
                }
            }

            // ── RIGHT — wedged status cluster ───────────────────────────────
            Item {
                id: rightZone
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
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad
                    height: parent.height
                    spacing: 0

                    Item {
                        width: hostLab.implicitWidth + 10
                        height: parent.height

                        Text {
                            id: hostLab
                            anchors.centerIn: parent
                            text: (Quickshell.env("HOSTNAME") || "nixbox").toUpperCase()
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMicro
                        }
                    }

                    VRule {
                        height: parent.height - 2 * Theme.moduleInset
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.sepWidth
                    }

                    StatCell {
                        tag: "CPU"
                        value: Globals.cpuPct + "%"
                        valueColor: strip.heat(Globals.cpuPct)
                    }

                    StatCell {
                        tag: "RAM"
                        value: Globals.ramPct + "%"
                        valueColor: strip.heat(Globals.ramPct)
                    }

                    VRule {
                        visible: Globals.batPresent
                        height: parent.height - 2 * Theme.moduleInset
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? Theme.sepWidth : 0
                    }

                    BatteryCell {
                        pct: Globals.batPct
                        charging: Globals.batCharging
                        onMains: Globals.batAc
                    }

                    VRule {
                        height: parent.height - 2 * Theme.moduleInset
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.sepWidth
                    }

                    Item {
                        width: clockText.implicitWidth + 16
                        height: parent.height

                        MfShape {
                            anchors.fill: parent
                            anchors.topMargin: Theme.moduleInset
                            anchors.bottomMargin: Theme.moduleInset
                            kind: "chamfer"
                            slant: Theme.chamfer
                            fillColor: Theme.bgSelected
                            strokeColor: Theme.accent
                        }

                        Text {
                            id: clockText
                            anchors.centerIn: parent
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBar
                            text: Qt.formatDateTime(new Date(), "dd MMM HH:mm")

                            Timer {
                                interval: 15000
                                running: true
                                repeat: true
                                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "dd MMM HH:mm")
                            }
                        }
                    }
                }
            }
        }
    }
}
