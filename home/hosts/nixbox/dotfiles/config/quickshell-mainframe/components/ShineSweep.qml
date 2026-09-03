import qs
import QtQuick

// Soft diagonal band driven by Theme.shinePhase. Canvas interpolates
// alpha; Rectangle.gradient does not (it paints a solid slab).
Item {
    id: root
    clip: true
    visible: Theme.shineEnabled
    opacity: Theme.shineOpacity * root.strength

    property real strength: 1

    Canvas {
        id: band
        width: parent.width * (0.55 + Theme.shineWidth)
        height: parent.height * 2.5
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width + width) * Theme.shinePhase - width
        rotation: Theme.shineAngle
        transformOrigin: Item.Center
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        property color ink: Theme.shineColor

        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width < 2 || height < 2)
                return;
            const r = Math.round(ink.r * 255);
            const g = Math.round(ink.g * 255);
            const b = Math.round(ink.b * 255);
            const grd = ctx.createLinearGradient(0, 0, width, 0);
            grd.addColorStop(0, "rgba(" + r + "," + g + "," + b + ",0)");
            grd.addColorStop(0.38, "rgba(" + r + "," + g + "," + b + ",0.45)");
            grd.addColorStop(0.5, "rgba(" + r + "," + g + "," + b + ",1)");
            grd.addColorStop(0.62, "rgba(" + r + "," + g + "," + b + ",0.45)");
            grd.addColorStop(1, "rgba(" + r + "," + g + "," + b + ",0)");
            ctx.fillStyle = grd;
            ctx.fillRect(0, 0, width, height);
        }
    }
}
