import QtQuick
import "../theme"

// HeroUI's NumberField: − value + in one field (40 px buttons with a faint divider). Type a number
// (applied on Enter or when leaving), click the buttons, Up / Down (Page Up / Down: ten steps), or scroll
// over it once it has focus. Clamped to from..to, rounded to `decimals`. `suffix`: a unit after the
// number ("px", "ms"). Emits valueModified only for the user's changes. Never cuts its number: it measures
// the widest value it can hold (from / to, with the unit), the − / + buttons and the padding give way when
// the field is narrow, and below that it grows (minimumWidth).
FieldText {
    id: field
    // scrolling over it changes the value once it has focus (components/WheelScroll lets it through)
    readonly property bool takesWheel: input.activeFocus

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix
    property bool invalid: errorMessage !== ""
    property string variant: "secondary"
    signal valueModified(real value)

    width: Math.round(160 * Math.max(1, Theme.textScale))

    // room the widest value needs, and what gives way for it
    TextMetrics {
        id: widest
        font: input.font
        text: [field.format(field.from), field.format(field.to)].reduce((a, b) => b.length > a.length ? b : a)
    }
    readonly property real textRoom: Math.ceil(widest.advanceWidth) + (field.suffix !== "" ? unit.implicitWidth + Theme.spacing : 0) + 2
    readonly property real minimumWidth: textRoom + 2 * 28 + 2 * 4
    readonly property real frameWidth: Math.max(width, minimumWidth)
    readonly property real stepW: Math.max(28, Math.min(Theme.field.stepperWidth, (frameWidth - textRoom - 2 * Theme.field.paddingX) / 2))
    readonly property real padX: Math.max(4, Math.min(Theme.field.paddingX, (frameWidth - textRoom - 2 * stepW) / 2))

    function format(v) {
        return v.toFixed(decimals);
    }
    function commit(v) {
        if (isNaN(v)) {
            input.text = format(value);
            return;
        }
        const k = Math.pow(10, decimals);
        const next = Math.min(to, Math.max(from, Math.round(v * k) / k));
        input.text = format(next);
        // the page stores it and `value` follows (assigning it here would cut the page's binding)
        if (next !== value)
            valueModified(next);
    }
    function stepBy(n) {
        commit((input.activeFocus ? parseFloat(input.text) : value) + n * step);
    }
    onValueChanged: if (!input.activeFocus) input.text = format(value)

    FieldFrame {
        id: frame
        width: field.frameWidth
        variant: field.variant
        hovered: hover.hovered
        focused: input.activeFocus
        invalid: field.invalid
        opacity: field.enabled ? 1 : Theme.disabledOpacity

        HoverHandler {
            id: hover
        }
        WheelHandler {
            enabled: input.activeFocus
            onWheel: event => field.stepBy(event.angleDelta.y > 0 ? 1 : -1)
        }

        Stepper {
            id: minus
            width: field.stepW
            anchors.left: parent.left
            iconName: "remove"
            enabled: field.value > field.from
            onClicked: field.stepBy(-1)
        }
        Rectangle {
            anchors.left: minus.right
            width: 1
            height: parent.height
            color: Theme.alpha(Theme.c.muted, 0.15)
        }
        Row {
            anchors.left: minus.right
            anchors.right: plus.left
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: field.padX
            rightPadding: field.padX
            spacing: Theme.spacing
            TextInput {
                id: input
                width: parent.width - parent.leftPadding - parent.rightPadding - (unit.visible ? unit.width + parent.spacing : 0)
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                text: field.format(field.value)
                color: Theme.c.foreground
                selectionColor: Theme.alpha(Theme.c.accent, 0.4)
                selectedTextColor: Theme.c.foreground
                font.family: Theme.font.family
                font.pixelSize: Theme.text.sm
                font.features: { "tnum": 1 }
                font.variableAxes: ({ "ROND": Theme.font.roundness })
                selectByMouse: true
                activeFocusOnTab: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: RegularExpressionValidator {
                    regularExpression: /-?[0-9]*[.,]?[0-9]*/
                }
                onEditingFinished: field.commit(parseFloat(text.replace(",", ".")))
                Keys.onUpPressed: field.stepBy(1)
                Keys.onDownPressed: field.stepBy(-1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                        field.stepBy(event.key === Qt.Key_PageUp ? 10 : -10);
                        event.accepted = true;
                    }
                }
            }
            Label {
                id: unit
                visible: field.suffix !== ""
                text: field.suffix
                color: Theme.c.muted
            }
        }
        Rectangle {
            anchors.right: plus.left
            width: 1
            height: parent.height
            color: Theme.alpha(Theme.c.muted, 0.15)
        }
        Stepper {
            id: plus
            width: field.stepW
            anchors.right: parent.right
            iconName: "add"
            enabled: field.value < field.to
            onClicked: field.stepBy(1)
        }
    }

    component Stepper: MouseArea {
        id: stepper
        property string iconName
        width: Theme.field.stepperWidth
        height: Theme.field.height
        hoverEnabled: true
        opacity: enabled ? 1 : Theme.disabledOpacity
        // held down: repeats, like a key
        onPressed: repeat.start()
        onReleased: repeat.stop()
        onCanceled: repeat.stop()
        Timer {
            id: repeat
            interval: 400
            repeat: true
            onTriggered: {
                interval = 60;
                stepper.clicked(null);
            }
            onRunningChanged: if (!running) interval = 400
        }
        // pressed tint, inset so it stays inside the field's rounded corners
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacing - 1
            radius: Theme.field.radius - anchors.margins
            color: stepper.pressed ? Theme.alpha(Theme.c.foreground, 0.1) : (stepper.containsMouse ? Theme.alpha(Theme.c.foreground, 0.05) : "transparent")
        }
        Icon {
            anchors.centerIn: parent
            name: stepper.iconName
            size: Theme.field.iconSize
            color: Theme.c.foreground
            scale: stepper.pressed ? 0.97 : 1
        }
    }
}
