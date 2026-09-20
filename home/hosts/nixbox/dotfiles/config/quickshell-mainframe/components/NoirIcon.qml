import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

// Grayscale app marks with a thin opposite-ink rim so Chrome / Brave /
// Netflix keep their internals instead of collapsing to a flat blob.
// Dark: lift the face toward paper ink (the old 0.22 colorization left
// hicolor glyphs as mid-grey mush on the charcoal rail).
Item {
    id: root

    property alias source: src.source
    property color ink: Theme.fg
    readonly property bool ready: src.status === Image.Ready && !!src.source
    readonly property bool dark: Theme.palette === "dark"
    readonly property color rimInk: dark ? "#050608" : "#ffffff"

    IconImage {
        id: src
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: src
        source: src
        visible: root.ready
        saturation: -1
        colorization: 1
        colorizationColor: root.rimInk
        brightness: root.dark ? -0.62 : 0.34
        contrast: root.dark ? 0.58 : 0.5
        scale: 1.14
        paddingRect: Qt.rect(2, 2, 2, 2)
    }

    MultiEffect {
        anchors.fill: src
        source: src
        visible: root.ready
        saturation: -1
        colorization: root.dark ? 0.62 : 0.38
        colorizationColor: root.ink
        contrast: root.dark ? 0.94 : 0.78
        brightness: root.dark ? 0.34 : -0.14
        paddingRect: Qt.rect(2, 2, 2, 2)
    }
}
