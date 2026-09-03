import qs
import QtQuick

// Themed context menu — hairline + hatch, no stock Qt chrome
Item {
    id: root
    property var items: [] // [{ label, action, danger?, visible? }]
    property bool open: false
    property real menuX: 0
    property real menuY: 0

    signal triggered(int index)

    function popup(x, y) {
        menuX = x
        menuY = y
        open = true
    }

    function close() {
        open = false
    }

    visible: open
    z: 9999

    // Scrim
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
    }

    MainframeReveal {
        id: reveal
        revealed: root.open
        x: Math.min(root.menuX, root.width - panel.width - 8)
        y: Math.min(root.menuY, root.height - panel.height - 8)
        width: panel.width
        height: panel.height

        MainframeSurface {
            id: panel
            width: col.implicitWidth + 20
            height: col.implicitHeight + 16
            showHatchTop: true
            baseColor: Theme.bgRaised

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 2
                width: Math.max(140, implicitWidth)

                Repeater {
                    model: root.items
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: col.width
                        height: visible ? 28 : 0
                        visible: modelData.visible !== false

                        Rectangle {
                            anchors.fill: parent
                            color: ma.containsMouse ? Theme.bgSelected : "transparent"
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label || ""
                            color: modelData.danger ? Theme.danger : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.triggered(index)
                                if (typeof modelData.action === "function")
                                    modelData.action()
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
