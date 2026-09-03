import qs
import QtQuick

// Extra HUD chrome for a raised wedge plate (top-right stats / bottom-right tray).
// Inset past the slant so marks sit on the plate, not in the cut.
Item {
    id: root
    property string clipKind: ""
    property real clipSlant: 0
    clip: root.clipKind === ""

    HatchField {
        anchors.fill: parent
        stripeColor: Theme.fgMuted
        opacityMul: 0.22
        clipKind: root.clipKind
        clipSlant: root.clipSlant
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.tickLen + 3
        edge: "top"
        tickColor: Theme.fgMuted
        tickOpacity: 0.7
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.tickLen + 3
        edge: "bottom"
        tickColor: Theme.fgMuted
        tickOpacity: 0.55
    }

    EdgeScale {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Theme.tickLen + 3
        edge: "left"
        tickColor: Theme.fgMuted
        tickOpacity: 0.6
    }

    PixelCluster {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 3
        anchors.leftMargin: Theme.tickLen + 6
    }

    StepCorner {
        corner: "innerLeft"
        stepColor: Theme.fgMuted
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: 1
    }
}
