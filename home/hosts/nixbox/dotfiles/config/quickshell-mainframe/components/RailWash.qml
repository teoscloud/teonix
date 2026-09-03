import qs
import QtQuick

// Full-span rail lattice — grid plus edge rice so it does not read as a bare graph paper.
Item {
    id: root
    anchors.fill: parent
    clip: true

    TechGrid {
        anchors.fill: parent
        kind: "square"
        lineColor: Theme.gridInk
        opacityMul: Theme.gridOpacity
    }

    HatchField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 4
        stripeColor: Theme.gridInk
        opacityMul: 0.22
    }

    HatchField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        stripeColor: Theme.gridInk
        opacityMul: 0.22
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.tickLen + 4
        edge: "top"
        tickColor: Theme.fgMuted
        tickOpacity: 0.7
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.tickLen + 4
        edge: "bottom"
        tickColor: Theme.fgMuted
        tickOpacity: 0.6
    }

    EdgeScale {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Theme.tickLen + 3
        edge: "left"
        tickColor: Theme.fgMuted
        tickOpacity: 0.5
    }

    EdgeScale {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Theme.tickLen + 3
        edge: "right"
        tickColor: Theme.fgMuted
        tickOpacity: 0.5
    }

    PixelCluster {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
    }

    PixelCluster {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 8
    }

    StepCorner {
        corner: "innerLeft"
        stepColor: Theme.fgMuted
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 1
    }

    StepCorner {
        corner: "bottomRight"
        stepColor: Theme.fgMuted
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 1
    }
}
