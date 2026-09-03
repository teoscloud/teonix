import qs
import QtQuick

// Empty-flank ornament: hatch + edge scale + step corner.
// Full-width TechGrid lives on the rail wash behind this.
Item {
    id: root
    property string side: "left" // left | right

    clip: true

    HatchField {
        anchors.fill: parent
        opacityMul: Theme.hatchFieldOpacity
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.tickLen + 4
        edge: "top"
    }

    EdgeScale {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.tickLen + 3
        edge: "bottom"
        tickOpacity: 0.45
    }

    StepCorner {
        corner: root.side === "left" ? "innerRight" : "innerLeft"
        anchors.bottom: parent.bottom
        anchors.right: root.side === "left" ? parent.right : undefined
        anchors.left: root.side === "right" ? parent.left : undefined
        anchors.bottomMargin: 1
    }
}
