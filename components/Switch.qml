import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T
import "../theme"

// HeroUI's Switch: a 40 x 20 pill, grey when off, the accent when on; a white thumb slides across
// (on the island's spring). Optional label and description to its right; in a settings row the
// row gives the text and the switch stands alone.
T.Switch {
    id: control

    property string description

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : Theme.disabledOpacity
    spacing: Theme.toggle.labelGap
    implicitWidth: track.width + (text !== "" || description !== "" ? spacing + texts.implicitWidth : 0)
    implicitHeight: Math.max(track.height, texts.implicitHeight)

    indicator: Rectangle {
        id: track
        width: Theme.toggle.trackWidth
        height: Theme.toggle.trackHeight
        y: (control.height - height) / 2
        radius: height / 2
        color: control.checked ? (control.hovered || control.down ? Theme.c.accentHover : Theme.c.accent) : (control.hovered || control.down ? Theme.alpha(Theme.c.default, 0.8) : Theme.c.default)
        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeSmooth
            }
        }

        Rectangle {
            id: thumb
            width: Theme.toggle.thumbWidth
            height: Theme.toggle.thumbHeight
            radius: height / 2
            y: (track.height - height) / 2
            x: control.checked ? track.width - width - Theme.toggle.thumbInset : Theme.toggle.thumbInset
            color: control.checked ? Theme.c.accentForeground : "white"
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                blur: 6
                offset.y: 1
                color: "#33000000"
                opacity: control.checked ? 1 : 0
            }
            Behavior on x {
                Spring {
                    s: Theme.springSoft
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.motion.normal
                }
            }
        }
        FocusRing {
            shown: control.visualFocus
            baseRadius: parent.radius
        }
    }

    contentItem: Column {
        id: texts
        leftPadding: track.width + control.spacing
        anchors.verticalCenter: parent.verticalCenter
        visible: control.text !== "" || control.description !== ""
        spacing: Theme.field.gap
        Label {
            visible: control.text !== ""
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
