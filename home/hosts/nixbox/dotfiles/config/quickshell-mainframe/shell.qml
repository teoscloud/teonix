//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "components"

ShellRoot {
    id: root

    IpcHandler {
        target: "mixer"
        function toggle(): void { Globals.toggleMixer(); }
        function open(): void { Globals.openMixer(); }
        function close(): void { Globals.closeMixer(); }
    }

    // Mainframe folds power into the start block — there is no separate PowerMenu
    IpcHandler {
        target: "power"
        function toggle(): void { Globals.togglePower(); }
        function open(): void { Globals.startMenuOpen = true; }
        function close(): void { Globals.startMenuOpen = false; }
    }

    IpcHandler {
        target: "notifs"
        function toggle(): void { Globals.toggleNotifs(); }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { Globals.toggleLauncher(); }
        function open(): void { Globals.openLauncher(); }
        function close(): void { Globals.closeLauncher(); }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { Globals.toggleEmoji(); }
        function open(): void { Globals.openEmoji(); }
        function close(): void { Globals.closeEmoji(); }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void { Theme.toggle(); }
        function set(id: string): void { Theme.setPalette(id); }
    }

    TopStrip {}
    SessionRail {}
    MixerPanel {}
    NotificationCenter {}
    StartMenu {}
    Launcher {}
    EmojiPicker {}

    // Global context menu host
    PanelWindow {
        visible: Globals.ctxMenuOpen
        screen: Globals.shellScreen
        exclusiveZone: 0
        color: "transparent"
        aboveWindows: true
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        MainframeMenu {
            anchors.fill: parent
            open: Globals.ctxMenuOpen
            items: Globals.ctxMenuItems
            menuX: Globals.ctxMenuX
            menuY: Globals.ctxMenuY
            onOpenChanged: if (!open) Globals.ctxMenuOpen = false
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Globals.ctxMenuOpen = false
        }
    }
}
