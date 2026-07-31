import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "theme.js" as Theme
import "components"

Scope {
    id: root

    // Frost glass — wallpaper tint × blur (dock/bar stay untinted)
    readonly property color colFg: "#f7f5ff"
    readonly property color colMuted: Qt.rgba(0.97, 0.96, 1.0, 0.72)
    readonly property color colPanel: Globals.glassColor(0.55)
    readonly property color colToast: Globals.glassColor(0.60)
    readonly property color colCard: Qt.rgba(1, 1, 1, 0.08)
    readonly property color colCardHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color colBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property color colBorderSoft: Qt.rgba(1, 1, 1, 0.10)

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
        try {
            return Quickshell.iconPath(icon, true) || "";
        } catch (e) {
            return "";
        }
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

    // ---- Toasts ----
    PanelWindow {
        id: toastWin
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        // Layer-surface alpha for Hyprland frost (child cards stay translucent)
        color: root.colToast
        aboveWindows: true
        visible: toastCol.children.length > 0 && !Globals.notifDrawerOpen
        WlrLayershell.namespace: "quickshell:notifs"
        WlrLayershell.layer: WlrLayer.Top

        HyprlandWindow.visibleMask: Region {
            item: toastCol
            radius: Theme.radiusSm
        }

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + 8
            right: 12
        }

        implicitWidth: 340
        implicitHeight: Math.max(1, toastCol.implicitHeight)

        Column {
            id: toastCol
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            spacing: 6

            Repeater {
                model: root.toastQueue
                delegate: NotifCard {
                    required property var modelData
                    width: toastCol.width
                    notif: modelData
                    toastMode: true
                }
            }
        }
    }

    // Click-outside dismiss (below drawer Overlay so media clicks never hit it)
    PanelWindow {
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
        id: drawerWin
        visible: Globals.notifDrawerOpen
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        // Alpha on the layer surface itself — required for Hyprland blurls/layerrule frost
        color: root.colPanel
        aboveWindows: true
        focusable: true
        WlrLayershell.namespace: "quickshell:notifs"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandWindow.visibleMask: Region {
            item: drawerPanel
            radius: 22
        }

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + 8
            right: 12
        }

        implicitWidth: 380
        implicitHeight: 620

        Rectangle {
            id: drawerPanel
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
                        radius: 8
                        color: clearMa.containsMouse ? root.colCardHover : root.colCard
                        border.color: Qt.rgba(1, 1, 1, 0.10)
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
                    height: visible ? mediaOuter.implicitHeight + 16 : 0
                    radius: Theme.radiusSm
                    color: root.colCard
                    border.color: Qt.rgba(1, 1, 1, 0.10)
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
                        source: root.activePlayer?.trackArtUrl || ""
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
                                    radius: 3
                                    color: index === root.activePlayerIndex
                                        ? Theme.accentHot
                                        : Qt.rgba(1, 1, 1, 0.28)
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
                                        radius: 10
                                        color: root.colCard
                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: root.activePlayer?.trackArtUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !(root.activePlayer?.trackArtUrl)
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
                                        radius: 2
                                        color: Qt.rgba(1, 1, 1, 0.10)

                                        Rectangle {
                                            width: {
                                                mediaCard.posTick;
                                                const pos = toSecs(root.activePlayer?.position || 0);
                                                const len = Math.max(0.001, toSecs(root.activePlayer?.length || 1));
                                                return parent.width * Math.min(1, Math.max(0, pos / len));
                                            }
                                            height: parent.height
                                            radius: 2
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
                                    spacing: 10
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
                                        font.pixelSize: 18
                                        opacity: 0.9
                                    }

                                    Item {
                                        id: volTrack
                                        Layout.fillWidth: true
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
                                            radius: 2
                                            color: Qt.rgba(1, 1, 1, 0.12)

                                            Rectangle {
                                                width: parent.width * volTrack.vol
                                                height: parent.height
                                                radius: 2
                                                color: root.colFg
                                                opacity: 0.85
                                            }
                                        }

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
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
                                        Layout.preferredWidth: 36
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
        // Toast + drawer share the same media chrome
        readonly property int mediaSize: 52

        height: Math.max(mediaSize + 16, textCol.implicitHeight + 16)
        radius: toastMode ? 14 : 10
        color: toastMode ? root.colToast : (cardMa.containsMouse ? root.colCardHover : root.colCard)
        border.color: Qt.rgba(1, 1, 1, toastMode ? 0.14 : 0.10)
        border.width: 1

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
            anchors.margins: 8
            spacing: 10

            Rectangle {
                id: mediaBox
                Layout.preferredWidth: card.mediaSize
                Layout.preferredHeight: card.mediaSize
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: root.colCard
                border.color: Qt.rgba(1, 1, 1, 0.08)
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
                    implicitSize: 48
                    asynchronous: true
                    source: (!card.notif || mediaBox.hasInlineImage) ? "" : notifIconSource(card.notif)
                    visible: !mediaBox.hasInlineImage && status === Image.Ready && !!source
                }
                Text {
                    anchors.centerIn: parent
                    visible: !mediaBox.hasInlineImage && !nIcon.visible
                    text: "󰂚"
                    color: root.colMuted
                    font.pixelSize: 22
                }

                // Small app icon, bottom-right of main image
                Rectangle {
                    visible: mediaBox.showAppBadge
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: 18
                    height: 18
                    radius: 6
                    color: Qt.rgba(0.08, 0.08, 0.1, 0.92)
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                    clip: true
                    z: 2

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 13
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
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✕"
                        color: root.colMuted
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: 11
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
                    visible: !!(card.notif && card.notif.body)
                    text: (card.notif && card.notif.body) || ""
                    color: root.colMuted
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: card.toastMode ? 2 : 4
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: card.notif && card.notif.actions && card.notif.actions.length > 0

                    Repeater {
                        model: card.notif ? card.notif.actions : []
                        delegate: Rectangle {
                            required property var modelData
                            width: actionLabel.implicitWidth + 12
                            height: 22
                            radius: 6
                            color: root.colCardHover
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData.text || modelData.identifier || "Action"
                                color: root.colFg
                                font.family: Theme.fontFamilyUi
                                font.pixelSize: 11
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
            interval: 6000
            running: card.toastMode
            onTriggered: root.dropToast(card.notif)
        }
    }
}
