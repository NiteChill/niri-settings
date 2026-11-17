import QtQuick
import "../theme"

// A column of Radio buttons with an optional label above: HeroUI's RadioGroup. `options` is a list of
// { value, label, description }; `value` is the chosen one's value: the page sets it, and updates it on `activated`. `horizontal` lays them out in a row.
Column {
    id: group

    property string label
    property var options: []
    property var value
    property bool horizontal: false
    signal activated(var value)

    spacing: Theme.spacing * 3

    Label {
        visible: group.label !== ""
        text: group.label
        weight: Theme.weightMedium
    }
    Grid {
        columns: group.horizontal ? Math.max(1, group.options.length) : 1
        columnSpacing: Theme.spacing * 6
        rowSpacing: Theme.spacing * 3
        Repeater {
            model: group.options
            Radio {
                required property var modelData
                text: modelData.label
                description: modelData.description || ""
                // the group decides: a click asks, `value` answers (so setting value from outside works too)
                checkable: false
                autoExclusive: false
                checked: group.value === modelData.value
                onClicked: group.activated(modelData.value)
            }
        }
    }
}
