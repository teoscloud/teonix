import qs
import QtQuick

// TL→BR expand/collapse from midpoint scale (top-left origin)
Item {
    id: root
    property bool revealed: false
    property real startScale: Theme.revealStartScale
    property int durationMs: Theme.revealMs
    property int origin: Item.TopLeft

    opacity: revealed ? 1 : 0
    scale: revealed ? 1 : startScale
    transformOrigin: origin
    visible: opacity > 0.01 || revealAnim.running || scaleAnim.running

    Behavior on opacity {
        NumberAnimation {
            id: revealAnim
            duration: Theme.shineEnabled ? root.durationMs : 80
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            id: scaleAnim
            duration: Theme.shineEnabled ? root.durationMs : 80
            easing.type: Easing.OutCubic
        }
    }
}
