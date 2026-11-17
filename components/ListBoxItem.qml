import QtQuick
import "../theme"

// One row of a HeroUI ListBox (Select's menu, menus): 36 px, 16 px corners, grey when hovered or
// keyboard-highlighted, shrinks a little while pressed. Optional icon, description under the label, a
// check at the end when `selected`. `danger` writes it in red.
Item {
    id: item

    property string label
    property string description
    property string iconName
    property bool selected: false
    property bool highlighted: false
    property bool danger: false
    signal clicked
    signal hovered

    implicitHeight: Math.max(Theme.list.itemHeight, texts.implicitHeight + 2 * Theme.spacing * 1.5)

    Rectangle {
        anchors.fill: parent
        radius: Theme.list.itemRadius
        color: item.highlighted ? Theme.c.default : Theme.alpha(Theme.c.default, 0)
        scale: mouse.pressed ? 0.98 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motion.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOutQuart
            }
        }
    }
    Row {
        x: Theme.list.itemPaddingX
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2 * Theme.list.itemPaddingX - (check.visible ? check.width : 0)
        spacing: Theme.list.gap
        Icon {
            visible: item.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: item.iconName
            size: 16
            color: item.danger ? Theme.c.danger : Theme.c.muted
        }
        Column {
            id: texts
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (item.iconName !== "" ? 16 + parent.spacing : 0)
            Label {
                width: parent.width
                text: item.label
                color: item.danger ? Theme.c.danger : Theme.c.foreground
                elide: Text.ElideRight
            }
            Label {
                visible: item.description !== ""
                width: parent.width
                text: item.description
                size: "xs"
                color: Theme.c.muted
                elide: Text.ElideRight
            }
        }
    }
    Icon {
        id: check
        visible: item.selected
        anchors.right: parent.right
        anchors.rightMargin: Theme.list.itemPaddingX
        anchors.verticalCenter: parent.verticalCenter
        name: "check"
        size: 16
        color: item.danger ? Theme.c.danger : Theme.c.defaultForeground
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        // only a real pointer move highlights (rows sliding under a still pointer don't)
        onPositionChanged: item.hovered()
        onEntered: item.hovered()
        onClicked: item.clicked()
    }
}
