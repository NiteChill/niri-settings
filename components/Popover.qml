import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T
import "../theme"

// HeroUI's Popover: a floating panel in the overlay color, 24 px corners (a light 1 px edge in dark, a
// soft shadow in light). Opens with a fade + grow from 90 % and a 4 px slide away from its trigger
// (150 ms), closes faster (fade + 95 %, 100 ms). Escape or a click outside closes it.
T.Popup {
    id: popover

    // where it opens relative to its parent: below (default) or above
    property bool above: false
    property real radius: Theme.list.popoverRadius

    padding: Theme.list.popoverPadding
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent
    transformOrigin: above ? Item.Bottom : Item.Top

    background: Item {
        RectangularShadow {
            anchors.fill: parent
            visible: !Theme.dark
            radius: popover.radius
            blur: 28
            offset.y: 14
            spread: -6
            color: Theme.c.overlayShadow
        }
        Rectangle {
            anchors.fill: parent
            radius: popover.radius
            color: Theme.c.overlay
            border.width: 1
            border.color: Theme.c.overlayBorder
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeSmooth }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Theme.motion.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeSmooth }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeSmooth }
            NumberAnimation { property: "scale"; to: 0.95; duration: Theme.motion.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeSmooth }
        }
    }
}
