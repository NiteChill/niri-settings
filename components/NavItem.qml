import QtQuick
import "../theme"

// A page in the sidebar: icon + name, 36 px, 12 px corners; `hint` (a setting the search found on this
// page) goes in grey under the name and makes the item taller. The chosen one's highlight is drawn by the
// sidebar (it slides between items); this one only lightens on hover and brightens its icon when chosen.
Item {
    id: item

    property string label
    property string iconName
    property real iconRotation: 0
    property bool selected: false
    property string hint
    // a level icon like the island's (LayeredIcon): the whole symbol dimmed, the live level lit
    property var layers: []
    property int level: 0
    property string alone: ""
    // icon only, the name in a tooltip (narrow windows)
    property bool compact: false
    signal clicked

    readonly property bool hinted: hint !== "" && !compact
    implicitHeight: Theme.list.itemHeight + (hinted ? Theme.text.xs * 1.4 : 0)

    Rectangle {
        anchors.fill: parent
        radius: Theme.field.radius
        color: mouse.containsMouse && !item.selected ? Theme.alpha(Theme.c.default, 0.5) : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.motion.normal }
        }
    }
    Row {
        x: Theme.spacing * 2.5
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing * 3
        Icon {
            visible: item.layers.length === 0
            anchors.verticalCenter: parent.verticalCenter
            name: item.layers.length === 0 ? item.iconName : ""
            rotation: item.iconRotation
            size: 20
            color: item.selected ? Theme.c.foreground : Theme.c.muted
            Behavior on color {
                ColorAnimation { duration: Theme.motion.normal }
            }
        }
        LayeredIcon {
            visible: item.layers.length > 0
            anchors.verticalCenter: parent.verticalCenter
            layers: item.layers
            level: item.level
            alone: item.alone
            size: 20
            color: item.selected ? Theme.c.foreground : Theme.c.muted
        }
        Column {
            visible: !item.compact
            anchors.verticalCenter: parent.verticalCenter
            Label {
                width: Math.min(implicitWidth, item.width - Theme.spacing * 2.5 - 20 - Theme.spacing * 6)
                text: item.label
                weight: item.selected ? Theme.weightMedium : Theme.weightNormal
                elide: Text.ElideRight
            }
            Label {
                visible: item.hinted
                width: item.width - Theme.spacing * 2.5 - 20 - Theme.spacing * 6
                text: item.hint
                size: "xs"
                color: Theme.c.muted
                elide: Text.ElideRight
            }
        }
    }
    Tooltip {
        text: item.label
        shown: item.compact && mouse.containsMouse
        delay: 300
        x: item.width + Theme.spacing * 2
        y: (item.height - height) / 2
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.clicked()
    }
}
