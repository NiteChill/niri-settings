import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's Tabs (the segmented look): grey capsule holding the choices; the chosen one sits on a lighter
// segment that springs to it (the island's list spring), its text brightening from grey. Faint dividers
// between unchosen neighbours. `options`: [{ value, label, icon }] (icon optional); `value` comes from the page, which updates it on `activated`.
// Keyboard: Left / Right (or Tab into it, then arrows), Home / End.
T.Control {
    id: tabs

    property var options: []
    property var value
    property bool fullWidth: false
    signal activated(var value)

    readonly property int current: {
        for (let i = 0; i < options.length; i++)
            if (options[i].value === value)
                return i;
        return -1;
    }
    function choose(i) {
        if (i < 0 || i >= options.length)
            return;
        // the page sets `value` from its setting (assigning it here would cut that binding)
        activated(options[i].value);
    }

    implicitWidth: row.implicitWidth + 2 * Theme.tabs.listPadding
    implicitHeight: Theme.tabs.tabHeight + 2 * Theme.tabs.listPadding
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    background: Rectangle {
        radius: Theme.tabs.listRadius
        color: Theme.c.default
    }
    Keys.onLeftPressed: choose(Math.max(0, current - 1))
    Keys.onRightPressed: choose(Math.min(options.length - 1, current + 1))
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home)
            choose(0);
        else if (event.key === Qt.Key_End)
            choose(options.length - 1);
    }

    // the sliding segment
    Rectangle {
        id: segment
        // (repeater.count: re-read once the tabs exist)
        readonly property Item target: repeater.count > 0 && tabs.current >= 0 ? repeater.itemAt(tabs.current) : null
        visible: !!target
        x: target ? row.x + target.x : 0
        y: Theme.tabs.listPadding
        width: target ? target.width : 0
        height: Theme.tabs.tabHeight
        radius: height / 2
        color: Theme.c.segment
        Behavior on x {
            Spring {}
        }
        Behavior on width {
            Spring {}
        }
        FocusRing {
            shown: tabs.visualFocus
            baseRadius: parent.radius
        }
    }

    Row {
        id: row
        x: Theme.tabs.listPadding
        y: Theme.tabs.listPadding
        width: tabs.fullWidth ? tabs.width - 2 * Theme.tabs.listPadding : implicitWidth
        Repeater {
            id: repeater
            model: tabs.options
            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool chosen: index === tabs.current
                width: tabs.fullWidth ? row.width / tabs.options.length : content.implicitWidth + 2 * Theme.tabs.tabPadding
                height: Theme.tabs.tabHeight

                // divider before this tab, hidden next to the chosen one
                Rectangle {
                    visible: tab.index > 0
                    x: -width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height / 2
                    radius: 1
                    color: Theme.alpha(Theme.c.muted, 0.25)
                    opacity: tab.chosen || tab.index - 1 === tabs.current ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.motion.normal }
                    }
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: Theme.spacing * 1.5
                    opacity: !tab.chosen && mouse.containsMouse ? 0.7 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.motion.normal }
                    }
                    Icon {
                        visible: !!tab.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        name: tab.modelData.icon || ""
                        size: 16
                        color: label.color
                    }
                    Label {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        weight: Theme.weightMedium
                        color: tab.chosen ? Theme.c.foreground : Theme.c.muted
                        Behavior on color {
                            ColorAnimation { duration: Theme.motion.normal }
                        }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        tabs.forceActiveFocus(Qt.MouseFocusReason);
                        tabs.choose(tab.index);
                    }
                }
            }
        }
    }
}
