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

    Bar {}
    Dock {}
    MixerPanel {}
    NotificationCenter {}
    PowerMenu {}
}
