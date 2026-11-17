import QtQuick
import "../theme"

// HeroUI's Separator: a 1 px line. variant "default" | "secondary" (a bit stronger, for use on cards).
// `vertical` for a vertical one.
Rectangle {
    property string variant: "default"
    property bool vertical: false

    implicitWidth: vertical ? 1 : 0
    implicitHeight: vertical ? 0 : 1
    color: variant === "secondary" ? Theme.c.separatorSecondary : Theme.c.separator
}
