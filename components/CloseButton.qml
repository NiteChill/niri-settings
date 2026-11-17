import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's CloseButton: a small round grey button with an ×, used inside fields (clear) and popovers.
// `plain` drops the grey disc (an icon that lights up on hover, e.g. the password eye). `iconName` swaps
// the ×. Not in the Tab order: the field's keys (Escape) do the same.
T.AbstractButton {
    id: button

    property string iconName: "close"
    property bool plain: false
    property real px: 20

    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    implicitWidth: px
    implicitHeight: px

    scale: down ? 0.93 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOutQuart
        }
    }

    background: Rectangle {
        radius: height / 2
        color: button.plain ? "transparent" : (button.hovered ? Theme.c.defaultHover : Theme.mix(Theme.c.default, Theme.c.foreground, 0.08))
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: button.iconName
            size: button.plain ? 16 : 12
            color: button.hovered ? Theme.c.foreground : Theme.c.muted
            Behavior on color {
                ColorAnimation { duration: Theme.motion.normal }
            }
        }
    }
}
