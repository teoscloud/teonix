import QtQuick
import qs

// Thin motion helper (Caelestia Anim.qml–inspired, no plugin).
NumberAnimation {
    property bool fast: false
    duration: fast ? Theme.animFast : Theme.animMed
    easing.type: Easing.OutCubic
}
