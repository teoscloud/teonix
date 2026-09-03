import qs
import QtQuick

// Panel background: base fill + animated diagonal shine (shared Theme.shinePhase)
Item {
    id: root
    property color baseColor: Theme.bgRaised
    property bool showBorder: false
    property bool showHatchTop: false
    property bool showHatchBottom: false

    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.baseColor
        radius: Theme.cornerRadius
    }

    ShineSweep {
        anchors.fill: parent
    }

    PanelHud {
        anchors.fill: parent
        z: 0
    }

    HatchBand {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 4
        visible: root.showHatchTop
        z: 1
    }

    HatchBand {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        visible: root.showHatchBottom
        z: 1
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.hairline
        border.width: root.showBorder ? Theme.hairlineWidth : 0
        radius: Theme.cornerRadius
        z: 2
    }
}
