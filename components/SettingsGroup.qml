import QtQuick
import "../theme"
import "../services"

// A titled group of settings rows on one card (GNOME's boxed list, in HeroUI's look): an optional title
// and description above the card; the rows inside are separated by faint lines (each SettingsRow draws
// its own, except the first).
Column {
    id: group

    property string title
    // a setting of the Dynamic Island: shown only when it's installed (Island.installed). An instance that
    // sets its own `visible` adds `Island.installed &&` itself; bin/settings-index.py tags these.
    property bool islandOnly: false
    visible: !islandOnly || Island.installed
    property string description
    default property alias rows: list.data

    spacing: Theme.spacing * 2

    Column {
        visible: group.title !== "" || group.description !== ""
        width: parent.width
        leftPadding: Theme.spacing
        spacing: Theme.spacing / 2
        Label {
            visible: group.title !== ""
            text: group.title
            weight: Theme.weightSemibold
        }
        Label {
            visible: group.description !== ""
            width: parent.width - parent.leftPadding
            text: group.description
            color: Theme.c.muted
            wrapMode: Text.Wrap
        }
    }
    Rectangle {
        width: parent.width
        height: list.implicitHeight
        radius: Theme.card.radius
        color: Theme.c.surface
        border.width: Theme.cardBorder
        border.color: Theme.c.border
        Column {
            id: list
            // rows find their group's list by this name (SettingsRow.first)
            objectName: "settingsList"
            width: parent.width
        }
    }
}
