import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T
import "../theme"

// HeroUI's Slider: a 20 px grey track, filled with the accent up to an accent thumb holding a white
// knob (the knob shrinks a little while dragged). Optional label (left) and value (right) above it; in
// a SettingsRow the row's title is the label and the row writes the value at its top right (HeroUI's
// layout). A slider with few steps (a multiplier: 0.5×, 1×, 1.5×...) dots each step inside the track,
// by itself (`showSteps` forces it on or off); `marks` ([{ value, label }]) are written under the track.
// Drag, click, arrows / Page Up / Down / Home / End, or scroll over it once it has focus (until then the
// wheel scrolls the page). `format(v)` writes the value (default: the number + `suffix`): give every
// slider a format a person can read.
T.Slider {
    id: control

    property string label
    property string suffix
    property bool showOutput: label !== ""
    readonly property int stepCount: stepSize > 0 ? Math.round(Math.abs(to - from) / stepSize) : 0
    // few enough steps, and room for them: one dot per step
    property bool showSteps: stepCount > 1 && stepCount <= 16 && (width - 2 * edge) / stepCount >= 14
    property var marks: []
    property var format: v => (stepSize > 0 && stepSize < 1 ? v.toFixed(String(stepSize).split(".")[1].length) : Math.round(v)) + suffix

    readonly property real edge: Theme.slider.edge
    readonly property real trackTop: header.visible ? header.height + Theme.spacing : 0
    readonly property real thumbX: edge + visualPosition * (width - 2 * edge)

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : Theme.disabledOpacity
    implicitWidth: 256
    implicitHeight: trackTop + Theme.slider.trackHeight + (marks.length ? Theme.spacing + Theme.text.xs * 1.4 : 0)
    padding: 0
    snapMode: T.Slider.SnapAlways

    // the wheel changes the value only once the slider has the focus (clicked or tabbed to): over an
    // untouched slider it scrolls the page (components/WheelScroll)
    readonly property bool takesWheel: activeFocus
    WheelHandler {
        enabled: control.activeFocus
        onWheel: event => {
            if (event.angleDelta.y > 0)
                control.increase();
            else
                control.decrease();
            control.moved();
        }
    }
    Keys.onPressed: event => {
        const big = (control.to - control.from) / 10;
        let v = control.value;
        if (event.key === Qt.Key_PageUp)
            v += big;
        else if (event.key === Qt.Key_PageDown)
            v -= big;
        else if (event.key === Qt.Key_Home)
            v = control.from;
        else if (event.key === Qt.Key_End)
            v = control.to;
        else
            return;
        control.value = Math.min(control.to, Math.max(control.from, v));
        control.moved();
        event.accepted = true;
    }

    background: Item {
        Row {
            id: header
            visible: control.showOutput
            width: control.width
            Label {
                width: parent.width - value.width
                text: control.label
                weight: Theme.weightMedium
                elide: Text.ElideRight
            }
            Label {
                id: value
                text: control.format(control.value)
                weight: Theme.weightMedium
                font.features: { "tnum": 1 }
            }
        }
        Rectangle {
            id: track
            y: control.trackTop
            width: control.width
            height: Theme.slider.trackHeight
            radius: height / 2
            color: Theme.c.default

            Rectangle {
                width: control.thumbX
                height: parent.height
                radius: parent.radius
                color: Theme.c.accent
            }
            Repeater {
                model: control.showSteps && control.stepCount > 0 ? control.stepCount + 1 : 0
                Rectangle {
                    required property int index
                    readonly property real p: index / Math.max(1, control.stepCount)
                    readonly property real cx: control.edge + p * (control.width - 2 * control.edge)
                    x: cx - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.slider.stepDot
                    height: width
                    radius: width / 2
                    color: cx <= control.thumbX ? Theme.alpha(Theme.c.accentForeground, 0.25) : Theme.alpha(Theme.c.muted, 0.25)
                }
            }
        }
        Repeater {
            model: control.marks
            Label {
                required property var modelData
                readonly property real p: (modelData.value - control.from) / (control.to - control.from)
                // centred under its value, but kept inside the track (end labels line up with its ends)
                x: Math.max(0, Math.min(control.width - width, control.edge + p * (control.width - 2 * control.edge) - width / 2))
                y: control.trackTop + Theme.slider.trackHeight + Theme.spacing
                text: modelData.label
                size: "xs"
                color: modelData.value <= control.value ? Theme.c.foreground : Theme.c.muted
                font.features: { "tnum": 1 }
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(200) }
                }
            }
        }
    }

    handle: Rectangle {
        x: control.thumbX - width / 2
        y: control.trackTop
        width: Theme.slider.thumbWidth
        height: Theme.slider.trackHeight
        radius: height / 2
        color: Theme.c.accent

        Rectangle {
            anchors.centerIn: parent
            width: Theme.slider.knobWidth
            height: Theme.slider.knobHeight
            radius: height / 2
            color: Theme.c.accentForeground
            scale: control.pressed ? Theme.slider.draggingScale : 1
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                blur: 4
                offset.y: 1
                color: "#33000000"
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.motion.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
        FocusRing {
            shown: control.visualFocus
            baseRadius: parent.radius
        }
    }
}
