import QtQuick
import qs

// Solid flake + N. Canvas so fills stay opaque at 26px (Shape hairlined).
Item {
    id: root

    property color ink: Theme.palette === "dark" ? Theme.accentHot : Theme.fg
    property color cut: Theme.palette === "dark" ? Theme.bg : Theme.bgRaised
    property int mark: 26

    width: mark
    height: mark

    onInkChanged: canvas.requestPaint()
    onCutChanged: canvas.requestPaint()
    onMarkChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Connections {
        target: Theme
        function onPaletteChanged() { canvas.requestPaint() }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            const cx = w / 2;
            const cy = h / 2;
            const m = Math.min(w, h);
            ctx.reset();
            ctx.clearRect(0, 0, w, h);

            ctx.fillStyle = root.ink;
            for (let i = 0; i < 6; i++) {
                const a = (i * 60 - 90) * Math.PI / 180;
                const nx = Math.cos(a);
                const ny = Math.sin(a);
                const px = -ny;
                const py = nx;
                const r0 = m * 0.2;
                const r1 = m * 0.48;
                const hw = m * 0.15;
                ctx.beginPath();
                ctx.moveTo(cx + nx * r0 + px * hw * 0.45, cy + ny * r0 + py * hw * 0.45);
                ctx.lineTo(cx + nx * r1 * 0.62 + px * hw, cy + ny * r1 * 0.62 + py * hw);
                ctx.lineTo(cx + nx * r1, cy + ny * r1);
                ctx.lineTo(cx + nx * r1 * 0.62 - px * hw, cy + ny * r1 * 0.62 - py * hw);
                ctx.lineTo(cx + nx * r0 - px * hw * 0.45, cy + ny * r0 - py * hw * 0.45);
                ctx.closePath();
                ctx.fill();
            }

            ctx.beginPath();
            const hr = m * 0.22;
            for (let i = 0; i <= 6; i++) {
                const a = (i * 60 - 90) * Math.PI / 180;
                const x = cx + hr * Math.cos(a);
                const y = cy + hr * Math.sin(a);
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fill();

            ctx.fillStyle = root.cut;
            const x0 = cx - m * 0.09;
            const x1 = cx + m * 0.09;
            const y0 = cy - m * 0.11;
            const y1 = cy + m * 0.11;
            const t = m * 0.048;
            ctx.beginPath();
            ctx.moveTo(x0, y0);
            ctx.lineTo(x0 + t, y0);
            ctx.lineTo(x1 - t, y1 - t * 1.6);
            ctx.lineTo(x1 - t, y0);
            ctx.lineTo(x1, y0);
            ctx.lineTo(x1, y1);
            ctx.lineTo(x1 - t, y1);
            ctx.lineTo(x0 + t, y0 + t * 1.6);
            ctx.lineTo(x0 + t, y1);
            ctx.lineTo(x0, y1);
            ctx.closePath();
            ctx.fill();
        }
    }
}
