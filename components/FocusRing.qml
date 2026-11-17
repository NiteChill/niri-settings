import QtQuick
import "../theme"

// HeroUI's keyboard focus ring: 2 px of the focus color around its parent, `offset` px away (2 for
// buttons and switches, 0 for fields). Shown only while `shown` (bind it to the control's visualFocus,
// which is true for keyboard focus only, never for a click).
Rectangle {
    property bool shown: false
    property real offset: Theme.focusOffset
    property real baseRadius: 0

    anchors.fill: parent
    anchors.margins: -(offset + Theme.focusRing)
    radius: baseRadius + offset + Theme.focusRing
    color: "transparent"
    border.width: Theme.focusRing
    border.color: Theme.c.focus
    visible: shown
}
