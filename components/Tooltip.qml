import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's Tooltip: a small overlay-colored bubble (12 px corners, 8 px padding, xs text) above its
// parent after hovering a moment. Put one inside the item it explains and bind `shown` to its hover:
//   Tooltip { text: "…"; shown: hover.hovered }
T.ToolTip {
    id: tip

    property bool shown: false

    visible: shown && text !== ""
    delay: Theme.tooltip.delay
    padding: Theme.tooltip.padding
    x: (parent ? parent.width - width : 0) / 2
    y: -height - Theme.spacing * 2
    closePolicy: T.Popup.NoAutoClose

    contentItem: Label {
        text: tip.text
        size: "xs"
        wrapMode: Text.Wrap
        width: Math.min(implicitWidth, Theme.tooltip.maxWidth)
    }
    background: Rectangle {
        radius: Theme.tooltip.radius
        color: Theme.c.overlay
        border.width: 1
        border.color: Theme.c.overlayBorder
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.normal }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Theme.motion.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeSmooth }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion.fast }
    }
}
