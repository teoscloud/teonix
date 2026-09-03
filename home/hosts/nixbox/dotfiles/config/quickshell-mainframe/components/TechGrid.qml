import qs
import QtQuick

// Faint lattice. kind "diag" is a 45° diamond grid; "square" is axis-aligned.
Item {
    id: root
    property color lineColor: Theme.gridInk
    property int pitch: Theme.gridPitch
    property real opacityMul: Theme.gridOpacity
    property string kind: "square" // square | diag

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width < 1 || height < 1)
                return
            ctx.strokeStyle = root.lineColor
            ctx.globalAlpha = root.opacityMul
            ctx.lineWidth = 1
            const p = Math.max(4, root.pitch)
            ctx.beginPath()
            if (root.kind === "diag") {
                for (let x = -height; x < width + height; x += p) {
                    ctx.moveTo(x, height)
                    ctx.lineTo(x + height, 0)
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x + height, height)
                }
            } else {
                for (let x = 0; x <= width; x += p) {
                    ctx.moveTo(x + 0.5, 0)
                    ctx.lineTo(x + 0.5, height)
                }
                for (let y = 0; y <= height; y += p) {
                    ctx.moveTo(0, y + 0.5)
                    ctx.lineTo(width, y + 0.5)
                }
            }
            ctx.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onKindChanged() { canvas.requestPaint() }
        function onPitchChanged() { canvas.requestPaint() }
    }
}
