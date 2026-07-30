import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "theme.js" as Theme
import "components"

Scope {
    id: root

    readonly property color colFg: "#f7f5ff"
    readonly property color colMuted: Qt.rgba(0.97, 0.96, 1.0, 0.72)
    readonly property color colPanel: Globals.glassColor(0.55)
    readonly property color colCard: Qt.rgba(1, 1, 1, 0.08)
    readonly property color colCardHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color colBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property color colAccent: Theme.accentHot

    PanelWindow {
        visible: Globals.mixerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:mixer-dismiss"
        WlrLayershell.layer: WlrLayer.Top
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Globals.closeMixer()
        }
    }

    PanelWindow {
        id: mixerWin
        visible: Globals.mixerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: root.colPanel
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "quickshell:mixer"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandWindow.visibleMask: Region {
            item: panel
            radius: 22
        }

        // Sit under the bar VolumePill (left cluster)
        anchors {
            top: true
            left: true
        }
        margins {
            top: Theme.barHeight + 8
            left: Math.max(Theme.pad, Globals.volPillX)
        }
        implicitWidth: 400
        implicitHeight: 560

        property int tab: 0
        property int hwPct: 0
        property bool hwMute: false
        property string hwDesc: "Master HW"
        property var streams: []
        property var tracks: []
        property var sinks: []
        property var sources: []
        property var favIds: []
        property string err: ""
        property string defaultSink: ""
        property string defaultSource: ""

        function favTracks() {
            const out = [];
            for (let i = 0; i < tracks.length; i++) {
                if (favIds.indexOf(tracks[i].id) >= 0)
                    out.push(tracks[i]);
            }
            return out;
        }

        function toggleFavorite(id) {
            if (!id)
                return;
            const next = favIds.slice();
            const i = next.indexOf(id);
            if (i >= 0)
                next.splice(i, 1);
            else
                next.push(id);
            favIds = next;
            const payload = JSON.stringify(next).replace(/'/g, "'\\''");
            favWrite.command = ["sh", "-c",
                "mkdir -p \"$HOME/.config/buschain-control\" && printf '%s' '" + payload + "' > \"$HOME/.config/buschain-control/mixer-pins.json\""
            ];
            favWrite.running = true;
        }

        function applyPayload(j) {
            if (!j) {
                err = "empty mixer response";
                return;
            }
            if (j.error) {
                err = String(j.error);
                return;
            }
            err = "";
            if (j.status) {
                hwPct = Math.min(100, Math.max(0, Number(j.status.hw_volume_pct) || 0));
                hwMute = !!j.status.hw_mute;
                hwDesc = j.status.master_hw_desc || j.status.master_hw || "Master HW";
                Globals.hwVolPct = hwPct;
                Globals.hwVolMuted = hwMute;
            }
            streams = j.streams || [];
            tracks = j.tracks || [];
            sinks = j.sinks || [];
            sources = j.sources || [];
            defaultSink = j.default_sink || "";
            defaultSource = j.default_source || "";
        }

        function refresh() {
            refreshProc.running = false;
            refreshProc.running = true;
        }

        function runCtl(args) {
            ctlProc.command = [Globals.buschainCtl].concat(args);
            ctlProc.running = true;
        }

        Rectangle {
            id: panel
            anchors.fill: parent
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
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Mixer"
                        color: root.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "✕"
                        color: root.colMuted
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.ArrowCursor
                            onClicked: Globals.closeMixer()
                        }
                    }
                }

                Text {
                    visible: mixerWin.err.length > 0
                    text: mixerWin.err
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Row {
                    spacing: 5
                    Repeater {
                        model: ["Playback", "Tracks", "Output", "Input"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: tabLab.implicitWidth + 14
                            height: 26
                            radius: 8
                            color: mixerWin.tab === index ? root.colCardHover : root.colCard
                            border.color: mixerWin.tab === index ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                            border.width: 1
                            Text {
                                id: tabLab
                                anchors.centerIn: parent
                                text: modelData
                                color: mixerWin.tab === index ? root.colFg : root.colMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: mixerWin.tab === index
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.ArrowCursor
                                onClicked: mixerWin.tab = index
                            }
                        }
                    }
                }

                // Playback
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 0
                    spacing: 8

                    Text {
                        text: "Master HW — " + mixerWin.hwDesc
                        color: root.colAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: mixerWin.hwMute ? "MUTE" : "VOL"
                            color: root.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.ArrowCursor
                                onClicked: mixerWin.runCtl(["hw-vol", "mute", "toggle"])
                            }
                        }
                        HSlider {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            stepSize: 1
                            value: mixerWin.hwPct
                            onMoved: {
                                mixerWin.hwPct = Math.round(value);
                                mixerWin.runCtl(["hw-vol", "set", String(mixerWin.hwPct)]);
                            }
                        }
                        Text {
                            text: mixerWin.hwPct + "%"
                            color: root.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        visible: mixerWin.favTracks().length > 0
                        text: "Favorites"
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: mixerWin.favTracks().length > 0 ? 150 : 0
                        visible: mixerWin.favTracks().length > 0
                        contentWidth: favRow.implicitWidth
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        Row {
                            id: favRow
                            spacing: 6
                            Repeater {
                                model: mixerWin.favTracks()
                                TrackStrip {
                                    required property var modelData
                                    track: modelData
                                    favorited: true
                                    onStar: mixerWin.toggleFavorite(modelData.id)
                                    onVol: db => mixerWin.runCtl(["track", "vol", String(modelData.id), String(db)])
                                    onMuteToggle: mixerWin.runCtl(["track", "mute", String(modelData.id), "toggle"])
                                }
                            }
                        }
                    }

                    Text {
                        text: "Apps"
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5
                        model: mixerWin.streams
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 48
                            radius: 10
                            color: root.colCard
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 3
                                Text {
                                    text: modelData.application || modelData.name || "App"
                                    color: root.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: modelData.mute ? "M" : "A"
                                        color: root.colMuted
                                        font.pixelSize: 11
                                        font.bold: true
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.ArrowCursor
                                            onClicked: mixerWin.runCtl(["playback", "mute", String(modelData.index), "toggle"])
                                        }
                                    }
                                    HSlider {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 100
                                        stepSize: 1
                                        value: Math.min(100, modelData.volume_pct || 0)
                                        onMoved: mixerWin.runCtl(["playback", "vol", String(modelData.index), String(Math.round(value))])
                                    }
                                    Text {
                                        text: Math.min(100, modelData.volume_pct || 0) + "%"
                                        color: root.colMuted
                                        font.pixelSize: 11
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: mixerWin.streams.length === 0 && mixerWin.err.length === 0
                            text: "No playback streams"
                            color: root.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                // Tracks
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 1
                    Flickable {
                        anchors.fill: parent
                        contentWidth: tracksRow.implicitWidth
                        contentHeight: height
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        Row {
                            id: tracksRow
                            spacing: 6
                            height: parent.height
                            Repeater {
                                model: mixerWin.tracks
                                TrackStrip {
                                    required property var modelData
                                    track: modelData
                                    favorited: mixerWin.favIds.indexOf(modelData.id) >= 0
                                    tall: true
                                    onStar: mixerWin.toggleFavorite(modelData.id)
                                    onVol: db => mixerWin.runCtl(["track", "vol", String(modelData.id), String(db)])
                                    onMuteToggle: mixerWin.runCtl(["track", "mute", String(modelData.id), "toggle"])
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: mixerWin.tracks.length === 0
                        text: "No tracks in session"
                        color: root.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // Output
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 2
                    clip: true
                    spacing: 5
                    model: mixerWin.sinks
                    delegate: DeviceRow {
                        required property var modelData
                        width: ListView.view.width
                        kind: "sink"
                        device: modelData
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: mixerWin.sinks.length === 0
                        text: "No sinks"
                        color: root.colMuted
                        font.pixelSize: 12
                    }
                }

                // Input
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 3
                    clip: true
                    spacing: 5
                    model: mixerWin.sources
                    delegate: DeviceRow {
                        required property var modelData
                        width: ListView.view.width
                        kind: "source"
                        device: modelData
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: mixerWin.sources.length === 0
                        text: "No sources"
                        color: root.colMuted
                        font.pixelSize: 12
                    }
                }
            }
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.mixerOpen
            onActivated: Globals.closeMixer()
        }

        Process {
            id: refreshProc
            command: [Globals.buschainCtl, "mixer"]
            running: false
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    try {
                        mixerWin.applyPayload(JSON.parse(text.trim()));
                    } catch (e) {
                        mixerWin.err = "parse error";
                    }
                }
            }
            stderr: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    const t = text.trim();
                    if (t.length > 0)
                        mixerWin.err = t;
                }
            }
        }

        Process {
            id: favLoad
            command: ["sh", "-c", "cat \"$HOME/.config/buschain-control/mixer-pins.json\" 2>/dev/null || echo '[]'"]
            running: false
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    try {
                        mixerWin.favIds = JSON.parse(text.trim());
                    } catch (e) {
                        mixerWin.favIds = [];
                    }
                    mixerWin.refresh();
                }
            }
        }

        Process {
            id: ctlProc
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    mixerWin.refresh();
                    Globals.bumpHwVol();
                }
            }
            stderr: StdioCollector {
                waitForEnd: true
            }
            onExited: {
                mixerWin.refresh();
                Globals.bumpHwVol();
            }
        }

        Process {
            id: favWrite
        }

        FileView {
            path: Globals.mixerTickPath
            watchChanges: true
            onFileChanged: {
                reload();
                if (Globals.mixerOpen)
                    mixerWin.refresh();
            }
        }

        Timer {
            interval: 180
            running: Globals.mixerOpen
            repeat: true
            onTriggered: mixerWin.refresh()
        }

        Connections {
            target: Globals
            function onMixerOpenChanged() {
                if (Globals.mixerOpen) {
                    Globals.refreshWallpaperTint();
                    favLoad.running = true;
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: drow
        property var device: ({})
        property string kind: "sink"
        height: 56
        radius: 10
        color: root.colCard
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        readonly property bool isMaster: !!device.is_master
        readonly property bool isDefault: !!device.is_default
            || (kind === "sink" && device.name === mixerWin.defaultSink)
            || (kind === "source" && device.name === mixerWin.defaultSource)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: {
                        let t = device.desc || device.name || "Device";
                        const tags = [];
                        if (drow.isMaster)
                            tags.push("Master HW");
                        if (drow.isDefault)
                            tags.push("Default");
                        if (tags.length)
                            t += " · " + tags.join(" · ");
                        return t;
                    }
                    color: drow.isMaster ? root.colAccent : root.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: drow.isMaster || drow.isDefault
                    elide: Text.ElideRight
                }
                Text {
                    visible: kind === "sink" && !drow.isMaster
                    text: "Set HW"
                    color: root.colMuted
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.ArrowCursor
                        onClicked: mixerWin.runCtl(["master-hw", "set", String(device.name)])
                    }
                }
                Text {
                    text: drow.isDefault ? "Default" : "Set default"
                    color: drow.isDefault ? root.colAccent : root.colMuted
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.ArrowCursor
                        onClicked: mixerWin.runCtl(["default", drow.kind, String(device.name)])
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: device.mute ? "M" : "V"
                    color: root.colMuted
                    font.pixelSize: 11
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.ArrowCursor
                        onClicked: mixerWin.runCtl([drow.kind, "mute", String(device.name), "toggle"])
                    }
                }
                HSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    value: Math.min(100, device.volume_pct || 0)
                    onMoved: mixerWin.runCtl([drow.kind, "vol", String(device.name), String(Math.round(value))])
                }
                Text {
                    text: Math.min(100, device.volume_pct || 0) + "%"
                    color: root.colMuted
                    font.pixelSize: 11
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    component TrackStrip: Rectangle {
        id: strip
        property var track: ({})
        property bool favorited: false
        property bool tall: false
        signal star
        signal vol(real db)
        signal muteToggle

        width: 68
        height: tall ? Math.max(150, parent ? parent.height : 150) : 150
        radius: 10
        color: favorited ? Qt.rgba(0.9, 0.96, 0.76, 0.14) : root.colCard
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        function dbToUi(db) {
            const lin = Math.pow(10.0, Number(db || 0) / 20.0);
            return Math.max(0, Math.min(150, lin * 100.0));
        }
        function uiToDb(ui) {
            const lin = Math.max(1e-4, Number(ui) / 100.0);
            return Math.round((20.0 * Math.log(lin) / Math.LN10) * 10) / 10;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 3

            Text {
                text: favorited ? "★" : "☆"
                color: favorited ? root.colAccent : root.colMuted
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: strip.star()
                }
            }

            Text {
                text: track.mute ? "M" : "m"
                color: track.mute ? Theme.danger : root.colMuted
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: strip.muteToggle()
                }
            }

            VSlider {
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
                from: 0
                to: 150
                stepSize: 1
                value: strip.dbToUi(strip.track.gain_db)
                onMoved: strip.vol(strip.uiToDb(value))
            }

            Text {
                text: (Number(strip.track.gain_db) || 0).toFixed(1) + "dB"
                color: root.colFg
                font.family: Theme.fontFamily
                font.pixelSize: 9
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: String(strip.track.name || "Track").slice(0, 9)
                color: root.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
