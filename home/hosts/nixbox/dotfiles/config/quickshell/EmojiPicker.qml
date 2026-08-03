import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "theme.js" as Theme

Scope {
    id: root

    readonly property color colFg: "#f7f5ff"
    readonly property color colMuted: Qt.rgba(0.97, 0.96, 1.0, 0.72)
    readonly property color colPanel: Globals.glassColor(0.55)
    readonly property color colRow: Qt.rgba(1, 1, 1, 0.06)
    readonly property color colRowHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color colBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property color colAccent: Theme.accentHot

    readonly property string catalogPath: Quickshell.shellPath("data/emojis.json")
    readonly property string recentsPath: `${Quickshell.env("HOME")}/.config/qs-emoji-recents.json`
    readonly property string insertScript: Quickshell.shellPath("scripts/qs-insert-text.sh")

    property var allEmojis: []
    property var recents: []
    property string search: ""
    property string activeCategory: "Smileys"
    property int selected: 0
    property string pendingInsert: ""
    property var categoryOrder: [
        "Recents", "Smileys", "People", "Animals", "Nature",
        "Food", "Activity", "Travel", "Objects", "Symbols", "Flags"
    ]

    readonly property var displayed: {
        const q = root.search.trim().toLowerCase();
        if (q) {
            const out = [];
            for (let i = 0; i < root.allEmojis.length; i++) {
                const e = root.allEmojis[i];
                const hay = ((e.name || "") + " " + (e.keywords || "") + " " + (e.emoji || "")).toLowerCase();
                if (hay.indexOf(q) >= 0)
                    out.push(e);
            }
            return out;
        }
        if (root.activeCategory === "Recents") {
            const out = [];
            for (let i = 0; i < root.recents.length; i++) {
                const ch = root.recents[i];
                let found = null;
                for (let j = 0; j < root.allEmojis.length; j++) {
                    if (root.allEmojis[j].emoji === ch) {
                        found = root.allEmojis[j];
                        break;
                    }
                }
                out.push(found || { emoji: ch, name: ch, keywords: "", category: "Recents" });
            }
            return out;
        }
        const out = [];
        for (let i = 0; i < root.allEmojis.length; i++) {
            if (root.allEmojis[i].category === root.activeCategory)
                out.push(root.allEmojis[i]);
        }
        return out;
    }

    readonly property int displayCount: root.displayed.length

    property bool applyCategoryOnLoad: false

    function loadCatalog() {
        try {
            const raw = catalogFile.text();
            if (!raw || !raw.trim())
                return;
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed))
                root.allEmojis = parsed;
        } catch (e) {
            console.log("EmojiPicker: catalog parse failed", e);
        }
    }

    function loadRecents() {
        try {
            const raw = recentsFile.text();
            if (raw && raw.trim()) {
                const parsed = JSON.parse(raw);
                if (Array.isArray(parsed))
                    root.recents = parsed;
            }
        } catch (e) {
            console.log("EmojiPicker: recents parse failed", e);
        }
        if (root.applyCategoryOnLoad) {
            root.applyCategoryOnLoad = false;
            root.activeCategory = root.recents.length > 0 ? "Recents" : "Smileys";
            root.selected = 0;
        }
    }

    // Prefer FileView.setText so the in-memory view stays in sync with disk
    function saveRecents() {
        const json = JSON.stringify(root.recents);
        try {
            recentsFile.setText(json);
            return;
        } catch (e) {
            console.log("EmojiPicker: setText failed, falling back to shell write", e);
        }
        saveProc.command = ["bash", "-c",
            "umask 022; printf '%s' \"$1\" > \"$2\"",
            "qs-emoji-save",
            json,
            root.recentsPath
        ];
        saveProc.running = true;
    }

    function pushRecent(emoji) {
        if (!emoji)
            return;
        const next = [emoji];
        for (let i = 0; i < root.recents.length; i++) {
            if (root.recents[i] !== emoji)
                next.push(root.recents[i]);
            if (next.length >= 40)
                break;
        }
        root.recents = next;
        root.saveRecents();
    }

    function clampSelected() {
        if (root.displayCount <= 0) {
            root.selected = 0;
            return;
        }
        if (root.selected < 0)
            root.selected = 0;
        if (root.selected >= root.displayCount)
            root.selected = root.displayCount - 1;
    }

    function colsForWidth(w) {
        const cw = 52;
        return Math.max(1, Math.floor(w / cw));
    }

    function moveSelection(delta) {
        if (root.displayCount <= 0)
            return;
        root.selected = (root.selected + delta + root.displayCount) % root.displayCount;
        grid.positionViewAtIndex(root.selected, GridView.Contain);
    }

    function insertEmoji(emoji) {
        if (!emoji)
            return;
        root.pushRecent(emoji);
        root.pendingInsert = emoji;
        Globals.closeEmoji();
        insertDelay.restart();
    }

    function insertSelected() {
        const list = root.displayed;
        if (!list || list.length === 0)
            return;
        root.clampSelected();
        root.insertEmoji(list[root.selected].emoji);
    }

    function insertRecentIndex(idx) {
        if (idx < 0 || idx >= root.recents.length)
            return;
        root.insertEmoji(root.recents[idx]);
    }

    Timer {
        id: insertDelay
        interval: 50
        onTriggered: {
            const emoji = root.pendingInsert;
            root.pendingInsert = "";
            if (!emoji)
                return;
            const args = ["bash", root.insertScript, "--delay", "80"];
            if (Globals.insertTargetAddress)
                args.push("--focus", Globals.insertTargetAddress);
            args.push("--", emoji);
            insertProc.command = args;
            insertProc.running = true;
        }
    }

    FileView {
        id: catalogFile
        path: root.catalogPath
        blockLoading: true
        watchChanges: true
        onLoaded: root.loadCatalog()
        onFileChanged: reload()
    }

    FileView {
        id: recentsFile
        path: root.recentsPath
        blockLoading: true
        watchChanges: false
        onLoaded: root.loadRecents()
    }

    Process {
        id: saveProc
        onExited: code => {
            if (code === 0)
                recentsFile.reload();
            else
                console.log("EmojiPicker: shell save failed", code);
        }
    }
    Process { id: insertProc }

    Component.onCompleted: {
        catalogFile.reload();
        recentsFile.reload();
    }

    // Click-outside dismiss (separate layer under the panel)
    PanelWindow {
        visible: Globals.emojiOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:emoji-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Globals.closeEmoji()
        }
    }

    PanelWindow {
        id: emojiWin
        visible: Globals.emojiOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "quickshell:emoji"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Only the panel captures input — rest passes through to dismiss layer
        HyprlandWindow.visibleMask: Region {
            item: panel
            radius: 22
        }

        Rectangle {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 96
            width: 480
            height: 420
            radius: 22
            color: root.colPanel
            border.color: root.colBorder
            border.width: 1
            clip: true

            // Swallow clicks on chrome so they don't dismiss
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: event => event.accepted = true
                z: 0
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                z: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "😀"
                        font.pixelSize: 22
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: root.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        focus: Globals.emojiOpen
                        text: root.search
                        onTextChanged: {
                            root.search = text;
                            root.selected = 0;
                        }

                        Keys.onPressed: event => {
                            const cols = root.colsForWidth(grid.width);
                            const key = event.key;
                            const ctrl = !!(event.modifiers & Qt.ControlModifier);

                            if (key === Qt.Key_Escape) {
                                Globals.closeEmoji();
                                event.accepted = true;
                            } else if (key === Qt.Key_Return || key === Qt.Key_Enter
                                       || (ctrl && key === Qt.Key_W)) {
                                root.insertSelected();
                                event.accepted = true;
                            } else if (key === Qt.Key_Right || (ctrl && key === Qt.Key_E)) {
                                root.moveSelection(1);
                                event.accepted = true;
                            } else if (key === Qt.Key_Left || (ctrl && key === Qt.Key_Q)) {
                                root.moveSelection(-1);
                                event.accepted = true;
                            } else if (key === Qt.Key_Down || (ctrl && key === Qt.Key_F)) {
                                root.moveSelection(cols);
                                event.accepted = true;
                            } else if (key === Qt.Key_Up || (ctrl && key === Qt.Key_R)) {
                                root.moveSelection(-cols);
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search emoji…"
                            color: root.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            visible: !searchField.text && !searchField.activeFocus
                        }
                    }

                    Text {
                        text: "Esc"
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        opacity: 0.7
                    }
                }

                Flickable {
                    id: tabsFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    contentWidth: tabsRow.implicitWidth
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.search.trim() === ""

                    Row {
                        id: tabsRow
                        spacing: 6
                        height: parent.height

                        Repeater {
                            model: root.categoryOrder
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool active: root.activeCategory === modelData
                                width: tabLabel.implicitWidth + 18
                                height: 32
                                radius: 10
                                color: active ? root.colRowHover : root.colRow
                                border.color: active ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: modelData === "Recents"
                                        ? (root.recents.length ? ("Recents · " + root.recents.length) : "Recents")
                                        : modelData
                                    color: active ? root.colFg : root.colMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: active
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeCategory = modelData;
                                        root.selected = 0;
                                    }
                                }
                            }
                        }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 52
                    cellHeight: 52
                    model: root.displayed
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.selected
                    keyNavigationEnabled: false
                    interactive: true

                    onCountChanged: root.clampSelected()

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property string emojiChar: {
                            if (!modelData)
                                return "";
                            if (typeof modelData === "string")
                                return modelData;
                            return modelData.emoji || "";
                        }
                        readonly property bool isSelected: index === root.selected

                        Rectangle {
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: 12
                            color: cell.isSelected || cellMa.containsMouse
                                ? root.colRowHover
                                : "transparent"
                            border.color: cell.isSelected ? root.colAccent : "transparent"
                            border.width: cell.isSelected ? 1 : 0

                            Text {
                                anchors.centerIn: parent
                                text: cell.emojiChar
                                font.pixelSize: 26
                            }

                            Rectangle {
                                visible: root.search.trim() === ""
                                    && root.activeCategory === "Recents"
                                    && index < 5
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 2
                                anchors.topMargin: 2
                                width: 14
                                height: 14
                                radius: 4
                                color: Qt.rgba(0, 0, 0, 0.45)
                                Text {
                                    anchors.centerIn: parent
                                    text: String(index + 1)
                                    color: root.colAccent
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                }
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onEntered: root.selected = index
                                onClicked: {
                                    root.selected = index;
                                    root.insertEmoji(cell.emojiChar);
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: root.search.trim()
                            ? "No matches"
                            : (root.activeCategory === "Recents"
                                ? "No recent emoji yet — pick from Smileys"
                                : "Empty category")
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.search.trim())
                            return grid.count + " matches · Enter to insert";
                        if (root.activeCategory === "Recents" && root.recents.length)
                            return "Ctrl+Q/E ←→ · Ctrl+R/F ↑↓ · Ctrl+W/Enter paste";
                        return "Ctrl+Q/E ←→ · Ctrl+R/F ↑↓ · Ctrl+W or Enter to paste";
                    }
                    color: root.colMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                root.search = "";
                root.selected = 0;
                root.applyCategoryOnLoad = true;
                // Reload from disk so Recents reflect the last save (FileView cache)
                recentsFile.reload();
                Qt.callLater(() => searchField.forceActiveFocus());
            }
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.emojiOpen
            onActivated: Globals.closeEmoji()
        }
        Shortcut {
            sequences: ["Ctrl+1"]
            enabled: Globals.emojiOpen
            onActivated: root.insertRecentIndex(0)
        }
        Shortcut {
            sequences: ["Ctrl+2"]
            enabled: Globals.emojiOpen
            onActivated: root.insertRecentIndex(1)
        }
        Shortcut {
            sequences: ["Ctrl+3"]
            enabled: Globals.emojiOpen
            onActivated: root.insertRecentIndex(2)
        }
        Shortcut {
            sequences: ["Ctrl+4"]
            enabled: Globals.emojiOpen
            onActivated: root.insertRecentIndex(3)
        }
        Shortcut {
            sequences: ["Ctrl+5"]
            enabled: Globals.emojiOpen
            onActivated: root.insertRecentIndex(4)
        }
    }
}
