pragma Singleton
import Quickshell
import QtQuick

Singleton {
    property bool mixerOpen: false
    property bool notifDrawerOpen: false
    property bool powerMenuOpen: false
    property int notifCount: 0

    // Resolve against the active shell tree (works with qs -p and HM symlink)
    readonly property string buschainWaybar: Quickshell.shellPath("scripts/qs-buschain-waybar.sh")
    readonly property string buschainCtl: Quickshell.shellPath("scripts/qs-buschain-ctl.sh")

    function toggleMixer() {
        mixerOpen = !mixerOpen;
        if (mixerOpen) {
            notifDrawerOpen = false;
            powerMenuOpen = false;
        }
    }

    function openMixer() {
        mixerOpen = true;
        notifDrawerOpen = false;
        powerMenuOpen = false;
    }

    function closeMixer() {
        mixerOpen = false;
    }

    function toggleNotifs() {
        notifDrawerOpen = !notifDrawerOpen;
        if (notifDrawerOpen) {
            mixerOpen = false;
            powerMenuOpen = false;
        }
    }

    function togglePower() {
        powerMenuOpen = !powerMenuOpen;
        if (powerMenuOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
        }
    }

    function closeOverlays() {
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
    }
}
