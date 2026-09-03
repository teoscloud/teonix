import QtQuick
import qs

// One selection marker for a whole strip: it slides and resizes onto the
// focused cell rather than every cell drawing its own selected state, so a
// switch reads as continuous travel instead of two independent fades.
Item {
    id: root

    property real targetX: 0
    property real targetW: 0
    property color fillColor: Theme.bgSelected
    property color edgeColor: Theme.accentHot
    property real cut: Theme.octCut
    // Dock wells are tight — skip the inner oct / edge bars so the glyph
    // keeps a ring of plate around it instead of sitting in the ornaments.
    property bool ornaments: true

    readonly property bool shown: targetW > 1
    // 1 right after a jump, decaying — drives the arrival accents
    property real flash: 0

    x: targetX
    width: targetW
    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on x {
        NumberAnimation {
            duration: Theme.motionOff ? 0 : Theme.animSpring
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.motionOff ? 0 : Theme.animSpring
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.animFast }
    }

    onTargetXChanged: arrival.restart()
    onTargetWChanged: arrival.restart()

    SequentialAnimation {
        id: arrival
        running: false
        NumberAnimation { target: root; property: "flash"; to: 1; duration: 80 }
        NumberAnimation {
            target: root
            property: "flash"
            to: 0
            duration: 460
            easing.type: Easing.OutCubic
        }
    }

    MfShape {
        anchors.fill: parent
        kind: "oct"
        slant: root.cut
        fillColor: root.fillColor
        strokeColor: root.edgeColor
        strokeWidth: Theme.strokeActive
    }

    // Inner outline brightens as the marker lands
    MfShape {
        visible: root.ornaments
        anchors.fill: parent
        anchors.margins: 3
        kind: "oct"
        slant: Math.max(3, root.cut - 2)
        fillColor: "transparent"
        strokeColor: Theme.accent
        strokeWidth: 1
        shapeOpacity: 0.3 + 0.55 * root.flash
    }

    // Leading/trailing edge bars flare on arrival
    Repeater {
        model: root.ornaments ? 2 : 0

        Rectangle {
            required property int index
            width: 2
            height: parent.height - 2 * root.cut
            anchors.verticalCenter: parent.verticalCenter
            x: index === 0 ? 2 : parent.width - width - 2
            color: root.edgeColor
            opacity: 0.25 + 0.75 * root.flash
        }
    }

    CornerBrackets {
        visible: root.ornaments
        anchors.fill: parent
        anchors.leftMargin: root.cut - 3
        anchors.rightMargin: root.cut - 3
        markColor: root.edgeColor
        len: 4
        inset: 1
    }

    // Slow scan so the focused cell keeps a pulse even when idle
    Item {
        anchors.fill: parent
        anchors.leftMargin: root.cut
        anchors.rightMargin: root.cut
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        clip: true
        visible: !Theme.motionOff

        Rectangle {
            id: sweep
            width: 1
            height: parent.height
            color: root.edgeColor
            opacity: 0.45
            x: -2
        }

        SequentialAnimation {
            running: !Theme.motionOff
            loops: Animation.Infinite
            NumberAnimation {
                target: sweep
                property: "x"
                from: -2
                to: Math.max(0, root.width)
                duration: 1500
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 2500 }
        }
    }
}
