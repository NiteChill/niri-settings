import QtQuick
import Quickshell.Widgets
import "../theme"

// A choice shown as a picture: a rounded preview (the default child, clipped to the tile's corners), its
// name under it, and when chosen an accent ring and a check badge. Lifts a little on hover, sinks when
// pressed. Use a row of them where seeing beats reading (island styles, light / dark, power modes).
Item {
    id: tile

    property bool selected: false
    property string label
    property string sublabel
    property real previewHeight: 96
    property color previewColor: Theme.c.surfaceSecondary
    default property alias preview: frame.data
    signal clicked

    implicitWidth: 168
    implicitHeight: previewHeight + Theme.spacing * 2 + (label !== "" ? Theme.text.sm * 1.5 : 0) + (sublabel !== "" ? Theme.text.xs * 1.5 : 0)
    // keyboard: Tab reaches it, Left / Right move between the choices in the same row, Space / Enter picks
    readonly property bool isChoice: true
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onLeftPressed: Theme.stepFocus(tile, -1)
    Keys.onRightPressed: Theme.stepFocus(tile, 1)

    Item {
        id: lift
        width: parent.width
        height: tile.previewHeight
        scale: mouse.pressed ? 0.97 : mouse.containsMouse ? 1.02 : 1
        Behavior on scale {
            Spring {
                s: Theme.springSoft
            }
        }
        // the ring, 2 px out from the picture
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: Theme.radius["2xl"] + 4
            color: "transparent"
            border.width: 2
            border.color: tile.selected ? Theme.c.accent : "transparent"
            Behavior on border.color {
                ColorAnimation { duration: Theme.motion.normal }
            }
        }
        // keyboard focus: the usual focus ring, outside the chosen ring
        FocusRing {
            shown: tile.activeFocus
            offset: 6
            baseRadius: Theme.radius["2xl"]
        }
        ClippingRectangle {
            id: frame
            anchors.fill: parent
            radius: Theme.radius["2xl"]
            color: tile.previewColor
        }
        Rectangle {
            visible: tile.selected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing * 2
            width: 20
            height: 20
            radius: 10
            color: Theme.c.accent
            Icon {
                anchors.centerIn: parent
                name: "check"
                size: 14
                color: Theme.c.accentForeground
            }
        }
    }
    Column {
        y: tile.previewHeight + Theme.spacing * 2
        width: parent.width
        Label {
            visible: tile.label !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            weight: tile.selected ? Theme.weightMedium : Theme.weightNormal
            color: tile.selected ? Theme.c.foreground : Theme.c.muted
            elide: Text.ElideRight
        }
        Label {
            visible: tile.sublabel !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.sublabel
            size: "xs"
            color: Theme.c.muted
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
