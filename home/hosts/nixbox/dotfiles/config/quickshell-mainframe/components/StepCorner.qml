import qs
import QtQuick

// 3-step pixel stair where a wedge meets the empty wash.
Item {
    id: root
    property color stepColor: Theme.hatchFg
    property int step: 4
    property int steps: 3
    // inner-right (faces cluster from the left fill) or inner-left
    property string corner: "innerRight" // innerRight | innerLeft | bottomRight | bottomLeft

    implicitWidth: step * steps
    implicitHeight: step * steps

    Repeater {
        model: root.steps

        Rectangle {
            required property int index
            color: root.stepColor
            opacity: 0.55
            width: root.step
            height: root.step
            x: {
                if (root.corner === "innerRight" || root.corner === "bottomRight")
                    return (root.steps - 1 - index) * root.step
                return index * root.step
            }
            y: {
                if (root.corner === "innerRight" || root.corner === "innerLeft")
                    return index * root.step
                return (root.steps - 1 - index) * root.step
            }
        }
    }
}
