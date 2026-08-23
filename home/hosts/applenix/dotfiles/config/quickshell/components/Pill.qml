import QtQuick
import "../theme.js" as Theme

// Asymmetric waybar pill; clockCorner = flush top-right screen corner
Rectangle {
    id: root
    property bool hovered: false
    property bool clockCorner: false

    color: hovered ? Theme.pillHoverBg() : Theme.pillBg()

    topLeftRadius: clockCorner ? 0 : 20
    topRightRadius: clockCorner ? 0 : 12
    bottomRightRadius: clockCorner ? 0 : 20
    bottomLeftRadius: clockCorner ? 35 : 12

    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }
}
