import qs
import QtQuick

// HUD frame that hugs overlay plates — grid, hatch caps, ticks, brackets, pixels.
Item {
    id: root
    anchors.fill: parent
    clip: true

    TechGrid {
        anchors.fill: parent
        kind: "square"
        lineColor: Theme.overlayGridInk
        opacityMul: Theme.overlayGridOpacity
    }

    HatchField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 5
        stripeColor: Theme.gridInk
        opacityMul: 0.22
    }

    HatchField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 5
        stripeColor: Theme.gridInk
        opacityMul: 0.2
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.tickLen + 4
        edge: "top"
        tickColor: Theme.fgMuted
        tickOpacity: 0.75
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.tickLen + 4
        edge: "bottom"
        tickColor: Theme.fgMuted
        tickOpacity: 0.65
    }

    EdgeScale {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Theme.tickLen + 3
        edge: "left"
        tickColor: Theme.fgMuted
        tickOpacity: 0.55
    }

    EdgeScale {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Theme.tickLen + 3
        edge: "right"
        tickColor: Theme.fgMuted
        tickOpacity: 0.55
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        color: "transparent"
        border.color: Theme.hairline
        border.width: 1
        opacity: 0.45
    }

    CornerBrackets {
        anchors.fill: parent
        markColor: Theme.fgMuted
        len: 7
        inset: 2
    }

    PixelCluster {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 8
    }

    StepCorner {
        corner: "innerLeft"
        stepColor: Theme.fgMuted
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 2
    }

    StepCorner {
        corner: "bottomRight"
        stepColor: Theme.fgMuted
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 2
    }
}
