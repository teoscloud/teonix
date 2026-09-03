import qs
import QtQuick

Item {
    id: root
    property color stripeColor: Theme.hatchFg
    property color baseColor: Theme.hatch
    property int pitch: Theme.hatchPitch
    property real opacityMul: 0.55

    Rectangle {
        anchors.fill: parent
        color: root.baseColor
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.stripeColor
            ctx.globalAlpha = root.opacityMul
            ctx.lineWidth = 1
            const p = Math.max(3, root.pitch)
            for (let x = -height; x < width + height; x += p) {
                ctx.beginPath()
                ctx.moveTo(x, height)
                ctx.lineTo(x + height, 0)
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
