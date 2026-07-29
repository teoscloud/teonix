import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "theme.js" as Theme
import "components"

Scope {
    PanelWindow {
        id: mixerWin
        visible: Globals.mixerOpen
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
            right: 16
        }

        implicitWidth: 420
        implicitHeight: 520

        property int tab: 0
        property int hwPct: 0
        property bool hwMute: false
        property string hwDesc: "Master HW"
        property var streams: []
        property var tracks: []
        property var sinks: []
        property var favIds: []
        property string err: ""

        function favTracks() {
            return tracks.filter(t => favIds.indexOf(t.id) >= 0);
        }

        function toggleFavorite(id) {
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
            if (j.error) {
                err = String(j.error);
                return;
            }
            err = "";
            if (j.status) {
                hwPct = Math.min(100, Math.max(0, j.status.hw_volume_pct || 0));
                hwMute = !!j.status.hw_mute;
                hwDesc = j.status.master_hw_desc || j.status.master_hw || "Master HW";
            }
            streams = j.streams || [];
            tracks = j.tracks || [];
            sinks = j.sinks || [];
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.panelBg()
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Shadow Mixer"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "✕"
                        color: Theme.fgMuted
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Globals.closeMixer()
                        }
                    }
                }

                Text {
                    visible: mixerWin.err.length > 0
                    text: mixerWin.err
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Row {
                    spacing: 6
                    Repeater {
                        model: ["Playback", "Tracks", "Devices"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: lab.implicitWidth + 16
                            height: 26
                            radius: 8
                            color: mixerWin.tab === index ? Theme.bgElevated : "transparent"
                            border.color: mixerWin.tab === index ? Theme.border : "transparent"
                            border.width: 1
                            Text {
                                id: lab
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: mixerWin.tab === index
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mixerWin.tab = index
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 0
                    spacing: 8

                    Text {
                        text: "Master HW — " + mixerWin.hwDesc
                        color: Theme.accentHot
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: mixerWin.hwMute ? "󰖁" : "󰕾"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hwMuteProc.running = true
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
                                hwSetProc.command = [Globals.buschainCtl, "hw-vol", "set", String(mixerWin.hwPct)];
                                hwSetProc.running = true;
                            }
                        }
                        Text {
                            text: mixerWin.hwPct + "%"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            Layout.preferredWidth: 42
                        }
                    }

                    Text {
                        visible: mixerWin.favTracks().length > 0
                        text: "Favorites"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: mixerWin.favTracks().length > 0 ? 160 : 0
                        visible: mixerWin.favTracks().length > 0
                        contentWidth: favRow.implicitWidth
                        clip: true
                        Row {
                            id: favRow
                            spacing: 8
                            Repeater {
                                model: mixerWin.favTracks()
                                TrackStrip {
                                    required property var modelData
                                    track: modelData
                                    favorited: true
                                    onStar: mixerWin.toggleFavorite(modelData.id)
                                    onVol: db => {
                                        trackVol.command = [Globals.buschainCtl, "track", "vol", String(modelData.id), String(db)];
                                        trackVol.running = true;
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Apps"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: mixerWin.streams
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 52
                            radius: Theme.radiusSm
                            color: Theme.bgElevated
                            border.color: Theme.border
                            border.width: 1
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 2
                                Text {
                                    text: modelData.name || "App"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    HSlider {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 150
                                        stepSize: 1
                                        value: modelData.volume_pct || 0
                                        onMoved: {
                                            appVol.command = [Globals.buschainCtl, "playback", "vol", String(modelData.index), String(Math.round(value))];
                                            appVol.running = true;
                                        }
                                    }
                                    Text {
                                        text: (modelData.volume_pct || 0) + "%"
                                        color: Theme.fgMuted
                                        font.pixelSize: 11
                                        Layout.preferredWidth: 40
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: mixerWin.streams.length === 0 && mixerWin.err.length === 0
                            text: "No playback streams"
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 1
                    contentWidth: tracksRow.implicitWidth
                    clip: true
                    Row {
                        id: tracksRow
                        spacing: 8
                        Repeater {
                            model: mixerWin.tracks
                            TrackStrip {
                                required property var modelData
                                track: modelData
                                favorited: mixerWin.favIds.indexOf(modelData.id) >= 0
                                onStar: mixerWin.toggleFavorite(modelData.id)
                                onVol: db => {
                                    trackVol.command = [Globals.buschainCtl, "track", "vol", String(modelData.id), String(db)];
                                    trackVol.running = true;
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: mixerWin.tracks.length === 0
                        text: "No tracks in session"
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mixerWin.tab === 2
                    clip: true
                    spacing: 6
                    model: mixerWin.sinks
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 48
                        radius: Theme.radiusSm
                        color: modelData.is_master ? Theme.bgElevated : Theme.bg
                        border.color: Theme.border
                        border.width: 1
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            Text {
                                text: (modelData.is_master ? "★ " : "") + (modelData.desc || modelData.name)
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: !!modelData.is_master
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: Math.min(100, modelData.volume_pct || 0) + "%" + (modelData.mute ? " · muted" : "")
                                color: Theme.fgMuted
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        Process {
            id: refresh
            command: [Globals.buschainCtl, "playback", "list"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try { mixerWin.applyPayload(JSON.parse(this.text.trim())); } catch (e) {}
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    const t = this.text.trim();
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
                onStreamFinished: {
                    try { mixerWin.favIds = JSON.parse(this.text.trim()); } catch (e) { mixerWin.favIds = []; }
                    refresh.running = true;
                }
            }
        }

        Process { id: hwSetProc }
        Process {
            id: hwMuteProc
            command: [Globals.buschainCtl, "hw-vol", "mute", "toggle"]
            stdout: StdioCollector { onStreamFinished: refresh.running = true }
        }
        Process { id: appVol; stdout: StdioCollector { onStreamFinished: refresh.running = true } }
        Process { id: trackVol; stdout: StdioCollector { onStreamFinished: refresh.running = true } }
        Process { id: favWrite }

        Timer {
            interval: 1500
            running: Globals.mixerOpen
            repeat: true
            onTriggered: refresh.running = true
        }

        Connections {
            target: Globals
            function onMixerOpenChanged() {
                if (Globals.mixerOpen)
                    favLoad.running = true;
            }
        }
    }

    component TrackStrip: Rectangle {
        id: strip
        property var track: ({})
        property bool favorited: false
        signal star
        signal vol(real db)

        width: 72
        height: 200
        radius: Theme.radiusSm
        color: favorited ? Qt.rgba(0.35, 0.32, 0.45, 0.55) : Theme.bgElevated
        border.color: Theme.border
        border.width: 1

        function dbToUi(db) {
            const lin = Math.pow(10.0, Number(db || 0) / 20.0);
            return Math.max(0, Math.min(150, lin * 100.0));
        }
        function uiToDb(ui) {
            const lin = Math.max(1e-4, Number(ui) / 100.0);
            return 20.0 * Math.log(lin) / Math.LN10;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            Text {
                text: favorited ? "★" : "☆"
                color: favorited ? Theme.accentHot : Theme.fgMuted
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.star()
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
                text: Math.round(strip.dbToUi(strip.track.gain_db)) + "%"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: String(strip.track.name || "Track").slice(0, 10)
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 60
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
