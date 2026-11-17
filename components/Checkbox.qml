import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import "../theme"

// HeroUI's Checkbox: a 16 px rounded square; checking grows the accent fill in from 70 % and draws the
// checkmark stroke. Label and optional description to its right. `invalid` outlines it in red.
T.CheckBox {
    id: control

    property string description
    property bool invalid: false

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : Theme.disabledOpacity
    spacing: Theme.toggle.labelGap
    implicitWidth: box.width + (text !== "" ? spacing + texts.implicitWidth : 0)
    implicitHeight: Math.max(box.height, texts.implicitHeight)

    readonly property bool on: checkState !== Qt.Unchecked

    indicator: Rectangle {
        id: box
        width: Theme.toggle.box
        height: width
        y: control.description !== "" ? (Theme.text.sm * 1.4 - height) / 2 : (control.height - height) / 2
        radius: Theme.toggle.boxRadius
        color: control.hovered ? Theme.c.defaultHover : Theme.c.default
        border.width: control.invalid && !control.on ? 1 : 0
        border.color: Theme.c.danger
        scale: control.down ? 0.95 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }

        // the fill: grows from 70 % and fades in
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.invalid ? Theme.c.danger : (control.hovered ? Theme.c.accentHover : Theme.c.accent)
            opacity: control.on ? 1 : 0
            scale: control.on ? 1 : 0.7
            Behavior on opacity {
                NumberAnimation { duration: Theme.dur(200) }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.motion.fast }
            }
        }
        // HeroUI's checkmark (polyline 1,9 7,14 15,4 in a 17 x 18 box), drawn on by its stroke
        Shape {
            visible: control.checkState === Qt.Checked
            anchors.centerIn: parent
            width: Theme.toggle.checkSize
            height: Theme.toggle.checkSize * 18 / 17
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                id: mark
                strokeColor: control.invalid ? Theme.c.dangerForeground : Theme.c.accentForeground
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                scale: Qt.size(Theme.toggle.checkSize / 17, Theme.toggle.checkSize / 17)
                trim.end: control.checkState === Qt.Checked ? 1 : 0
                Behavior on trim.end {
                    NumberAnimation { duration: Theme.motion.normal }
                }
                PathSvg {
                    path: "M 1 9 L 7 14 L 15 4"
                }
            }
        }
        // partly checked: a dash
        Rectangle {
            visible: control.checkState === Qt.PartiallyChecked
            anchors.centerIn: parent
            width: Theme.toggle.checkSize * 0.8
            height: 2
            radius: 1
            color: Theme.c.accentForeground
        }
        FocusRing {
            shown: control.visualFocus
            baseRadius: parent.radius
        }
    }

    contentItem: Column {
        id: texts
        leftPadding: box.width + control.spacing
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
