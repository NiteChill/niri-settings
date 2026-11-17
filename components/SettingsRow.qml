import QtQuick
import "../theme"
import "../services"

// One setting: its name (and an optional grey explanation under it) on the left, its control on the
// right (the default child: a Switch, Select, NumberField...). `iconName`: a leading icon (`appIcon`: an
// app's; `iconLayers` + `iconLevel`: a level icon like the island's). `wide`: the control goes under the text,
// full width (sliders). `iconName`: a leading icon. Clickable rows (`onClicked`, e.g. opening a
// sub-page) get a chevron and highlight on hover. A faint line above every row but the first.
Item {
    id: row

    property string title
    // a setting of the Dynamic Island: shown only when it's installed (Island.installed). An instance that
    // sets its own `visible` adds `Island.installed &&` itself; bin/settings-index.py tags these.
    property bool islandOnly: false
    visible: !islandOnly || Island.installed
    property string description
    property string iconName
    // an app's icon from the icon theme instead (startup apps, app rules)
    property string appIcon
    // its letter when the theme has no such icon (default: the title's)
    property string appIconFallback
    // a level icon like the island's instead (LayeredIcon: Theme.wifiLayers + the bars)
    property var iconLayers: []
    property int iconLevel: 0
    property bool wide: false
    property bool clickable: false
    default property alias control: slot.data
    signal clicked

    readonly property real pad: Theme.card.padding
    // the control's own width; a control wider than about half the row goes under the text instead
    readonly property real natural: slot.children.length ? slot.children[0].width : 0
    readonly property bool stacked: wide || natural > width * 0.55
    // the first thing shown in its group: no line above it. Hidden rows before it don't count (a line
    // under the group's title looked like a glitch), and a row inside a wrapper (a Wi-Fi network with
    // its password field, an app rule's rows) is first only if its wrapper is too.
    function _firstShown(item) {
        for (const c of item.parent.children) {
            if (c === item)
                return true;
            if (c.visible && c.height > 0)
                return false;
        }
        return true;
    }
    readonly property bool first: {
        if (!parent)
            return true;
        // the group's list, through at most a few wrappers
        const chain = [];
        let it = row, inGroup = false;
        for (let depth = 0; depth < 4 && it.parent; depth++) {
            chain.push(it);
            if (it.parent.objectName === "settingsList") {
                inGroup = true;
                break;
            }
            it = it.parent;
        }
        // not in a group: only its own parent counts
        if (!inGroup)
            return _firstShown(row);
        return chain.every(x => _firstShown(x));
    }
    // a slider under the text shows its value here, at the row's top right, on the title's line
    readonly property var sliderControl: {
        const isSlider = c => c && c.hasOwnProperty("stepSize") && typeof c.format === "function" && !c.showOutput;
        // the control, or a slider inside it (beside a mute button, above a level meter): 3 levels deep
        const find = (item, depth) => {
            if (isSlider(item))
                return item;
            if (!item || depth === 0)
                return null;
            for (const k of item.children) {
                const r = find(k, depth - 1);
                if (r)
                    return r;
            }
            return null;
        };
        return find(slot.children.length ? slot.children[0] : null, 3);
    }

    width: parent ? parent.width : 0
    implicitHeight: stacked ? texts.implicitHeight + Theme.spacing * 3 + slot.childrenRect.height + 2 * pad : Math.max(Theme.spacing * 15, texts.implicitHeight + 2 * pad, slot.childrenRect.height + 2 * Theme.spacing * 3)

    Separator {
        visible: !row.first
        x: row.pad
        width: row.width - 2 * row.pad
        variant: "default"
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        radius: Theme.card.radius - Theme.spacing
        visible: row.clickable
        color: mouse.containsMouse ? Theme.c.surfaceHover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.motion.normal }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: true
        onClicked: row.clicked()
    }

    Icon {
        id: lead
        visible: row.iconName !== "" || row.appIcon !== "" || row.iconLayers.length > 0
        x: row.pad
        y: row.stacked ? row.pad : (row.height - height) / 2
        name: row.appIcon !== "" || row.iconLayers.length > 0 ? "" : row.iconName
        size: row.appIcon !== "" ? 24 : 20
        color: Theme.c.muted
        LayeredIcon {
            visible: row.iconLayers.length > 0
            anchors.fill: parent
            layers: row.iconLayers
            level: row.iconLevel
            size: 20
            color: Theme.c.muted
        }
        AppIcon {
            visible: row.appIcon !== ""
            anchors.fill: parent
            name: row.appIcon
            fallback: row.appIconFallback || row.title
            size: 24
        }
    }
    Column {
        id: texts
        x: lead.visible ? lead.x + lead.width + Theme.spacing * 3 : row.pad
        y: row.stacked ? row.pad : (row.height - height) / 2
        width: (row.stacked ? row.width - row.pad - (valueText.visible ? valueText.width + Theme.spacing * 4 : 0) : slot.x - Theme.spacing * 6) - x
        spacing: Theme.spacing / 2
        // a disabled row greys its text (its control greys itself)
        opacity: row.enabled ? 1 : Theme.disabledOpacity
        Label {
            width: parent.width
            text: row.title
            weight: Theme.weightMedium
            elide: Text.ElideRight
        }
        Label {
            visible: row.description !== ""
            width: parent.width
            text: row.description
            color: Theme.c.muted
            wrapMode: Text.Wrap
        }
    }
    Label {
        id: valueText
        visible: row.stacked && row.sliderControl !== null
        anchors.right: parent.right
        anchors.rightMargin: row.pad
        y: texts.y
        text: row.sliderControl ? row.sliderControl.format(row.sliderControl.value) : ""
        weight: Theme.weightMedium
        font.features: { "tnum": 1 }
        opacity: row.enabled ? 1 : Theme.disabledOpacity
    }
    Item {
        id: slot
        x: row.stacked ? row.pad : row.width - row.pad - width - (chevron.visible ? chevron.width + Theme.spacing * 2 : 0)
        y: row.stacked ? texts.y + texts.height + Theme.spacing * 3 : (row.height - height) / 2
        width: row.wide ? row.width - 2 * row.pad : childrenRect.width
        height: childrenRect.height
    }
    Icon {
        id: chevron
        visible: row.clickable
        anchors.right: parent.right
        anchors.rightMargin: row.pad
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_right"
        size: 20
        color: Theme.c.muted
    }
}
