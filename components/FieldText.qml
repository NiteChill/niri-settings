import QtQuick
import "../theme"

// What goes around a field: its label above, and under it either a grey description or, when there's
// an error, the error in red (HeroUI hides the description then). The field itself is the default child.
Column {
    id: wrap

    property string label
    property string description
    property string errorMessage
    property bool required: false
    default property alias field: slot.data

    spacing: Theme.field.gap

    Label {
        visible: wrap.label !== ""
        text: wrap.label + (wrap.required ? " *" : "")
        weight: Theme.weightMedium
        color: wrap.errorMessage !== "" ? Theme.c.danger : Theme.c.foreground
    }
    Item {
        id: slot
        width: wrap.width
        height: childrenRect.height
    }
    Label {
        visible: wrap.errorMessage !== "" || wrap.description !== ""
        width: wrap.width
        text: wrap.errorMessage !== "" ? wrap.errorMessage : wrap.description
        size: "xs"
        color: wrap.errorMessage !== "" ? Theme.c.danger : Theme.c.muted
        wrapMode: Text.Wrap
    }
}
