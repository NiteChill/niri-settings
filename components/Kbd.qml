import QtQuick
import "../theme"

// HeroUI's Kbd: keys on small grey caps, e.g. keys: ["Super", "Shift", "E"]. Symbols for the usual
// modifiers (Super ❖ is written as "Super": niri users know the word). `light` drops the caps.
Row {
    id: kbd

    property var keys: []
    property bool light: false

    spacing: Theme.kbd.gap
    Repeater {
        model: kbd.keys
        Rectangle {
            required property string modelData
            height: Theme.kbd.height
            width: Math.max(height, key.implicitWidth + 2 * Theme.kbd.paddingX)
            radius: Theme.kbd.radius
            color: kbd.light ? "transparent" : Theme.c.default
            Label {
                id: key
                anchors.centerIn: parent
                text: ({ "Shift": "⇧", "Ctrl": "Ctrl", "Alt": "Alt", "Enter": "↵", "Return": "↵", "Tab": "⇥", "Backspace": "⌫", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→" })[parent.modelData] || parent.modelData
                weight: Theme.weightMedium
                color: Theme.c.muted
            }
        }
    }
}
