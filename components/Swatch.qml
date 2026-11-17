import QtQuick
import "../theme"

// One color to pick (accent colors): a 28 px dot; the chosen one gets a ring and a check.
Item {
    id: swatch

    property color color
    property bool selected: false
    property string tip
    signal clicked

    implicitWidth: 36
    implicitHeight: 36
    // keyboard: like TileOption (Left / Right between the colours, Space / Enter picks)
    readonly property bool isChoice: true
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onLeftPressed: Theme.stepFocus(swatch, -1)
    Keys.onRightPressed: Theme.stepFocus(swatch, 1)
    FocusRing {
        shown: swatch.activeFocus
        offset: 0
        baseRadius: width / 2
    }

    Rectangle {
        anchors.centerIn: parent
        width: 36
        height: 36
        radius: 18
        color: "transparent"
        border.width: 2
        border.color: swatch.selected ? swatch.color : "transparent"
    }
    Rectangle {
        anchors.centerIn: parent
        width: swatch.selected ? 24 : 28
        height: width
        radius: width / 2
        color: swatch.color
        scale: mouse.pressed ? 0.9 : 1
        Behavior on width {
            Spring {}
        }
        Behavior on scale {
            Spring {}
        }
        Icon {
            anchors.centerIn: parent
            visible: swatch.selected
            name: "check"
            size: 16
            color: Theme.luminance(swatch.color) > 0.45 ? "#18181b" : "#ffffff"
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: swatch.clicked()
    }
    Tooltip {
        text: swatch.tip
        shown: mouse.containsMouse
    }
}
