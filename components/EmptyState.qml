import QtQuick
import "../theme"

// HeroUI's EmptyState: an icon on a soft round tile, a title, a grey line under it, centred.
Column {
    id: empty

    property string iconName
    property string title
    property string description

    spacing: Theme.spacing * 3
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.spacing * 12
        height: width
        radius: width / 2
        color: Theme.c.default
        Icon {
            anchors.centerIn: parent
            name: empty.iconName
            size: 24
            color: Theme.c.muted
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacing
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: empty.title
            size: "base"
            weight: Theme.weightMedium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: empty.description
            color: Theme.c.muted
        }
    }
}
