import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's Button. variant: "primary" (accent), "secondary" (grey, accent text), "tertiary" (grey),
// "outline", "ghost", "danger", "danger-soft". size: "sm" | "md" | "lg". An icon before the text
// (`iconName`) and/or after it (`endIconName`); no text = a round icon-only button. `pending` shows a
// spinner and ignores clicks. Pressing shrinks it a little (HeroUI's scale 0.97).
T.Button {
    id: button

    property string variant: "primary"
    property string size: "md"
    property string iconName
    property string endIconName
    property bool pending: false
    readonly property bool iconOnly: text === "" && iconName !== ""

    readonly property var look: {
        const c = Theme.c;
        switch (variant) {
        case "secondary":
            return { "bg": c.default, "hover": c.defaultHover, "fg": c.accentSoftForeground, "border": "transparent" };
        case "tertiary":
            return { "bg": c.default, "hover": c.defaultHover, "fg": c.defaultForeground, "border": "transparent" };
        case "outline":
            return { "bg": Theme.alpha(c.default, 0), "hover": Theme.alpha(c.default, 0.6), "fg": c.defaultForeground, "border": c.border };
        case "ghost":
            return { "bg": Theme.alpha(c.default, 0), "hover": c.default, "fg": c.defaultForeground, "border": "transparent" };
        case "danger":
            return { "bg": c.danger, "hover": c.dangerHover, "fg": c.dangerForeground, "border": "transparent" };
        case "danger-soft":
            return { "bg": c.dangerSoft, "hover": c.dangerSoftHover, "fg": c.dangerSoftForeground, "border": "transparent" };
        default:
            return { "bg": c.accent, "hover": c.accentHover, "fg": c.accentForeground, "border": "transparent" };
        }
    }
    readonly property real iconPx: Theme.button.iconSize[size]

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: Theme.button.height[size]
    implicitWidth: iconOnly ? implicitHeight : row.implicitWidth + 2 * Theme.button.padding[size]
    opacity: enabled ? 1 : Theme.disabledOpacity

    // pending: clicks don't go through (without fading it like disabled)
    MouseArea {
        anchors.fill: parent
        z: 10
        enabled: button.pending
        hoverEnabled: true
    }

    scale: down && !pending ? Theme.button.pressedScale[size] : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeSmooth
        }
    }

    background: Rectangle {
        radius: height / 2
        color: (button.hovered || button.down) && !button.pending ? button.look.hover : button.look.bg
        border.width: button.variant === "outline" ? 1 : 0
        border.color: button.look.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
        }
        FocusRing {
            shown: button.visualFocus
            baseRadius: parent.radius
        }
    }

    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.button.gap
            opacity: button.pending ? 0 : 1

            Icon {
                visible: button.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: button.iconName
                size: button.iconOnly ? Theme.button.iconSize.lg : button.iconPx
                color: button.look.fg
            }
            Label {
                visible: button.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                size: button.size === "lg" ? "base" : "sm"
                weight: Theme.weightMedium
                color: button.look.fg
            }
            Icon {
                visible: button.endIconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: button.endIconName
                size: button.iconPx
                color: button.look.fg
            }
        }
        Spinner {
            anchors.centerIn: parent
            visible: button.pending
            size: "sm"
            color: button.look.fg
        }
    }
}
