//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    IpcHandler {
        target: "mixer"
        function toggle(): void { Globals.toggleMixer(); }
        function open(): void { Globals.openMixer(); }
        function close(): void { Globals.closeMixer(); }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Globals.togglePower(); }
        function open(): void { Globals.powerMenuOpen = true; }
        function close(): void { Globals.powerMenuOpen = false; }
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

    Bar {}
    Dock {}
    ScrollStrip {}
    MixerPanel {}
    NotificationCenter {}
    PowerMenu {}
    Launcher {}
    EmojiPicker {}
}
