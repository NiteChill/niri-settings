import QtQuick
import QtQuick.Templates as T
import "../theme"

// HeroUI's Select: a field showing the chosen option with a chevron; clicking it (or Space / Enter /
// Down) opens a popover list under it with the chosen one checked. Up / Down move, Enter / Space pick,
// Escape closes. `options`: [{ value, label, description, icon }]; `value` comes from the page, which updates it on `activated`.
FieldText {
    id: select

    property var options: []
    property var value
    property string placeholder: "Select an option"
    property string variant: "secondary"
    property bool invalid: errorMessage !== ""
    signal activated(var value)

    readonly property int current: {
        for (let i = 0; i < options.length; i++)
            if (options[i].value === value)
                return i;
        return -1;
    }
    readonly property var chosen: current >= 0 ? options[current] : null

    width: Math.round(256 * Math.max(1, Theme.textScale))

    function pick(i) {
        // the page sets `value` from its setting on `activated` (assigning it here would cut that binding)
        if (i >= 0 && i < options.length)
            activated(options[i].value);
        popup.close();
        trigger.forceActiveFocus(Qt.TabFocusReason);
    }

    FieldFrame {
        id: frame
        width: select.width
        variant: select.variant
        hovered: trigger.hovered
        focused: trigger.visualFocus
        invalid: select.invalid
        opacity: select.enabled ? 1 : Theme.disabledOpacity

        T.AbstractButton {
            id: trigger
            anchors.fill: parent
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            onClicked: popup.opened ? popup.close() : popup.open()
            Keys.onDownPressed: popup.open()
            Keys.onUpPressed: popup.open()
            Keys.onReturnPressed: popup.open()

            Row {
                x: Theme.field.paddingX
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * Theme.field.paddingX - chevron.width
                spacing: Theme.spacing * 2
                Icon {
                    visible: !!(select.chosen && select.chosen.icon)
                    anchors.verticalCenter: parent.verticalCenter
                    name: select.chosen && select.chosen.icon || ""
                    size: 16
                    color: Theme.c.muted
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: select.chosen ? select.chosen.label : select.placeholder
                    color: select.chosen ? Theme.c.foreground : Theme.c.muted
                    elide: Text.ElideRight
                }
            }
            Icon {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing * 2.5
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard_arrow_down"
                size: 16
                color: Theme.c.muted
                rotation: popup.opened ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.motion.slow
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easeOutFluid
                    }
                }
            }
        }

        Popover {
            id: popup
            y: frame.height + Theme.list.popoverGap
            width: frame.width
            height: Math.min(select.options.length, Theme.list.maxRows) * Theme.list.itemHeight + 2 * padding
            onOpened: {
                list.currentIndex = Math.max(0, select.current);
                list.positionViewAtIndex(list.currentIndex, ListView.Contain);
                list.forceActiveFocus();
            }
            contentItem: ListView {
                id: list
                clip: true
                model: select.options
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: false
                highlightMoveDuration: 0
                WheelScroll {
                    flickable: list
                }
                Keys.onReturnPressed: select.pick(currentIndex)
                Keys.onSpacePressed: select.pick(currentIndex)
                delegate: ListBoxItem {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    label: modelData.label
                    description: modelData.description || ""
                    iconName: modelData.icon || ""
                    selected: index === select.current
                    highlighted: index === list.currentIndex
                    onHovered: list.currentIndex = index
                    onClicked: select.pick(index)
                }
            }
        }
    }
}
