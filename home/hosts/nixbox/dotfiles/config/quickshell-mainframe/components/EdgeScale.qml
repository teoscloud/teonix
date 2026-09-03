import qs
import QtQuick

// Ruler ticks along one edge of a plate. TickRule stays the short inline cluster.
Item {
    id: root
    property string edge: "top" // top | bottom | left | right
    property color tickColor: Theme.hatchFg
    property int pitch: Theme.edgeScalePitch
    property int shortLen: Theme.tickLen
    property int longLen: Theme.tickLen + 3
    property int longEvery: 5
    property real tickOpacity: 0.7

    readonly property bool horizontal: edge === "top" || edge === "bottom"

    implicitWidth: horizontal ? 40 : longLen
    implicitHeight: horizontal ? longLen : 40

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width < 1 || height < 1)
                return
            ctx.strokeStyle = root.tickColor
            ctx.globalAlpha = root.tickOpacity
            ctx.lineWidth = 1
            const p = Math.max(3, root.pitch)
            const longN = Math.max(2, root.longEvery)
            if (root.horizontal) {
                const alongTop = root.edge === "top"
                let i = 0
                for (let x = 0; x <= width; x += p) {
                    const len = (i % longN === 0) ? root.longLen : root.shortLen
                    const y0 = alongTop ? 0 : height
                    const y1 = alongTop ? len : height - len
                    ctx.beginPath()
                    ctx.moveTo(x + 0.5, y0)
                    ctx.lineTo(x + 0.5, y1)
                    ctx.stroke()
                    i++
                }
            } else {
                const alongLeft = root.edge === "left"
                let i = 0
                for (let y = 0; y <= height; y += p) {
                    const len = (i % longN === 0) ? root.longLen : root.shortLen
                    const x0 = alongLeft ? 0 : width
                    const x1 = alongLeft ? len : width - len
                    ctx.beginPath()
                    ctx.moveTo(x0, y + 0.5)
                    ctx.lineTo(x1, y + 0.5)
                    ctx.stroke()
                    i++
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onEdgeChanged() { canvas.requestPaint() }
        function onPitchChanged() { canvas.requestPaint() }
        function onTickColorChanged() { canvas.requestPaint() }
    }
}
