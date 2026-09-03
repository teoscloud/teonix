import qs
import QtQuick

Row {
    id: root
    property color ink: Theme.fgMuted
    property int count: 3
    property int px: 2
    spacing: 2

    Repeater {
        model: root.count
        Rectangle {
            width: root.px
            height: root.px
            color: root.ink
            opacity: 0.75
        }
    }
}
