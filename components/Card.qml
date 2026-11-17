import QtQuick
import "../theme"

// HeroUI's Card: a surface panel with 24 px corners and 16 px padding. variant: "default" (surface),
// "secondary", "tertiary" (a step lighter each), "transparent". Optional title + description at the
// top; children go below them, stacked with the card's gap.
Rectangle {
    id: card

    property string variant: "default"
    property string title
    property string description
    property real padding: Theme.card.padding
    default property alias content: body.data

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 2 * padding
    radius: Theme.card.radius
    color: variant === "secondary" ? Theme.c.surfaceSecondary : variant === "tertiary" ? Theme.c.surfaceTertiary : variant === "transparent" ? "transparent" : Theme.c.surface
    border.width: variant === "transparent" ? 0 : Theme.cardBorder
    border.color: Theme.c.border

    Column {
        id: column
        x: card.padding
        y: card.padding
        width: card.width - 2 * card.padding
        spacing: Theme.card.gap
        Column {
            visible: card.title !== "" || card.description !== ""
            width: parent.width
            Label {
                visible: card.title !== ""
                width: parent.width
                text: card.title
                weight: Theme.weightMedium
                lineHeight: 24
                lineHeightMode: Text.FixedHeight
            }
            Label {
                visible: card.description !== ""
                width: parent.width
                text: card.description
                color: Theme.c.muted
                wrapMode: Text.Wrap
            }
        }
        Column {
            id: body
            width: parent.width
            spacing: Theme.card.gap
        }
    }
}
