import QtQuick
import "../theme"

// HeroUI's Chip: a small capsule label. tone: "default" | "accent" | "success" | "warning" | "danger";
// variant: "secondary" (grey capsule, colored text: the default), "primary" (solid), "soft" (tinted),
// "tertiary" (no capsule). size: "sm" | "md" | "lg". Optional leading icon.
Rectangle {
    id: chip

    property string text
    property string tone: "default"
    property string variant: "secondary"
    property string size: "md"
    property string iconName

    readonly property var look: {
        const c = Theme.c;
        const name = tone;
        const solid = { "accent": [c.accent, c.accentForeground], "success": [c.success, c.successForeground], "warning": [c.warning, c.warningForeground], "danger": [c.danger, c.dangerForeground], "default": [c.default, c.defaultForeground] };
        const soft = { "accent": [c.accentSoft, c.accentSoftForeground], "success": [c.successSoft, c.successSoftForeground], "warning": [c.warningSoft, c.warningSoftForeground], "danger": [c.dangerSoft, c.dangerSoftForeground], "default": [c.defaultSoft, c.defaultForeground] };
        const fg = name === "default" ? c.defaultForeground : soft[name][1];
        if (variant === "primary")
            return solid[name];
        if (variant === "soft")
            return soft[name];
        if (variant === "tertiary")
            return ["transparent", fg];
        return [c.default, fg];
    }

    implicitHeight: size === "sm" ? Theme.chip.heightSm : size === "lg" ? Theme.chip.heightLg : Theme.chip.height
    implicitWidth: row.implicitWidth + 2 * (size === "sm" ? Theme.chip.paddingXSm : size === "lg" ? Theme.chip.paddingXLg : Theme.chip.paddingX)
    radius: height / 2
    color: look[0]

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing
        Icon {
            visible: chip.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.iconName
            size: chip.size === "lg" ? 16 : 14
            color: chip.look[1]
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            size: chip.size === "lg" ? "sm" : "xs"
            weight: Theme.weightMedium
            color: chip.look[1]
        }
    }
}
