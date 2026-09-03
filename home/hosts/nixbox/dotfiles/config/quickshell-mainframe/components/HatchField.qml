import qs
import QtQuick

// Diagonal caution stripes with no opaque base — wash overlay only.
Item {
    id: root
    property color stripeColor: Theme.hatchFg
    property int pitch: Theme.hatchPitch
    property real opacityMul: Theme.hatchFieldOpacity
    // Match MfShape so stripes fill a wedge, not a rectangle that stops at the cut.
    property string clipKind: ""
    property real clipSlant: 0

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width < 1 || height < 1)
                return
            const s = Math.max(0, Math.min(root.clipSlant, width * 0.5))
            if (root.clipKind === "slantRBack" && s > 0) {
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width - s, 0)
                ctx.lineTo(width, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.clip()
            } else if (root.clipKind === "slantL" && s > 0) {
                ctx.beginPath()
                ctx.moveTo(s, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.clip()
            }
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

    onClipKindChanged: canvas.requestPaint()
    onClipSlantChanged: canvas.requestPaint()
}
