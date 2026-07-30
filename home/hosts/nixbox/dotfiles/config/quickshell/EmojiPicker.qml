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
    // Wallpaper-tinted frost (Hyprland blur shows through)
    readonly property color colPanel: Globals.glassColor(0.55)
    readonly property color colRow: Qt.rgba(1, 1, 1, 0.06)
    readonly property color colRowHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color colBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property color colAccent: Theme.accentHot

    readonly property string catalogPath: Quickshell.shellPath("data/emojis.json")
    readonly property string recentsPath: `${Quickshell.env("HOME")}/.config/qs-emoji-recents.json`

    property var allEmojis: []
    property var recents: []
    property string search: ""
    property string activeCategory: "Recents"
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
            if (!raw || !raw.trim()) {
                root.recents = [];
                // Seed empty file so FileView stops warning on missing path
                root.saveRecents();
                return;
            }
            const parsed = JSON.parse(raw);
            root.recents = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            root.recents = [];
            root.saveRecents();
        }
    }

    function saveRecents() {
        try {
            recentsFile.setText(JSON.stringify(root.recents));
        } catch (e) {
            console.log("EmojiPicker: failed to save recents", e);
        }
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

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function insertEmoji(emoji) {
        if (!emoji)
            return;
        root.pushRecent(emoji);
        insertProc.command = ["sh", "-c",
            "printf %s " + shellQuote(emoji) + " | wl-copy && wtype -M ctrl -M shift v -m ctrl -m shift"
        ];
        insertProc.running = true;
        Globals.closeEmoji();
    }

    function insertRecentIndex(idx) {
        if (idx < 0 || idx >= root.recents.length)
            return;
        root.insertEmoji(root.recents[idx]);
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
        watchChanges: true
        onLoaded: root.loadRecents()
        onFileChanged: reload()
    }

    Process { id: insertProc }

    Component.onCompleted: {
        catalogFile.reload();
        recentsFile.reload();
    }

    // Click-outside
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
        // Alpha on the layer surface — required for Hyprland blurls/layerrule frost
        color: root.colPanel
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
            color: "transparent"
            border.color: root.colBorder
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Search
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
                        onTextChanged: root.search = text

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Globals.closeEmoji();
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

                // Category tabs — horizontal scroll
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
                                // Hide Recents tab label still shown; empty recents ok
                                width: tabLabel.implicitWidth + 18
                                height: 32
                                radius: 10
                                color: active ? root.colRowHover : root.colRow
                                border.color: active ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: active ? root.colFg : root.colMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: active
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.ArrowCursor
                                    onClicked: root.activeCategory = modelData
                                }
                            }
                        }
                    }
                }

                // Grid
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 52
                    cellHeight: 52
                    model: root.displayed
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: 12
                            color: cellMa.containsMouse ? root.colRowHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.emoji || ""
                                font.pixelSize: 26
                            }

                            // Ctrl+1..5 badges on first five Recents when not searching
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
                                cursorShape: Qt.ArrowCursor
                                onClicked: root.insertEmoji(modelData.emoji)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: root.search.trim() ? "No matches" : "No recent emoji yet"
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.search.trim()
                        ? (grid.count + " matches")
                        : "Ctrl+1…5 insert latest recents"
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
                root.activeCategory = "Recents";
                root.loadRecents();
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
