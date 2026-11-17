import QtQuick
import "../theme"

// HeroUI's Alert: a soft tinted box with an icon, a title and a line of explanation, optionally a button.
// tone: "accent" (info), "success", "warning", "danger", "default".
Rectangle {
    id: banner

    property string tone: "accent"
    property string title
    property string description
    property string iconName: tone === "danger" ? "error-fill" : tone === "warning" ? "error-fill" : tone === "success" ? "check" : "info-fill"
    property string actionText
    signal action

    readonly property color fg: tone === "danger" ? Theme.c.danger : tone === "warning" ? Theme.c.warning : tone === "success" ? Theme.c.success : tone === "default" ? Theme.c.muted : Theme.c.accent

    width: parent ? parent.width : 400
    implicitHeight: Math.max(row.implicitHeight, button.visible ? button.height : 0) + 2 * Theme.spacing * 3.5
    radius: Theme.radius["2xl"]
    color: tone === "default" ? Theme.c.surface : Theme.alpha(fg, 0.1)

    Row {
        id: row
        x: Theme.spacing * 4
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x * 2 - (button.visible ? button.width + Theme.spacing * 3 : 0)
        spacing: Theme.spacing * 3
        Icon {
            name: banner.iconName
            size: 20
            color: banner.fg
        }
        Column {
            width: parent.width - 20 - parent.spacing
            spacing: Theme.spacing / 2
            Label {
                visible: banner.title !== ""
                width: parent.width
                text: banner.title
                weight: Theme.weightMedium
                color: banner.tone === "default" ? Theme.c.foreground : banner.fg
                wrapMode: Text.Wrap
            }
            Label {
                visible: banner.description !== ""
                width: parent.width
                text: banner.description
                color: Theme.c.muted
                wrapMode: Text.Wrap
            }
        }
    }
    Button {
        id: button
        visible: banner.actionText !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing * 3
        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        variant: "tertiary"
        text: banner.actionText
        onClicked: banner.action()
    }
}
