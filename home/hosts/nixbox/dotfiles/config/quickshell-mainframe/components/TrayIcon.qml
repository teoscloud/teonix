import QtQuick
import Quickshell.Widgets
import qs

// Tray glyph that survives either palette.
//
// Icon *names* are re-themed upstream (Globals.trayIconSource). Apps that hand
// over a fixed pixmap instead draw it for whichever tray they were designed
// against, so a white glyph vanishes on the light bar and a black one on the
// dark bar. Such a pixmap is measured once — mean luminance and saturation over
// its opaque pixels — and re-inked in the palette's foreground when it is
// monochrome and too close to the panel behind it. Anything with real colour is
// left exactly as the app drew it.
Item {
    id: root

    property string source: ""
    property bool adapt: false
    property int size: Theme.trayIcon
    property color ink: Theme.fg

    property bool measured: false
    property real lum: -1
    property real sat: -1

    readonly property bool monochrome: measured && sat < 0.2
    readonly property bool reInked: adapt && monochrome
        && (Theme.mode === "dark" ? lum < 0.4 : lum > 0.6)

    implicitWidth: size
    implicitHeight: size

    onSourceChanged: {
        measured = false;
        probe.reload();
    }

    onAdaptChanged: probe.repaintSoon()
    onReInkedChanged: probe.repaintSoon()
    onInkChanged: probe.repaintSoon()

    IconImage {
        anchors.fill: parent
        asynchronous: true
        source: root.source
        opacity: root.reInked ? 0 : 1
    }

    // Kept in the scene at zero opacity when unused: an invisible Canvas never
    // paints, and painting is what measures the glyph.
    Canvas {
        id: probe
        anchors.fill: parent
        opacity: root.reInked ? 1 : 0
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        function reload() {
            if (!root.source)
                return;
            if (isImageLoaded(root.source))
                requestPaint();
            else if (!isImageLoading(root.source))
                loadImage(root.source);
        }

        // A repaint asked for from inside onPaint has to land on a later tick
        function repaintSoon() {
            Qt.callLater(requestPaint);
        }

        onImageLoaded: requestPaint()
        Component.onCompleted: reload()

        onPaint: {
            if (width < 2 || height < 2 || !root.source || !isImageLoaded(root.source))
                return;
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(root.source, 0, 0, width, height);

            if (!root.measured) {
                const px = ctx.getImageData(0, 0, width, height).data;
                let n = 0;
                let lumSum = 0;
                let satSum = 0;
                for (let i = 0; i < px.length; i += 4) {
                    if (px[i + 3] < 40)
                        continue;
                    const r = px[i] / 255;
                    const g = px[i + 1] / 255;
                    const b = px[i + 2] / 255;
                    const mx = Math.max(r, g, b);
                    const mn = Math.min(r, g, b);
                    lumSum += 0.299 * r + 0.587 * g + 0.114 * b;
                    satSum += mx > 0 ? (mx - mn) / mx : 0;
                    n++;
                }
                if (n < 1)
                    return;
                root.lum = lumSum / n;
                root.sat = satSum / n;
                root.measured = true;
                repaintSoon();
                return;
            }

            if (!root.reInked)
                return;

            // source-in keeps the glyph's alpha and replaces its colour, which is
            // the whole shape for a monochrome pixmap.
            ctx.globalCompositeOperation = "source-in";
            ctx.fillStyle = root.ink;
            ctx.fillRect(0, 0, width, height);
            ctx.globalCompositeOperation = "source-over";
        }
    }

    Connections {
        target: Theme
        function onPaletteChanged() { probe.repaintSoon() }
    }
}
