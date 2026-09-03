import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

// Grayscale app marks with a thin opposite-ink rim so Chrome / Brave /
// Netflix keep their internals instead of collapsing to a flat blob.
Item {
    id: root

    property alias source: src.source
    property color ink: Theme.fg
    readonly property bool ready: src.status === Image.Ready && !!src.source
    readonly property bool dark: Theme.palette === "dark"
    readonly property color rimInk: dark ? "#000000" : "#ffffff"

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
        brightness: root.dark ? -0.4 : 0.3
        contrast: 0.46
        scale: 1.12
        paddingRect: Qt.rect(2, 2, 2, 2)
    }

    MultiEffect {
        anchors.fill: src
        source: src
        visible: root.ready
        saturation: -1
        colorization: 0.22
        colorizationColor: root.ink
        contrast: root.dark ? 0.75 : 0.68
        brightness: root.dark ? 0.12 : -0.12
        paddingRect: Qt.rect(2, 2, 2, 2)
    }
}
