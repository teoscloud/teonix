import qs
import QtQuick

// Tab / chip chrome with top-left 45° cut (angular, not a square)
Item {
    id: root
    property color fill: Theme.bgSelected
    property color stroke: Theme.hairline
    property int cut: 8
    property bool showStroke: true

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            const c = Math.min(root.cut, width * 0.45, height * 0.45)
            ctx.beginPath()
            ctx.moveTo(c, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.lineTo(0, c)
            ctx.closePath()
            ctx.fillStyle = root.fill
            ctx.fill()
            if (root.showStroke) {
                ctx.strokeStyle = root.stroke
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    onFillChanged: canvas.requestPaint()
    onStrokeChanged: canvas.requestPaint()
    onCutChanged: canvas.requestPaint()
}
