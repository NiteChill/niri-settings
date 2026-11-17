import QtQuick
import Quickshell.Widgets
import "../theme"
import "../services"

// A little screen (your wallpaper) with a target in each corner: click one (or Tab to it, then Space)
// to turn that corner on or off. `corners`: the chosen ones, by name ("top-left", "top-right", "bottom-left", "bottom-right");
// `toggled(name)` asks for a change (the page writes it, then `corners` follows).
Item {
    id: picker

    property var corners: []
    signal toggled(string name)

    implicitWidth: 240
    implicitHeight: 150

    ClippingRectangle {
        id: screen
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.c.default
        border.width: 1
        border.color: Theme.c.border
        Image {
            anchors.fill: parent
            source: Niri.wallpaper ? "file://" + Niri.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
            asynchronous: true
            opacity: 0.85
        }
        // a quarter glow tucked into each chosen corner (clipped by the screen's rounded corners)
        Repeater {
            model: targets.count
            Rectangle {
                required property int index
                readonly property var t: targets.count > 0 ? targets.itemAt(index) : null
                readonly property real r: 44
                width: r * 2
                height: r * 2
                radius: r
                x: t && t.modelData[1] ? picker.width - r : -r
                y: t && t.modelData[2] ? picker.height - r : -r
                color: Theme.c.accent
                opacity: !t ? 0 : t.on ? 0.55 : t.hovered ? 0.25 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.normal }
                }
            }
        }
    }

    Repeater {
        id: targets
        model: [["top-left", 0, 0], ["top-right", 1, 0], ["bottom-left", 0, 1], ["bottom-right", 1, 1]]
        Item {
            id: target
            required property var modelData
            readonly property bool on: picker.corners.indexOf(modelData[0]) >= 0
            readonly property bool hovered: mouse.containsMouse || activeFocus
            // keyboard: Tab reaches a corner, Left / Right move between them, Space / Enter turns it on or off
            readonly property bool isChoice: true
            activeFocusOnTab: true
            Keys.onSpacePressed: picker.toggled(modelData[0])
            Keys.onReturnPressed: picker.toggled(modelData[0])
            Keys.onLeftPressed: Theme.stepFocus(target, -1)
            Keys.onRightPressed: Theme.stepFocus(target, 1)
            readonly property real r: 44
            width: r
            height: r
            x: modelData[1] ? picker.width - width : 0
            y: modelData[2] ? picker.height - height : 0

            Rectangle {
                width: 14
                height: 14
                radius: 7
                x: target.modelData[1] ? target.r - width - 8 : 8
                y: target.modelData[2] ? target.r - height - 8 : 8
                color: target.on ? Theme.c.accentForeground : "transparent"
                border.width: target.on ? 0 : 2
                border.color: "#ccffffff"
                scale: mouse.pressed ? 0.85 : 1
                FocusRing {
                    shown: target.activeFocus
                    offset: 2
                    baseRadius: 7
                }
                Behavior on scale {
                    Spring {}
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.toggled(target.modelData[0])
            }
        }
    }
    // the screen's rounded corners stay drawn over the glows
    Rectangle {
        anchors.fill: parent
        radius: screen.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.c.border
    }
}
