import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "components"

Scope {
    id: root

    // Mainframe panels
    readonly property color colFg: Theme.fg
    readonly property color colMuted: Theme.fgMuted
    readonly property color colPanel: Theme.bgRaised
    readonly property color colToast: Theme.bgRaised
    readonly property color colCard: Theme.bg
    readonly property color colCardHover: Theme.bgSelected
    readonly property color colBorder: Theme.hairline
    readonly property color colBorderSoft: Theme.hatch

    // Toast popup queue (visual only). Dismissing a toast must NOT clear Control Center history.
    property var toastQueue: []

    function pushToast(n) {
        if (!n)
            return;
        const next = root.toastQueue.slice();
        // Newest on top
        next.unshift(n);
        // Cap visible toasts
        while (next.length > 5)
            next.pop();
        root.toastQueue = next;
    }

    function dropToast(n) {
        if (!n)
            return;
        root.toastQueue = root.toastQueue.filter(t => t !== n);
    }

    function dismissNotif(n) {
        root.dropToast(n);
        if (n && n.dismiss)
            n.dismiss();
    }

    NotificationServer {
        id: server
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false
        keepOnReload: false

        onNotification: notification => {
            // Keep in Control Center until the user clears it
            notification.tracked = true;
            root.pushToast(notification);
        }
    }

    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            Globals.notifCount = server.trackedNotifications.values.length;
            // Drop toast entries whose Notification objects were destroyed
            const alive = server.trackedNotifications.values;
            root.toastQueue = root.toastQueue.filter(t => alive.indexOf(t) >= 0);
        }
    }

    Component.onCompleted: Globals.notifCount = server.trackedNotifications.values.length

    readonly property int notifCount: server.trackedNotifications.values.length

    Connections {
        target: Globals
        function onNotifDrawerOpenChanged() {
            // Opening Control Center absorbs popups into the history list
            if (Globals.notifDrawerOpen) {
                root.toastQueue = [];
                root.mediaIndex = -1; // re-auto-pick playing player
            }
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.mediaIndex >= root.playerCount)
                root.mediaIndex = root.playerCount > 0 ? root.playerCount - 1 : -1;
        }
    }

    // Manual media selection (−1 = auto: playing → has track → first)
    property int mediaIndex: -1

    readonly property var playerList: Mpris.players?.values || []

    readonly property int playerCount: playerList.length

    readonly property var activePlayer: {
        const list = root.playerList;
        if (!list.length)
            return null;
        if (root.mediaIndex >= 0 && root.mediaIndex < list.length)
            return list[root.mediaIndex];
        let playing = null;
        let withTrack = null;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p.isPlaying && !playing)
                playing = p;
            if ((p.trackTitle || "") !== "" && !withTrack)
                withTrack = p;
        }
        return playing || withTrack || list[0];
    }

    readonly property int activePlayerIndex: {
        const list = root.playerList;
        const cur = root.activePlayer;
        if (!list.length || !cur)
            return -1;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === cur)
                return i;
        }
        return 0;
    }

    property bool mediaAnimating: false

    function cycleMedia(dir) {
        // dir +1 = wheel up / next (right), −1 = wheel down / prev (left)
        const list = root.playerList;
        const n = list.length;
        if (n < 2 || root.mediaAnimating)
            return;
        let idx = root.activePlayerIndex;
        if (idx < 0)
            idx = 0;
        const next = (idx + ((dir % n) + n) % n) % n;
        if (next === idx)
            return;
        if (!mediaCard || !mediaSlideAnim)
            {
                root.mediaIndex = next;
                return;
            }
        mediaSlideAnim.dir = dir > 0 ? 1 : -1;
        mediaSlideAnim.nextIndex = next;
        root.mediaAnimating = true;
        mediaSlideAnim.start();
    }

    // MPRIS position/length are microseconds
    function toSecs(us) {
        if (!isFinite(us) || us < 0)
            return 0;
        return us > 10000 ? us / 1000000 : us;
    }

    function dismissAll() {
        root.toastQueue = [];
        const vals = server.trackedNotifications.values;
        for (let i = vals.length - 1; i >= 0; i--) {
            if (vals[i].dismiss)
                vals[i].dismiss();
        }
    }

    function notifAppIconSource(n) {
        if (!n)
            return "";
        const icon = n.appIcon || "";
        if (!icon)
            return "";
        if (icon.charAt(0) === "/" || icon.indexOf("://") >= 0)
            return icon.charAt(0) === "/" ? ("file://" + icon) : icon;
        return Globals.themedIcon(icon, Theme.appIconTheme, "app");
    }

    function notifIconSource(n) {
        if (n.image)
            return n.image;
        return notifAppIconSource(n);
    }

    function fmtTime(secs) {
        if (!isFinite(secs) || secs < 0)
            return "0:00";
        const s = Math.floor(secs % 60);
        const m = Math.floor(secs / 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Brave/Chrome publish their app icon as mpris:artUrl for YouTube tabs.
    property string resolvedArtUrl: ""

    function metadataUrl(p) {
        if (!p || !p.metadata)
            return "";
        const md = p.metadata;
        return String(md["xesam:url"] || md["xesam:Url"] || "");
    }

    function youtubeIdFrom(s) {
        const m = String(s || "").match(/(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/);
        return m ? m[1] : "";
    }

    function isFakeBrowserArt(url) {
        const u = String(url || "");
        if (!u)
            return true;
        return u.indexOf("/tmp/.org.chromium.") >= 0;
    }

    function notifArtForTrack(title) {
        const t = String(title || "");
        if (!t)
            return "";
        const vals = server.trackedNotifications.values;
        for (let i = 0; i < vals.length; i++) {
            const n = vals[i];
            if (!n || !n.image)
                continue;
            const sum = String(n.summary || "");
            const body = String(n.body || "");
            if (sum === t || body.indexOf(t) >= 0 || t.indexOf(sum) >= 0)
                return n.image;
        }
        return "";
    }

    function instantMediaArt() {
        const p = root.activePlayer;
        if (!p)
            return "";
        const title = p.trackTitle || "";
        const yid = root.youtubeIdFrom(root.metadataUrl(p))
            || root.youtubeIdFrom(title)
            || root.youtubeIdFrom(p.trackArtUrl || "");
        if (yid)
            return "https://i.ytimg.com/vi/" + yid + "/hqdefault.jpg";
        const fromNotif = root.notifArtForTrack(title);
        if (fromNotif)
            return fromNotif;
        const raw = p.trackArtUrl || "";
        if (raw && !root.isFakeBrowserArt(raw))
            return raw;
        return "";
    }

    readonly property string mediaArtUrl: {
        const instant = root.instantMediaArt();
        if (instant)
            return instant;
        return root.resolvedArtUrl;
    }

    readonly property string mediaArtKey: {
        const p = root.activePlayer;
        if (!p)
            return "";
        return [p.dbusName || "", p.trackTitle || "", p.trackArtUrl || "", root.metadataUrl(p)].join("\x1f");
    }

    onMediaArtKeyChanged: {
        root.resolvedArtUrl = "";
        Qt.callLater(root.kickArtResolve);
    }

    function kickArtResolve() {
        artProc.running = false;
        const p = root.activePlayer;
        if (!p) {
            root.resolvedArtUrl = "";
            return;
        }
        if (root.instantMediaArt())
            return;
        const title = p.trackTitle || "";
        const raw = p.trackArtUrl || "";
        const need = root.isFakeBrowserArt(raw) || /youtube/i.test(title);
        if (!need)
            return;
        artProc.command = [Globals.mprisArtScript, p.dbusName || ""];
        artProc.running = true;
    }

    Process {
        id: artProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const u = String(text || "").trim().split(/\s/)[0];
                if (u.indexOf("://") >= 0 || u.startsWith("/"))
                    root.resolvedArtUrl = u;
            }
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    // ---- Toasts ----
    PanelWindow {
        screen: Globals.shellScreen
        id: toastWin
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        visible: toastCol.children.length > 0 && !Globals.notifDrawerOpen
        WlrLayershell.namespace: "quickshell:notifs"
        WlrLayershell.layer: WlrLayer.Top

        HyprlandWindow.visibleMask: Region {
            item: toastCol
            radius: 0
        }

        // Toasts stack up out of the bell in the bottom rail
        anchors {
            bottom: true
            right: true
        }

        margins {
            bottom: 2
            right: 12
        }

        implicitWidth: 408 // ~20% over previous 340
        implicitHeight: Math.max(1, toastCol.implicitHeight)

        Column {
            id: toastCol
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width
            spacing: 8

            Repeater {
                model: root.toastQueue
                delegate: Item {
                    required property var modelData
                    width: toastCol.width
                    height: toastCard.height

                    MainframeReveal {
                        anchors.fill: parent
                        revealed: true
                        MainframeSurface {
                            anchors.fill: parent
                            baseColor: root.colToast
                            showHatchTop: true
                        }
                    }
                    NotifCard {
                        id: toastCard
                        width: parent.width
                        notif: modelData
                        toastMode: true
                        color: "transparent"
                        border.width: 0
                    }
                }
            }
        }
    }

    // Click-outside dismiss (below drawer Overlay so media clicks never hit it)
    PanelWindow {
        screen: Globals.shellScreen
        visible: Globals.notifDrawerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:notifs-dismiss"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Globals.notifDrawerOpen = false
        }
    }

    // ---- Drawer (panel-sized frost; Overlay so it stacks above dismiss) ----
    PanelWindow {
        screen: Globals.shellScreen
        id: drawerWin
        visible: Globals.notifDrawerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "quickshell:notifs"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Off the reveal, not the panel it scales — a mask read from a scaled
        // item freezes at the start scale and crops the drawer.
        HyprlandWindow.visibleMask: Region {
            x: drawerReveal.x
            y: drawerReveal.y
            width: drawerReveal.width
            height: drawerReveal.height
        }

        anchors {
            bottom: true
            right: true
        }

        margins {
            bottom: 2
            right: 12
        }

        implicitWidth: 400
        implicitHeight: 640

        MainframeReveal {
            id: drawerReveal
            anchors.fill: parent
            revealed: Globals.notifDrawerOpen

            MainframeSurface {
                id: drawerPanel
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
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Control Center"
                        color: root.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: root.notifCount > 0
                        width: clearLabel.implicitWidth + 14
                        height: 24
                        radius: 0
                        color: clearMa.containsMouse ? root.colCardHover : root.colCard
                        border.color: Theme.hairline
                        border.width: 1

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: root.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dismissAll()
                        }
                    }
                }

                // Media player
                Rectangle {
                    id: mediaCard
                    Layout.fillWidth: true
                    visible: !!root.activePlayer
                    implicitHeight: mediaOuter.implicitHeight + 20
                    height: visible ? implicitHeight : 0
                    Layout.preferredHeight: height
                    radius: 0
                    color: root.colCard
                    border.color: Theme.hairline
                    border.width: 1
                    clip: true

                    property int posTick: 0

                    // Eat clicks so they never fall through to the dismiss layer
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onPressed: mouse => {
                            mouse.accepted = false;
                        }
                        onClicked: mouse => {
                            mouse.accepted = true;
                        }
                        onWheel: event => {
                            root.cycleMedia(event.angleDelta.y > 0 ? 1 : -1);
                            event.accepted = true;
                        }
                    }

                    // Album art wash (does not slide — stays as card atmosphere)
                    Image {
                        anchors.fill: parent
                        source: root.mediaArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.10
                        visible: status === Image.Ready
                    }

                    ColumnLayout {
                        id: mediaOuter
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Player dots (fixed — do not slide with content)
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5
                            visible: root.playerCount > 1
                            height: visible ? 8 : 0

                            Repeater {
                                model: root.playerCount
                                delegate: Rectangle {
                                    required property int index
                                    width: index === root.activePlayerIndex ? 12 : 6
                                    height: 6
                                    radius: 0
                                    color: index === root.activePlayerIndex
                                        ? Theme.accentHot
                                        : Theme.hatch
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                        }
                                    }
                                }
                            }
                        }

                        // Sliding pane
                        Item {
                            id: slideClip
                            Layout.fillWidth: true
                            Layout.preferredHeight: mediaPane.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: mediaPane
                                width: parent.width
                                x: 0
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: 0
                                        color: root.colCard
                                        border.color: Theme.hairline
                                        border.width: 1
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: root.mediaArtUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !root.mediaArtUrl
                                            text: "♪"
                                            color: Theme.accent
                                            font.pixelSize: 18
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.activePlayer?.identity || "Now Playing"
                                            color: root.colMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.activePlayer?.trackTitle || "Unknown track"
                                            color: root.colFg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            // Keep line even without artist so height stays stable
                                            text: root.activePlayer?.trackArtist || " "
                                            color: root.colMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            opacity: root.activePlayer?.trackArtist ? 1 : 0
                                        }
                                    }
                                }

                                // Progress — reserve height when unsupported
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    opacity: root.activePlayer && root.activePlayer.lengthSupported && root.activePlayer.length > 0 ? 1 : 0
                                    enabled: opacity > 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: 0
                                        color: Theme.hatch

                                        Rectangle {
                                            width: {
                                                mediaCard.posTick;
                                                const pos = toSecs(root.activePlayer?.position || 0);
                                                const len = Math.max(0.001, toSecs(root.activePlayer?.length || 1));
                                                return parent.width * Math.min(1, Math.max(0, pos / len));
                                            }
                                            height: parent.height
                                            radius: 0
                                            color: Theme.accentHot
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: {
                                                mediaCard.posTick;
                                                return fmtTime(toSecs(root.activePlayer?.position || 0));
                                            }
                                            color: root.colMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: fmtTime(toSecs(root.activePlayer?.length || 0))
                                            color: root.colMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                // Transport — fixed slots so prev/play/next never shift
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    // Mirror raise slot width on the left for centering
                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 34
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MediaBtn {
                                        label: "󰒮"
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 34
                                        enabled: !!(root.activePlayer?.canGoPrevious)
                                        onActivate: {
                                            if (root.activePlayer)
                                                root.activePlayer.previous();
                                        }
                                    }
                                    MediaBtn {
                                        label: root.activePlayer?.isPlaying ? "󰏤" : "󰐊"
                                        primary: true
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 34
                                        enabled: !!(root.activePlayer?.canTogglePlaying || root.activePlayer?.canPlay || root.activePlayer?.canPause)
                                        onActivate: {
                                            if (root.activePlayer)
                                                root.activePlayer.togglePlaying();
                                        }
                                    }
                                    MediaBtn {
                                        label: "󰒭"
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 34
                                        enabled: !!(root.activePlayer?.canGoNext)
                                        onActivate: {
                                            if (root.activePlayer)
                                                root.activePlayer.next();
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    // Fixed-width raise slot (invisible when unsupported — layout stays centered)
                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 34
                                        opacity: root.activePlayer?.canRaise ? 1 : 0
                                        enabled: !!(root.activePlayer?.canRaise)

                                        MediaBtn {
                                            anchors.centerIn: parent
                                            label: "󰐑"
                                            small: true
                                            enabled: parent.enabled
                                            onActivate: {
                                                if (root.activePlayer)
                                                    root.activePlayer.raise();
                                            }
                                        }
                                    }
                                }

                                // Volume — always reserve row height
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    opacity: root.activePlayer?.volumeSupported ? 1 : 0
                                    enabled: opacity > 0

                                    Text {
                                        text: {
                                            const v = root.activePlayer?.volume ?? 0;
                                            if (v <= 0.001)
                                                return "󰖁";
                                            if (v < 0.34)
                                                return "󰕿";
                                            if (v < 0.67)
                                                return "󰖀";
                                            return "󰕾";
                                        }
                                        color: root.colFg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        opacity: 0.9
                                        Layout.preferredWidth: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Item {
                                        id: volTrack
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 40
                                        Layout.preferredHeight: 22

                                        readonly property real vol: Math.max(0, Math.min(1, root.activePlayer?.volume ?? 0))

                                        function setVolFromX(x) {
                                            if (!root.activePlayer)
                                                return;
                                            const t = Math.max(0, Math.min(1, x / Math.max(1, width)));
                                            root.activePlayer.volume = t;
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: 4
                                            radius: 0
                                            color: Theme.hatch

                                            Rectangle {
                                                width: parent.width * volTrack.vol
                                                height: parent.height
                                                radius: 0
                                                color: root.colFg
                                                opacity: 0.85
                                            }
                                        }

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 0
                                            color: root.colFg
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(parent.width - width, volTrack.vol * parent.width - width / 2))
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.ArrowCursor
                                            onPressed: volTrack.setVolFromX(mouse.x)
                                            onPositionChanged: if (pressed)
                                                volTrack.setVolFromX(mouse.x)
                                            onWheel: event => {
                                                if (!root.activePlayer)
                                                    return;
                                                const d = event.angleDelta.y > 0 ? 1 : -1;
                                                root.activePlayer.volume = Math.max(0, Math.min(1,
                                                    (root.activePlayer.volume || 0) + d * 0.05));
                                                event.accepted = true;
                                            }
                                        }
                                    }

                                    Text {
                                        text: Math.round((root.activePlayer?.volume ?? 0) * 100) + "%"
                                        color: root.colMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        Layout.preferredWidth: Math.max(implicitWidth, 52)
                                        Layout.minimumWidth: implicitWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    SequentialAnimation {
                        id: mediaSlideAnim
                        property int dir: 1
                        property int nextIndex: 0

                        NumberAnimation {
                            target: mediaPane
                            property: "x"
                            to: mediaSlideAnim.dir > 0 ? -slideClip.width : slideClip.width
                            duration: 140
                            easing.type: Easing.InCubic
                        }
                        ScriptAction {
                            script: {
                                root.mediaIndex = mediaSlideAnim.nextIndex;
                                mediaPane.x = mediaSlideAnim.dir > 0 ? slideClip.width : -slideClip.width;
                            }
                        }
                        NumberAnimation {
                            target: mediaPane
                            property: "x"
                            to: 0
                            duration: 170
                            easing.type: Easing.OutCubic
                        }
                        ScriptAction {
                            script: root.mediaAnimating = false
                        }
                    }

                    Timer {
                        interval: 1000
                        running: mediaCard.visible && Globals.notifDrawerOpen && !!(root.activePlayer?.isPlaying)
                        repeat: true
                        onTriggered: mediaCard.posTick++
                    }
                }

                // Section label
                Text {
                    text: "Notifications"
                    color: root.colMuted
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: 12
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: server.trackedNotifications
                    delegate: NotifCard {
                        required property var modelData
                        width: ListView.view.width
                        notif: modelData
                        toastMode: false
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: root.notifCount === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰂛"
                            color: root.colMuted
                            font.pixelSize: 22
                            opacity: 0.7
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            color: root.colMuted
                            font.family: Theme.fontFamilyUi
                            font.pixelSize: 13
                        }
                    }
                }
            }
            }
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: Globals.notifDrawerOpen
            onActivated: Globals.notifDrawerOpen = false
        }
    }

    // Bare iOS Now Playing icons (no circular chrome)
    component MediaBtn: Item {
        id: btn
        property string label: ""
        property bool primary: false
        property bool small: false
        signal activate

        // Prefer Layout.preferred* from parent; fall back to fixed slots
        implicitWidth: primary ? 44 : (small ? 28 : 38)
        implicitHeight: 34
        opacity: !enabled ? 0.28 : (ma.containsMouse ? 0.75 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: root.colFg
            font.pixelSize: btn.primary ? 24 : (btn.small ? 14 : 18)
            font.family: Theme.fontFamily
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            enabled: btn.enabled
            onClicked: mouse => {
                mouse.accepted = true;
                btn.activate();
            }
        }
    }

    component NotifCard: Rectangle {
        id: card
        property var notif: null
        property bool toastMode: false
        // Fixed size — never derive from height (binding loop → freeze)
        // Toast chrome ~20% larger; drawer keeps denser sizing
        readonly property int mediaSize: toastMode ? 62 : 52
        readonly property int pad: toastMode ? 10 : 8
        readonly property int titlePx: toastMode ? 19 : 14
        readonly property int bodyPx: toastMode ? 15 : 12
        readonly property bool hasActions: !!(notif && notif.actions && notif.actions.length > 0)

        // Height from icon + text only — action chips overlay, never grow the card
        height: Math.max(mediaSize + pad * 2, textCol.implicitHeight + pad * 2)
        radius: 0
        color: toastMode ? root.colToast : (cardMa.containsMouse ? root.colCardHover : root.colCard)
        border.color: root.colBorder
        border.width: 1
        clip: true

        opacity: 0
        property real slideX: 24

        transform: Translate {
            x: card.slideX
        }

        Component.onCompleted: {
            opacity = 1;
            slideX = 0;
        }

        Behavior on opacity {
            QsAnim {}
        }
        Behavior on slideX {
            QsAnim {}
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        RowLayout {
            id: bodyRow
            anchors.fill: parent
            anchors.margins: card.pad
            spacing: toastMode ? 12 : 10

            Rectangle {
                id: mediaBox
                Layout.preferredWidth: card.mediaSize
                Layout.preferredHeight: card.mediaSize
                Layout.alignment: Qt.AlignTop
                // Always circular — square inline images must not bleed through as squares
                radius: card.mediaSize / 2
                color: root.colCard
                border.color: Theme.hairline
                border.width: 1
                clip: true

                readonly property bool hasInlineImage: !!(card.notif && card.notif.image)
                readonly property string appIconSrc: card.notif ? notifAppIconSource(card.notif) : ""
                // Badge when a distinct notification image is shown (icon-only = main glyph)
                readonly property bool showAppBadge: hasInlineImage && !!appIconSrc

                Image {
                    id: nImage
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: {
                        if (!card.notif)
                            return "";
                        const img = card.notif.image || "";
                        if (!img)
                            return "";
                        return img.charAt(0) === "/" ? ("file://" + img) : img;
                    }
                    visible: mediaBox.hasInlineImage && status === Image.Ready
                }
                IconImage {
                    id: nIcon
                    anchors.fill: parent
                    anchors.margins: 2
                    implicitSize: card.mediaSize - 4
                    asynchronous: true
                    source: (!card.notif || mediaBox.hasInlineImage) ? "" : notifIconSource(card.notif)
                    visible: !mediaBox.hasInlineImage && status === Image.Ready && !!source
                }
                Text {
                    anchors.centerIn: parent
                    visible: !mediaBox.hasInlineImage && !nIcon.visible
                    text: "󰂚"
                    color: root.colMuted
                    font.pixelSize: toastMode ? 26 : 22
                }

                // Small app icon, bottom-right of main image
                Rectangle {
                    visible: mediaBox.showAppBadge
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: toastMode ? 22 : 18
                    height: toastMode ? 22 : 18
                    radius: width / 2
                    color: Qt.rgba(0.08, 0.08, 0.1, 0.92)
                    border.color: Theme.hairline
                    border.width: 1
                    clip: true
                    z: 2

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: toastMode ? 15 : 13
                        asynchronous: true
                        source: mediaBox.appIconSrc
                    }
                }
            }

            ColumnLayout {
                id: textCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                // Title + dismiss flush to top (same for toast + drawer)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: (card.notif && card.notif.summary) || "Notification"
                        color: root.colFg
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: card.titlePx
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✕"
                        color: root.colMuted
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: toastMode ? 14 : 11
                        opacity: 0.7
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.ArrowCursor
                            onClicked: mouse => {
                                mouse.accepted = true;
                                root.dismissNotif(card.notif);
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    // Keep body clear of bottom-right action chips
                    Layout.rightMargin: card.hasActions ? (toastMode ? 72 : 64) : 0
                    visible: !!(card.notif && card.notif.body)
                    text: (card.notif && card.notif.body) || ""
                    color: root.colMuted
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: card.bodyPx
                    wrapMode: Text.Wrap
                    maximumLineCount: card.toastMode ? 2 : 4
                }
            }
        }

        // Action chips float bottom-right — toast + drawer; never add a layout row
        Flow {
            id: actionFlow
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: card.pad
            spacing: 4
            z: 3
            visible: card.hasActions
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: card.notif ? card.notif.actions : []
                delegate: Rectangle {
                    required property var modelData
                    width: actionLabel.implicitWidth + (toastMode ? 16 : 12)
                    height: toastMode ? 26 : 22
                    radius: toastMode ? 8 : 6
                    color: Qt.rgba(0.12, 0.12, 0.14, 0.92)
                    border.color: Theme.hairline
                    border.width: 1

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text || modelData.identifier || "Action"
                        color: root.colFg
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: toastMode ? 14 : 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.ArrowCursor
                        onClicked: mouse => {
                            mouse.accepted = true;
                            if (modelData.invoke)
                                modelData.invoke();
                        }
                    }
                }
            }
        }

        MouseArea {
            id: cardMa
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            onClicked: mouse => {
                mouse.accepted = true;
                // Toast click: hide popup only. Drawer click: dismiss from history.
                if (card.toastMode)
                    root.dropToast(card.notif);
                else
                    root.dismissNotif(card.notif);
            }
        }

        Timer {
            interval: 9000
            running: card.toastMode
            onTriggered: root.dropToast(card.notif)
        }
    }
}
