import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "components/appIcons.js" as AppIcons

Scope {
    id: root

    readonly property color colFg: Theme.fg
    readonly property color colMuted: Theme.fgMuted
    readonly property color colPanel: Theme.bgRaised
    readonly property color colBorder: Theme.hairline
    readonly property color colText: Theme.fg
    readonly property color colAccent: Theme.accentHot
    readonly property color colRow: Theme.bg
    readonly property color colRowHover: Theme.bgSelected

    property string query: ""
    property int selected: 0
    property string mathResult: ""
    property string mathExpr: ""
    property bool mathPending: false
    property string pendingInsert: ""
    property var appRecents: []

    readonly property string appRecentsPath: `${Quickshell.env("HOME")}/.config/qs-launcher-recents.json`

    // Reactive results — ScriptModel re-runs when DesktopEntries / query / math / recents change
    ScriptModel {
        id: resultModel
        values: {
            const q = root.query.trim();
            const qLower = q.toLowerCase();
            const out = [];
            const recentIds = root.appRecents || [];

            // Touch math props so calc rows stay reactive
            const mathRes = root.mathResult;
            const mathPending = root.mathPending;

            if (root.looksLikeMath(q)) {
                const expr = q.endsWith("=") ? q.slice(0, -1).trim() : q;
                out.push({
                    kind: "math",
                    title: mathRes !== "" ? ("= " + mathRes) : (mathPending ? "Calculating…" : "= ?"),
                    subtitle: expr,
                    result: mathRes,
                    entry: null
                });
                out.push({
                    kind: "calc",
                    title: "Open Calculator",
                    subtitle: mathRes !== "" ? (expr + " = " + mathRes) : expr,
                    result: mathRes,
                    entry: null
                });
            }

            // Proven Quickshell pattern: spread ObjectModel.values into a real array
            const apps = [...DesktopEntries.applications.values];
            const byId = {};
            for (let i = 0; i < apps.length; i++) {
                const e = apps[i];
                if (e && e.id)
                    byId[e.id] = e;
            }

            const used = {};
            const list = [];

            // Empty query: surface recent apps first (preserve recency order)
            if (!qLower) {
                for (let r = 0; r < recentIds.length; r++) {
                    const id = recentIds[r];
                    const e = byId[id];
                    if (!e || used[id])
                        continue;
                    used[id] = true;
                    list.push({
                        kind: "app",
                        title: e.name || e.id || "App",
                        subtitle: "Recent",
                        entry: e,
                        result: "",
                        _rank: -1000 + r,
                        _name: (e.name || "").toLowerCase()
                    });
                }
            }

            for (let i = 0; i < apps.length; i++) {
                const e = apps[i];
                if (!e)
                    continue;
                const id = e.id || "";
                if (used[id])
                    continue;
                // DesktopEntries.applications already excludes NoDisplay/Hidden
                const name = e.name || "";
                const gen = e.genericName || "";
                const comment = e.comment || "";
                const exec = e.execString || "";
                let keys = "";
                try {
                    const kw = e.keywords || [];
                    keys = (kw && kw.join) ? kw.join(" ") : String(kw || "");
                } catch (err) {
                    keys = "";
                }
                const hay = (name + " " + gen + " " + comment + " " + exec + " " + keys).toLowerCase();
                if (qLower && hay.indexOf(qLower) < 0)
                    continue;
                const recentBoost = 0;
                const prefix = qLower && name.toLowerCase().indexOf(qLower) === 0 ? 0 : 1;
                list.push({
                    kind: "app",
                    title: name || id || "App",
                    subtitle: comment || gen || exec,
                    entry: e,
                    result: "",
                    _rank: recentBoost + prefix,
                    _name: name.toLowerCase()
                });
                if (id)
                    used[id] = true;
            }
            list.sort((a, b) => {
                if (a._rank !== b._rank)
                    return a._rank - b._rank;
                return a._name < b._name ? -1 : (a._name > b._name ? 1 : 0);
            });
            const limit = out.length ? 6 : 8;
            for (let i = 0; i < Math.min(limit, list.length); i++)
                out.push(list[i]);

            return out;
        }
    }

    readonly property var results: resultModel.values
    readonly property int resultCount: resultModel.values.length

    function looksLikeMath(s) {
        const t = String(s || "").trim();
        if (!t)
            return false;
        // strip trailing =
        const body = t.endsWith("=") ? t.slice(0, -1).trim() : t;
        if (!body)
            return false;
        if (!/[0-9]/.test(body))
            return false;
        if (!/[+\-*/^%()]/.test(body))
            return false;
        // allow simple function names, reject long alpha words (app names)
        const cleaned = body.replace(/\b(sin|cos|tan|log|ln|sqrt|abs|pi|e)\b/gi, "");
        if (/[a-zA-Z]{3,}/.test(cleaned))
            return false;
        return true;
    }

    function simpleEval(expr) {
        // Lightweight fallback when qalc is unavailable (basic arithmetic only)
        try {
            let e = String(expr).trim();
            if (e.endsWith("="))
                e = e.slice(0, -1).trim();
            e = e.replace(/\s+/g, "");
            e = e.replace(/\^/g, "**");
            if (!/^[\d.+\-*/%()]+$/.test(e))
                return "";
            // Parse via iterative reduce for + - then * / %
            // Digits and operators only (already validated)
            const v = eval(e);
            if (typeof v !== "number" || !isFinite(v))
                return "";
            const r = Math.round(v * 1e10) / 1e10;
            return String(r);
        } catch (err) {
            return "";
        }
    }

    function clampSelected() {
        if (root.selected >= root.resultCount)
            root.selected = Math.max(0, root.resultCount - 1);
    }

    function runQalc() {
        if (!root.looksLikeMath(root.query)) {
            root.mathResult = "";
            root.mathExpr = "";
            root.mathPending = false;
            return;
        }
        const expr = root.query.trim().endsWith("=")
            ? root.query.trim().slice(0, -1).trim()
            : root.query.trim();
        root.mathExpr = expr;
        root.mathPending = true;
        // Prefer qalc; fall back to simple JS
        qalcProc.command = ["qalc", "-t", "--", expr];
        qalcProc.running = false;
        qalcProc.running = true;
        // optimistic local fallback while waiting
        const local = root.simpleEval(expr);
        if (local)
            root.mathResult = local;
    }

    function insertText(text) {
        if (!text)
            return;
        root.pendingInsert = text;
        insertDelay.restart();
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function loadAppRecents() {
        try {
            const raw = appRecentsFile.text();
            if (!raw || !raw.trim()) {
                root.appRecents = [];
                root.saveAppRecents();
                return;
            }
            const parsed = JSON.parse(raw);
            root.appRecents = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            root.appRecents = [];
            root.saveAppRecents();
        }
    }

    function saveAppRecents() {
        try {
            appRecentsFile.setText(JSON.stringify(root.appRecents));
        } catch (e) {
            console.log("Launcher: failed to save app recents", e);
        }
    }

    function pushAppRecent(entry) {
        if (!entry)
            return;
        const id = entry.id || "";
        if (!id)
            return;
        const next = [id];
        for (let i = 0; i < root.appRecents.length; i++) {
            if (root.appRecents[i] !== id)
                next.push(root.appRecents[i]);
            if (next.length >= 24)
                break;
        }
        root.appRecents = next;
        root.saveAppRecents();
    }

    function activateSelected() {
        const item = root.results[root.selected];
        if (!item)
            return;
        if (item.kind === "math") {
            const r = item.result || root.mathResult;
            Globals.closeLauncher();
            root.insertText(r);
            return;
        }
        if (item.kind === "calc") {
            const payload = root.mathResult
                ? (root.mathExpr + " = " + root.mathResult)
                : root.mathExpr;
            calcProc.command = ["sh", "-c",
                "printf %s " + shellQuote(payload) + " | wl-copy; gnome-calculator >/dev/null 2>&1 &"
            ];
            calcProc.running = true;
            Globals.closeLauncher();
            return;
        }
        if (item.kind === "app" && item.entry) {
            root.pushAppRecent(item.entry);
            item.entry.execute();
            Globals.closeLauncher();
        }
    }

    function iconSource(entry) {
        if (!entry)
            return "";
        const icon = entry.icon || "";
        if (!icon)
            return "";
        if (icon.charAt(0) === "/" || icon.indexOf("://") >= 0)
            return icon.charAt(0) === "/" ? ("file://" + icon) : icon;
        return Globals.themedIcon(icon, Theme.appIconTheme, "app")
            || AppIcons.resolve(
                n => Globals.themedIcon(n, Theme.appIconTheme, "app"),
                icon,
                n => Globals.iconReady(n, Theme.appIconTheme, "app")
            );
    }

    Process {
        id: qalcProc
        stdout: StdioCollector {
            id: qalcOut
            waitForEnd: true
            onStreamFinished: {
                const t = (qalcOut.text || "").trim();
                root.mathPending = false;
                if (t)
                    root.mathResult = t.split("\n")[0].trim();
                else if (!root.mathResult)
                    root.mathResult = root.simpleEval(root.mathExpr);
            }
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: code => {
            root.mathPending = false;
            if (code !== 0 && !root.mathResult)
                root.mathResult = root.simpleEval(root.mathExpr);
        }
    }

    Process { id: insertProc }
    Process { id: calcProc }

    Timer {
        id: qalcDebounce
        interval: 180
        onTriggered: root.runQalc()
    }

    Timer {
        id: insertDelay
        interval: 50
        onTriggered: {
            const text = root.pendingInsert;
            root.pendingInsert = "";
            if (!text)
                return;
            const script = Quickshell.shellPath("scripts/qs-insert-text.sh");
            const args = ["bash", script, "--delay", "80"];
            if (Globals.insertTargetAddress)
                args.push("--focus", Globals.insertTargetAddress);
            args.push("--", text);
            insertProc.command = args;
            insertProc.running = true;
        }
    }

    FileView {
        id: appRecentsFile
        path: root.appRecentsPath
        blockLoading: true
        watchChanges: true
        onLoaded: root.loadAppRecents()
        onFileChanged: reload()
    }

    Component.onCompleted: appRecentsFile.reload()

    // Click-outside dismiss
    PanelWindow {
        screen: Globals.shellScreen
        visible: Globals.launcherOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:launcher-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Globals.closeLauncher()
        }
    }

    PanelWindow {
        screen: Globals.shellScreen
        id: launcherWin
        visible: Globals.launcherOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Take the mask from the reveal's own geometry, not the panel inside it:
        // the reveal scales its content, and a mask read off a scaled item stays
        // frozen at the start scale, cropping the panel.
        HyprlandWindow.visibleMask: Region {
            x: reveal.x
            y: reveal.y
            width: reveal.width
            height: reveal.height
        }

        MainframeReveal {
            id: reveal
            revealed: Globals.launcherOpen
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.16)
            width: 720
            height: panelCol.implicitHeight

            MainframeSurface {
                id: panel
                anchors.fill: parent
                baseColor: root.colPanel
                showHatchTop: true
                showHatchBottom: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: {}
                }

                ColumnLayout {
                    id: panelCol
                    width: parent.width
                    spacing: 0

                // Search
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 14
                    Layout.bottomMargin: 10
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: root.colMuted
                        font.pixelSize: 22
                        font.family: Theme.fontFamily
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: root.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        selectedTextColor: "#111"
                        selectionColor: root.colAccent
                        cursorVisible: true
                        focus: Globals.launcherOpen
                        text: root.query

                        onTextChanged: {
                            root.query = text;
                            root.selected = 0;
                            if (root.looksLikeMath(text))
                                qalcDebounce.restart();
                            else {
                                root.mathResult = "";
                                root.mathExpr = "";
                                root.mathPending = false;
                            }
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Globals.closeLauncher();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                root.selected = Math.min(root.resultCount - 1, root.selected + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.selected = Math.max(0, root.selected - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.activateSelected();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search apps & calculate… (recents when empty)"
                            color: root.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            visible: !searchField.text && !searchField.activeFocus
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.hatch
                    visible: root.resultCount > 0
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.resultCount, 8) * 56
                    clip: true
                    model: resultModel
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds

                    onCountChanged: root.clampSelected()

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 56
                        color: index === root.selected ? root.colRowHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 0
                                color: root.colRow
                                clip: true

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 26
                                    asynchronous: true
                                    source: modelData.kind === "app" ? root.iconSource(modelData.entry) : ""
                                    visible: status === Image.Ready && modelData.kind === "app"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.kind !== "app" || parent.children[0].status !== Image.Ready
                                    text: modelData.kind === "math" ? "=" : (modelData.kind === "calc" ? "󰖬" : "󰀄")
                                    color: modelData.kind === "math" ? root.colAccent : root.colFg
                                    font.pixelSize: modelData.kind === "math" ? 20 : 18
                                    font.family: Theme.fontFamily
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || ""
                                    color: root.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: modelData.kind === "math"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.subtitle || ""
                                    color: root.colMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    visible: !!(modelData.subtitle)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                            onEntered: root.selected = index
                            onClicked: {
                                root.selected = index;
                                root.activateSelected();
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.margins: 14
                    visible: root.resultCount === 0
                    text: DesktopEntries.applications.values.length === 0
                        ? "No applications indexed yet…"
                        : "No matches"
                    color: root.colMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    Layout.fillWidth: true
                    height: 8
                    visible: root.resultCount > 0
                }
            }
            }
        }

        onVisibleChanged: {
            if (visible) {
                root.query = "";
                root.selected = 0;
                root.mathResult = "";
                root.mathExpr = "";
                root.mathPending = false;
                root.loadAppRecents();
                Qt.callLater(() => {
                    searchField.forceActiveFocus();
                    searchField.selectAll();
                });
            }
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.launcherOpen
            onActivated: Globals.closeLauncher()
        }
    }
}
