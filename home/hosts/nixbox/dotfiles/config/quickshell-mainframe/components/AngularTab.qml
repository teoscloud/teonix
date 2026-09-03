import QtQuick
import Quickshell.Widgets
import qs

// Top-strip window tab: square, with the top-left corner sliced off.
Item {
    id: root

    property string title: ""
    property string iconPath: ""
    property string fallbackGlyph: "?"
    property bool isActive: false
    // When set, the tab fills this width instead of hugging the title.
    property real slotWidth: 0

    signal activated()

    readonly property real slice: Theme.tabSlice
    readonly property real padL: Theme.pad + 2
    readonly property real padR: Theme.pad
    readonly property bool hovered: ma.containsMouse

    // Idle tabs ride lower so the focused tab stands proud of the row
    property real topInset: isActive ? 0 : Theme.moduleInset

    Behavior on topInset {
        NumberAnimation { duration: Theme.animMed }
    }

    implicitWidth: slotWidth > 0
        ? slotWidth
        : Math.min(Theme.tabMaxWidth, Math.max(Theme.tabMinWidth, inner.implicitWidth + padL + padR))
    implicitHeight: parent ? parent.height : Theme.barHeight
    width: implicitWidth

    Item {
        id: frame
        anchors.fill: parent
        anchors.topMargin: root.topInset

        MfShape {
            anchors.fill: parent
            kind: "sliceTL"
            slant: root.slice
            fillColor: root.isActive ? Theme.trayPlate
                : (root.hovered ? Qt.lighter(Theme.groupWell, 1.08) : Theme.groupWell)
            strokeColor: "transparent"
            strokeWidth: 0

            Behavior on fillColor { ColorAnimation { duration: Theme.animMed } }
            Behavior on strokeColor { ColorAnimation { duration: Theme.animMed } }
        }

        ShineSweep {
            anchors.fill: parent
            visible: root.isActive && Theme.shineEnabled
            strength: 1.35
        }

        // Reticle marks skip the sliced corner
        CornerBrackets {
            anchors.fill: parent
            markColor: Theme.accentHot
            len: 4
            inset: 2
            topLeft: false
            bottomLeft: false
            bottomRight: false
            opacity: root.isActive ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        }

        Row {
            id: inner
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padL
            spacing: 6

            IconImage {
                id: ico
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17
                asynchronous: true
                source: root.iconPath
                visible: status === Image.Ready && !!source
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !ico.visible
                text: root.fallbackGlyph
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBar
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, root.width - root.padL - root.padR - x)
                elide: Text.ElideRight
                text: root.title
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBar
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: 5
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: root.activated()
    }
}
