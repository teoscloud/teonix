import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "theme.js" as Theme
import "components"

// Bottom dock — pins from ~/.config/qs-dock-pinned (synced → qs-dock-apps.json).
Scope {
    id: root

    property var pinned: []
    // Bumped after Hyprland.refreshToplevels so DockIcon/extras rebind
    property int toplevelEpoch: 0

    readonly property string syncScript: Quickshell.shellPath("scripts/sync-dock-pins.py")
    readonly property string appsPath: `${Quickshell.env("HOME")}/.config/qs-dock-apps.json`

    // Known StartupWMClass / Hyprland class mismatches
    readonly property var classAliases: ({
        "cursor": ["code-cursor", "cursor"],
        "code-cursor": ["cursor", "code-cursor"],
        "brave-browser": ["brave-browser", "brave"],
        "brave": ["brave-browser", "brave"],
        "google-chrome": ["google-chrome", "chrome", "google-chrome-stable"],
        "google-chrome-stable": ["google-chrome", "chrome"],
        "chrome": ["google-chrome", "chrome"],
        "mailspring": ["mailspring"],
        "chromium": ["chromium", "chromium-browser"],
        "chromium-browser": ["chromium", "chromium-browser"]
    })

    function loadPinned() {
        try {
            const raw = appsFile.text();
            if (!raw || !raw.trim())
                return;
            const parsed = JSON.parse(raw);
            if (!Array.isArray(parsed))
                return;
            pinned = parsed.map(a => ({
                id: a.id || a.desktopId || "",
                desktopId: a.desktopId || a.id || "",
                className: a.className || a.desktopId || a.id || "",
                label: a.label || a.id || "?",
                exec: a.exec || a.desktopId || a.id || "",
                iconName: a.iconName || a.desktopId || a.id || "",
                iconPath: a.iconPath || ""
            }));
        } catch (e) {
            console.log("Dock: failed to parse qs-dock-apps.json:", e);
        }
    }

    function normalizeKey(v) {
        let s = String(v || "").toLowerCase().trim();
        if (!s)
            return "";
        if (s.endsWith(".desktop"))
            s = s.slice(0, -8);
        s = s.replace(/\s+/g, "").replace(/_/g, "-");
        return s;
    }

    function pushKey(keys, v) {
        const s = root.normalizeKey(v);
        if (!s)
            return;
        if (keys.indexOf(s) < 0)
            keys.push(s);
        const noHyphen = s.replace(/-/g, "");
        if (noHyphen && keys.indexOf(noHyphen) < 0)
            keys.push(noHyphen);
        const aliases = root.classAliases[s];
        if (aliases) {
            for (let i = 0; i < aliases.length; i++) {
                const a = root.normalizeKey(aliases[i]);
                if (a && keys.indexOf(a) < 0)
                    keys.push(a);
                const ah = a.replace(/-/g, "");
                if (ah && keys.indexOf(ah) < 0)
                    keys.push(ah);
            }
        }
    }

    function matchKeys(app) {
        const keys = [];
        // Do not use iconName — shared theme names cause false merges
        root.pushKey(keys, app.className);
        root.pushKey(keys, app.desktopId);
        root.pushKey(keys, app.id);
        return keys;
    }

    function toplevelClass(t) {
        const ipc = t?.lastIpcObject || {};
        const raw = ipc.class || ipc.initialClass || t?.classname || t?.class || "";
        return String(raw || "");
    }

    function toplevelClassKey(t) {
        return root.normalizeKey(root.toplevelClass(t));
    }

    function classMatchesKeys(c, keys) {
        const n = root.normalizeKey(c);
        if (!n)
            return false;
        if (keys.indexOf(n) >= 0 || keys.indexOf(n.replace(/-/g, "")) >= 0)
            return true;
        const aliases = root.classAliases[n];
        if (aliases) {
            for (let i = 0; i < aliases.length; i++) {
                const a = root.normalizeKey(aliases[i]);
                if (a && (keys.indexOf(a) >= 0 || keys.indexOf(a.replace(/-/g, "")) >= 0))
                    return true;
            }
        }
        return false;
    }

    function launchCmdFor(app) {
        const desktopId = app.desktopId || app.id;
        if (desktopId)
            return "gtk-launch " + desktopId + " 2>/dev/null || " + (app.exec || desktopId);
        return app.exec || "";
    }

    function workspaceIdOf(t) {
        const ws = t?.lastIpcObject?.workspace ?? t?.workspace;
        if (ws === undefined || ws === null)
            return 99999;
        if (typeof ws === "number")
            return ws;
        if (typeof ws === "object" && ws.id !== undefined)
            return Number(ws.id) || 99999;
        return Number(ws) || 99999;
    }

    function posOf(t) {
        const at = t?.lastIpcObject?.at;
        if (Array.isArray(at) && at.length >= 1)
            return { x: Number(at[0]) || 0, y: Number(at[1]) || 0 };
        return { x: 0, y: 0 };
    }

    // Match app windows, ordered: workspace asc → leftmost → topmost → address
    function toplevelsFor(app) {
        const keys = root.matchKeys(app);
        const tops = Hyprland.toplevels?.values || [];
        const out = [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const c = root.toplevelClass(t);
            if (!c)
                continue;
            if (!Globals.isBarToplevel(t))
                continue;
            if (root.classMatchesKeys(c, keys))
                out.push(t);
        }
        out.sort((a, b) => {
            const wa = root.workspaceIdOf(a);
            const wb = root.workspaceIdOf(b);
            if (wa !== wb)
                return wa - wb;
            const pa = root.posOf(a);
            const pb = root.posOf(b);
            if (pa.x !== pb.x)
                return pa.x - pb.x;
            if (pa.y !== pb.y)
                return pa.y - pb.y;
            const aa = root.formatAddress(a.address || a.lastIpcObject?.address);
            const ab = root.formatAddress(b.address || b.lastIpcObject?.address);
            return aa < ab ? -1 : (aa > ab ? 1 : 0);
        });
        return out;
    }

    function refreshToplevelState() {
        try {
            Hyprland.refreshToplevels();
        } catch (e) {
            // older QS builds may lack refreshToplevels
        }
        root.toplevelEpoch++;
    }

    function resolveExtraIcon(className) {
        const c = String(className || "");
        const stem = c.split(".").pop() || c;
        const candidates = [c, stem, root.normalizeKey(c), root.normalizeKey(stem)];
        const aliases = root.classAliases[root.normalizeKey(c)];
        if (aliases) {
            for (let i = 0; i < aliases.length; i++)
                candidates.push(aliases[i]);
        }
        for (let i = 0; i < candidates.length; i++) {
            const name = candidates[i];
            if (!name)
                continue;
            try {
                const path = Quickshell.iconPath(name, true);
                if (path)
                    return { iconName: name, iconPath: "" };
            } catch (e) {
            }
        }
        return { iconName: stem || c, iconPath: "" };
    }

    // Hyprland wants address:0x.... — QS often hands bare hex / decimal
    function formatAddress(addr) {
        if (addr === undefined || addr === null || addr === "")
            return "";
        let s = String(addr).trim();
        if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0)
            return s;
        if (/^[0-9]+$/.test(s))
            return "0x" + Number(s).toString(16);
        if (/^[0-9a-fA-F]+$/.test(s))
            return "0x" + s;
        return s;
    }

    // keepCursor: restore pointer after focus so dock scroll doesn't warp into the window
    function activateToplevel(t, keepCursor) {
        if (!t)
            return;
        const addr = root.formatAddress(t.address || t.lastIpcObject?.address);
        const cls = root.toplevelClass(t);
        const focusCmd = addr
            ? ("hyprctl dispatch focuswindow address:" + addr)
            : (cls ? ("hyprctl dispatch focuswindow class:" + cls) : "");
        if (!focusCmd)
            return;

        if (keepCursor) {
            focusKeepCursor.command = ["sh", "-c",
                'pos=$(hyprctl cursorpos); ' +
                'x=${pos%%,*}; y=${pos#*,}; y=${y// /}; ' +
                focusCmd + '; ' +
                'hyprctl dispatch movecursor "$x" "$y"'
            ];
            focusKeepCursor.running = true;
            return;
        }

        if (addr)
            Hyprland.dispatch("focuswindow address:" + addr);
        else if (cls)
            Hyprland.dispatch("focuswindow class:" + cls);
    }

    function closeToplevels(list) {
        for (let i = 0; i < list.length; i++) {
            const addr = root.formatAddress(list[i].address || list[i].lastIpcObject?.address);
            if (addr)
                Hyprland.dispatch("closewindow address:" + addr);
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event?.name || "";
            if (["openwindow", "closewindow", "windowtitlev2", "activewindowv2", "movewindow", "movewindowv2"].indexOf(name) >= 0)
                root.refreshToplevelState();
        }
    }

    Component.onCompleted: Qt.callLater(() => root.refreshToplevelState())

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
        onExited: code => {
            appsFile.reload();
            root.loadPinned();
            root.refreshToplevelState();
        }
    }

    Process { id: focusKeepCursor }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dock
            required property var modelData
            screen: modelData
            // Main monitor only — no exclusive zone on other outputs
            visible: Globals.isShellMonitor(modelData)
            exclusiveZone: visible ? Theme.dockExclusive : 0

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: Theme.dockWindowHeight
            // Frost color on the layer surface; mask clips blur to the pill
            color: Theme.dockBg()
            WlrLayershell.namespace: "quickshell:dock"

            HyprlandWindow.visibleMask: Region {
                item: dockPill
                radius: 17
            }

            function isRunning(app) {
                void root.toplevelEpoch;
                return root.toplevelsFor(app).length > 0;
            }

            function activateApp(app) {
                void root.toplevelEpoch;
                const list = root.toplevelsFor(app);
                if (list.length === 0) {
                    dock.launchApp(app);
                    return;
                }
                let idx = -1;
                for (let i = 0; i < list.length; i++) {
                    if (list[i].activated) {
                        idx = i;
                        break;
                    }
                }
                // Already focused → cycle; otherwise focus first match
                if (idx >= 0 && list.length > 1)
                    root.activateToplevel(list[(idx + 1) % list.length]);
                else
                    root.activateToplevel(list[idx >= 0 ? idx : 0]);
            }

            function launchApp(app) {
                const cmd = root.launchCmdFor(app);
                if (!cmd)
                    return;
                launch.command = ["sh", "-c", "(" + cmd + ") >/dev/null 2>&1 &"];
                launch.running = true;
            }

            Rectangle {
                id: dockPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dockMarginBottom
                width: row.implicitWidth + 24
                height: Theme.dockPillHeight
                radius: 17
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                Row {
                    id: row
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    spacing: 4

                    Repeater {
                        model: root.pinned
                        delegate: DockIcon {
                            required property var modelData
                            app: modelData
                            onActivate: dock.activateApp(modelData)
                            onLaunchNew: dock.launchApp(modelData)
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 36
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                        visible: extrasRepeater.count > 0
                    }

                    Repeater {
                        id: extrasRepeater
                        model: {
                            void root.toplevelEpoch;
                            const pinnedKeys = [];
                            for (let i = 0; i < root.pinned.length; i++) {
                                const keys = root.matchKeys(root.pinned[i]);
                                for (let j = 0; j < keys.length; j++)
                                    pinnedKeys.push(keys[j]);
                            }
                            const tops = Hyprland.toplevels?.values || [];
                            const seen = {};
                            const extras = [];
                            for (let i = 0; i < tops.length; i++) {
                                const c = root.toplevelClass(tops[i]);
                                const key = root.normalizeKey(c);
                                if (!key || seen[key])
                                    continue;
                                if (!Globals.isBarToplevel(tops[i]))
                                    continue;
                                if (root.classMatchesKeys(c, pinnedKeys))
                                    continue;
                                seen[key] = true;
                                const icons = root.resolveExtraIcon(c);
                                extras.push({
                                    className: c,
                                    label: c.split(".").pop(),
                                    exec: c,
                                    iconName: icons.iconName,
                                    iconPath: icons.iconPath,
                                    toplevel: tops[i]
                                });
                            }
                            return extras;
                        }
                        delegate: DockIcon {
                            required property var modelData
                            app: modelData
                            onActivate: dock.activateApp(modelData)
                            onLaunchNew: dock.launchApp(modelData)
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
        signal activate
        signal launchNew

        width: Theme.dockIcon + 6
        height: Theme.dockIcon + 6

        property var instances: {
            void root.toplevelEpoch;
            return root.toplevelsFor(app);
        }
        property int instanceCount: instances.length
        property int cycleIndex: 0

        readonly property string resolvedSource: {
            const path = app.iconPath || "";
            if (path && path.charAt(0) === "/")
                return "file://" + path;
            const name = app.iconName || app.className || "";
            if (!name)
                return "";
            try {
                return Quickshell.iconPath(name, true) || "";
            } catch (e) {
                return "";
            }
        }

        function cycleInstances(delta) {
            const list = icon.instances;
            if (!list.length)
                return;
            // Prefer advancing from currently focused instance
            let idx = 0;
            for (let i = 0; i < list.length; i++) {
                if (list[i].activated) {
                    idx = i;
                    break;
                }
            }
            idx = (idx + delta + list.length * 8) % list.length;
            icon.cycleIndex = idx;
            // Keep pointer on the dock while scrolling through instances
            root.activateToplevel(list[idx], true);
        }

        function closeAll() {
            root.closeToplevels(icon.instances);
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                implicitSize: Theme.dockIcon - 8
                width: Theme.dockIcon - 8
                height: Theme.dockIcon - 8
                asynchronous: true
                mipmap: true
                source: icon.resolvedSource
                visible: status === Image.Ready && !!source
            }

            Image {
                id: appIconFallback
                anchors.centerIn: parent
                width: Theme.dockIcon - 8
                height: Theme.dockIcon - 8
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                source: icon.resolvedSource
                visible: !appIcon.visible && status === Image.Ready && !!source
            }

            Text {
                anchors.centerIn: parent
                visible: !appIcon.visible && !appIconFallback.visible
                text: String(app.label || "?").slice(0, 2).toUpperCase()
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
            }
        }

        // Instance dots (up to 4)
        Row {
            visible: icon.instanceCount > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            spacing: 3

            Repeater {
                model: Math.min(icon.instanceCount, 4)
                delegate: Rectangle {
                    required property int index
                    width: icon.instanceCount > 3 ? 4 : 5
                    height: 4
                    radius: 2
                    color: Theme.accent
                    opacity: 0.85
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    icon.launchNew();
                else if (mouse.button === Qt.RightButton)
                    ctxMenu.popup(ma, mouse.x, mouse.y);
                else
                    icon.activate();
            }
            onWheel: event => {
                // Spatial: wheel up → right (+1 in left→right list), down → left
                if (icon.instanceCount > 0) {
                    if (event.angleDelta.y > 0)
                        icon.cycleInstances(1);
                    else if (event.angleDelta.y < 0)
                        icon.cycleInstances(-1);
                    event.accepted = true;
                }
            }
        }

        Menu {
            id: ctxMenu
            MenuItem {
                text: icon.instanceCount > 0 ? "Focus" : "Open"
                onTriggered: icon.activate()
            }
            MenuItem {
                text: "New window"
                onTriggered: icon.launchNew()
            }
            MenuSeparator {
                visible: icon.instanceCount > 0
            }
            MenuItem {
                text: icon.instanceCount > 1 ? "Close all windows" : "Close"
                visible: icon.instanceCount > 0
                onTriggered: icon.closeAll()
            }
        }
    }
}
