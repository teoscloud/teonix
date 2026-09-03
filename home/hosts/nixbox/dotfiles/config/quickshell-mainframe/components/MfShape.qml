import QtQuick
import QtQuick.Shapes
import qs

// Angular chrome primitive — every mainframe panel derives from this.
// Vector-backed (not Canvas) so slant/width stay smooth while animating.
//
//   oct     all four corners cut        ⯃
//   sliceTL square, top-left cut only   ◸▔
//   para    both side edges lean right  ▱
//   hex     pointed left + right ends   ⬡
//   slantL  left edge cut               ◤▔
//   slantR  right edge cut ( / )        ▔◥
//   slantRBack right edge cut ( \ )     ◥▔
//   chamfer top-left + bottom-right cut
//   rect    plain
Item {
    id: root

    property string kind: "oct"
    property real slant: Theme.octCut
    property color fillColor: Theme.bgRaised
    property color strokeColor: Theme.hairline
    property real strokeWidth: Theme.hairlineWidth
    property real shapeOpacity: 1

    readonly property var points: {
        const w = Math.max(1, width)
        const h = Math.max(1, height)

        if (kind === "oct") {
            // Corner cuts must survive on both axes or the octagon degenerates
            const c = Math.max(0, Math.min(slant, w * 0.4, h * 0.4))
            return [Qt.point(c, 0), Qt.point(w - c, 0), Qt.point(w, c), Qt.point(w, h - c),
                    Qt.point(w - c, h), Qt.point(c, h), Qt.point(0, h - c), Qt.point(0, c),
                    Qt.point(c, 0)]
        }

        const s = Math.max(0, Math.min(slant, w * 0.5))

        if (kind === "sliceTL")
            return [Qt.point(s, 0), Qt.point(w, 0), Qt.point(w, h), Qt.point(0, h), Qt.point(0, s), Qt.point(s, 0)]
        if (kind === "hex")
            return [Qt.point(s, 0), Qt.point(w - s, 0), Qt.point(w, h / 2), Qt.point(w - s, h), Qt.point(s, h), Qt.point(0, h / 2), Qt.point(s, 0)]
        if (kind === "slantL")
            return [Qt.point(s, 0), Qt.point(w, 0), Qt.point(w, h), Qt.point(0, h), Qt.point(s, 0)]
        if (kind === "slantR")
            return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w - s, h), Qt.point(0, h), Qt.point(0, 0)]
        if (kind === "slantRBack")
            return [Qt.point(0, 0), Qt.point(w - s, 0), Qt.point(w, h), Qt.point(0, h), Qt.point(0, 0)]
        if (kind === "chamfer")
            return [Qt.point(s, 0), Qt.point(w, 0), Qt.point(w, h - s), Qt.point(w - s, h), Qt.point(0, h), Qt.point(0, s), Qt.point(s, 0)]
        if (kind === "rect")
            return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w, h), Qt.point(0, h), Qt.point(0, 0)]
        return [Qt.point(s, 0), Qt.point(w, 0), Qt.point(w - s, h), Qt.point(0, h), Qt.point(s, 0)]
    }

    Shape {
        anchors.fill: parent
        opacity: root.shapeOpacity
        asynchronous: false

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            PathPolyline { path: root.points }
        }
    }
}
