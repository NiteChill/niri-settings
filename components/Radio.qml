import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's Radio: a 16 px circle that fills with the accent when chosen, a white dot in the middle
// (6 px, 8 px while pressed). Put several in a RadioGroup (same parent = exclusive). Optional description.
T.RadioButton {
    id: control

    property string description

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : Theme.disabledOpacity
    spacing: Theme.toggle.labelGap
    implicitWidth: dot.width + (text !== "" ? spacing + texts.implicitWidth : 0)
    implicitHeight: Math.max(dot.height, texts.implicitHeight)

    indicator: Rectangle {
        id: dot
        width: Theme.toggle.box
        height: width
        y: control.description !== "" ? (Theme.text.sm * 1.4 - height) / 2 : (control.height - height) / 2
        radius: width / 2
        color: control.checked ? (control.down ? Theme.c.accentHover : Theme.c.accent) : (control.hovered ? Theme.c.defaultHover : Theme.c.default)
        scale: control.down ? 0.95 : 1
        Behavior on color {
            ColorAnimation { duration: Theme.dur(200) }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.motion.fast }
        }
        Rectangle {
            anchors.centerIn: parent
            width: control.checked ? (control.down ? Theme.toggle.radioDotPressed : Theme.toggle.radioDot) : Theme.toggle.box
            height: width
            radius: width / 2
            color: Theme.c.accentForeground
            opacity: control.checked ? 1 : 0
            Behavior on width {
                NumberAnimation {
                    duration: Theme.dur(200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.motion.normal }
            }
        }
        FocusRing {
            shown: control.visualFocus
            baseRadius: parent.radius
        }
    }

    contentItem: Column {
        id: texts
        leftPadding: dot.width + control.spacing
        visible: control.text !== ""
        spacing: Theme.field.gap / 2
        Label {
            text: control.text
            weight: Theme.weightMedium
        }
        Label {
            visible: control.description !== ""
            text: control.description
            size: "xs"
            color: Theme.c.muted
        }
    }
}
