import QtQuick
import "../theme"
import "../services"
import "../components"

// The Dynamic Island page for people who don't have it (Island.installed false; SETTINGS_NO_ISLAND=1 shows
// it anyway): stills of the real island over your wallpaper, what it brings, and where to get it. Its settings
// (IslandPage) take this page's place once it's installed. The button opens Env.islandHomepage; until
// there is one, it does nothing.
Column {
    id: page
    spacing: Theme.spacing * 8

    IslandGallery {
        width: parent.width
    }

    Column {
        width: parent.width
        spacing: Theme.spacing * 2
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Dynamic Island"
            size: "2xl"
            weight: Theme.weightSemibold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "A living bar at the top of your screen. It shows the time and what matters, and grows into what you need: search, quick settings, your music, notifications."
            color: Theme.c.muted
        }
    }

    // what it brings
    Grid {
        id: features
        width: parent.width
        columns: width > 560 ? 2 : 1
        columnSpacing: Theme.spacing * 3
        rowSpacing: Theme.spacing * 3
        readonly property real cell: (width - (columns - 1) * columnSpacing) / columns
        Repeater {
            model: [
                ["search", "Search everything", "Apps, files, settings, calculations and the web, from one shortcut."],
                ["island-gauge-balanced", "Quick settings", "Wi-Fi, Bluetooth, Focus, sound and brightness, a click away."],
                ["island-music-note", "Now playing", "The song, its cover and its controls, with bars that move to the music."],
                ["island-notifications", "Calm alerts", "Notifications, the battery and your headphones, shown briefly and softly."]
            ]
            Rectangle {
                required property var modelData
                width: features.cell
                height: Theme.spacing * 24
                radius: Theme.card.radius
                color: Theme.c.surface
                border.width: Theme.cardBorder
                border.color: Theme.c.border
                Rectangle {
                    id: badge
                    x: Theme.card.padding
                    y: Theme.card.padding
                    width: 40
                    height: 40
                    radius: 12
                    color: Theme.c.accentSoft
                    Icon {
                        anchors.centerIn: parent
                        name: modelData[0]
                        size: 22
                        color: Theme.c.accent
                    }
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: Theme.spacing * 3
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.card.padding
                    y: Theme.card.padding
                    spacing: Theme.spacing
                    Label {
                        width: parent.width
                        text: modelData[1]
                        weight: Theme.weightSemibold
                    }
                    Label {
                        width: parent.width
                        text: modelData[2]
                        color: Theme.c.muted
                        size: "sm"
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // where to get it
    Column {
        width: parent.width
        spacing: Theme.spacing * 2
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            size: "lg"
            iconName: "download-fill"
            text: "Get the Dynamic Island"
            onClicked: if (Env.islandHomepage !== "") Env.launch(["xdg-open", Env.islandHomepage])
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Free and open source. Its settings appear here once it's installed."
            color: Theme.c.muted
            size: "sm"
        }
    }
}
