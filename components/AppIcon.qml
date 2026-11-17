import QtQuick
import Quickshell
import "../theme"

// An app's icon from the icon theme (`name` from its desktop file); a grey tile with its first letter
// when the theme has none.
Item {
    id: icon

    property string name
    property string fallback: "?"
    property real size: 24

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: icon.name ? Quickshell.iconPath(icon.name, true) : ""
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        radius: icon.size / 4
        color: Theme.c.default
        Label {
            anchors.centerIn: parent
            text: (icon.fallback || "?").charAt(0).toUpperCase()
            size: icon.size > 28 ? "base" : "xs"
            weight: Theme.weightSemibold
            color: Theme.c.muted
        }
    }
}
