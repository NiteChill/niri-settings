import QtQuick
import "../theme"

// The box every field draws (text, search, number, select): 36 px tall, 12 px corners. variant:
// "secondary" (grey, for fields on cards: the default here, since settings sit on cards) or "primary"
// (the field color, for fields on the window background). Lighter on hover; while `focused`, a 2 px
// focus ring right against it; `invalid`: a 1 px red outline (2 px while focused).
Rectangle {
    id: frame

    property string variant: "secondary"
    property bool hovered: false
    property bool focused: false
    property bool invalid: false

    implicitHeight: Theme.field.height
    radius: Theme.field.radius
    color: variant === "primary" ? (hovered && !focused ? Theme.c.fieldHover : Theme.c.field) : (hovered && !focused ? Theme.c.defaultHover : Theme.c.default)
    Behavior on color {
        ColorAnimation {
            duration: Theme.motion.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeSmooth
        }
    }

    // focus ring, or the invalid outline
    Rectangle {
        readonly property real w: frame.focused ? Theme.focusRing : (frame.invalid ? 1 : 0)
        anchors.fill: parent
        anchors.margins: -w
        radius: frame.radius + w
        color: "transparent"
        border.width: w
        border.color: frame.invalid ? Theme.c.danger : Theme.c.focus
        visible: w > 0
    }
}
