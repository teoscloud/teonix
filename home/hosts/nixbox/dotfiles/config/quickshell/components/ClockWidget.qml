import QtQuick
import "../theme.js" as Theme

Text {
    id: clock
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    text: "󰥔 " + Qt.formatDateTime(new Date(), "ddd MMM dd hh:mm AP")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = "󰥔 " + Qt.formatDateTime(new Date(), "ddd MMM dd hh:mm AP")
    }
}
