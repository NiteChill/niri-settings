import QtQuick
import "../theme"
import "../services"
import "../components"

// Mouse & Touchpad: one tab per device, each opening on a card that says which device it is for (the
// mouse that's plugged in, or that none is), so a change on one tab is never expected on the other.
// Pointer settings shared by both sit under the tabs. Stored in niri's input.mouse / input.touchpad
// blocks, which aren't merged across files: the first change copies the block from config.kdl into the
// app's file (services/Niri.qml), so nothing set there is lost.
Column {
    id: page

    // no mouse but a touchpad: open on the touchpad
    property string tab: Hw.mice.length === 0 && Hw.touchpads.length > 0 ? "touchpad" : "mouse"
    readonly property int rev: Niri.revision
    function flag(p, d) {
        return (rev, Niri.flag(p, d));
    }
    function arg(p, d) {
        return (rev, Niri.arg(p, d));
    }
    // "+20 %" faster / "-30 %" slower than normal, "Normal" in the middle
    function speedText(v) {
        const pct = Math.round(v * 100);
        return pct === 0 ? "Normal" : (pct > 0 ? "+" : "−") + Math.abs(pct) + " %";
    }
    function timesText(v) {
        return (Math.round(v * 100) / 100) + "×";
    }
    // a built-in touchpad has a hardware code for a name ("SYNA8018:00 06CB:CE67 Touchpad")
    function touchpadName(n) {
        return /^[A-Z0-9]+:[0-9A-F]{2}\b/.test(n) ? "Built-in touchpad" : n;
    }

    Component.onCompleted: Hw.pointerWatch = true
    Component.onDestruction: Hw.pointerWatch = false

    spacing: Theme.spacing * 8

    Tabs {
        anchors.horizontalCenter: parent.horizontalCenter
        options: [
            { "value": "mouse", "label": "Mouse", "icon": "mouse-fill" },
            { "value": "touchpad", "label": "Touchpad", "icon": "touch_app-fill" }
        ]
        value: page.tab
        onActivated: v => page.tab = v
    }

    // which device this tab is for
    component DeviceCard: Card {
        id: card
        opacity: Hw.pointersKnown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.motion.normal }
        }
        property string icon
        property var names: []
        property string none
        property string noneHint
        property string some
        width: parent ? parent.width : 0
        Row {
            spacing: Theme.spacing * 4
            Rectangle {
                width: 48
                height: 48
                radius: Theme.radius.lg
                color: card.names.length ? Theme.c.accentSoft : Theme.c.default
                Icon {
                    anchors.centerIn: parent
                    name: card.icon
                    size: 26
                    color: card.names.length ? Theme.c.accent : Theme.c.muted
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: card.width - 48 - Theme.spacing * 4 - 2 * Theme.card.padding
                spacing: Theme.spacing / 2
                Label {
                    width: parent.width
                    text: card.names.length ? card.names.join(", ") : card.none
                    weight: Theme.weightSemibold
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: card.names.length ? card.some : card.noneHint
                    color: Theme.c.muted
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ---- mouse ----
    DeviceCard {
        visible: page.tab === "mouse"
        icon: "mouse-fill"
        names: Hw.mice
        none: "No mouse connected"
        noneHint: "These settings are for a mouse you plug in or connect with Bluetooth. They'll apply as soon as you connect one. The built-in touchpad has its own tab."
        some: Hw.mice.length > 1 ? "Connected. These settings apply to every mouse." : "Connected. These settings are for the mouse only, not the touchpad."
    }
    SettingsGroup {
        visible: page.tab === "mouse"
        width: parent.width
        SettingsRow {
            title: "Main button"
            description: "The button you click with. The other one opens menus. Left-handed people often swap them."
            Tabs {
                options: [{ "value": false, "label": "Left" }, { "value": true, "label": "Right" }]
                value: page.flag("input.mouse.left-handed", false)
                onActivated: v => Niri.setFlag("input.mouse.left-handed", v)
            }
        }
        SettingsRow {
            title: "Pointer speed"
            wide: true
            Slider {
                width: parent.width
                from: -1
                to: 1
                stepSize: 0.05
                value: page.arg("input.mouse.accel-speed", 0)
                format: page.speedText
                onMoved: Niri.set("input.mouse.accel-speed", [Math.round(value * 100) / 100])
                marks: [{ "value": -1, "label": "Slower" }, { "value": 0, "label": "Normal" }, { "value": 1, "label": "Faster" }]
            }
        }
        SettingsRow {
            title: "Mouse acceleration"
            description: "The pointer travels further when you move the mouse quickly, and less when you move it slowly. Turn it off if you want the same hand movement to always move the pointer the same distance, as many gamers do."
            Switch {
                checked: page.arg("input.mouse.accel-profile", "adaptive") !== "flat"
                onToggled: Niri.set("input.mouse.accel-profile", [checked ? "adaptive" : "flat"])
            }
        }
    }
    SettingsGroup {
        visible: page.tab === "mouse"
        width: parent.width
        title: "Scrolling"
        SettingsRow {
            title: "Scroll direction"
            description: "Traditional: rolling the wheel down moves the page down. Natural: the page moves the other way, as if you were pushing it, like on a phone."
            Tabs {
                options: [{ "value": false, "label": "Traditional" }, { "value": true, "label": "Natural" }]
                value: page.flag("input.mouse.natural-scroll", false)
                onActivated: v => Niri.setFlag("input.mouse.natural-scroll", v)
            }
        }
        SettingsRow {
            title: "Scroll speed"
            description: "How far the page moves for each notch of the wheel."
            wide: true
            Slider {
                width: parent.width
                from: 0.25
                to: 3
                stepSize: 0.25
                value: page.arg("input.mouse.scroll-factor", 1)
                format: page.timesText
                onMoved: Niri.set("input.mouse.scroll-factor", [value])
                marks: [{ "value": 0.25, "label": "Slower" }, { "value": 1, "label": "Normal" }, { "value": 3, "label": "Faster" }]
            }
        }
        SettingsRow {
            title: "Middle click with both buttons"
            description: "For a mouse without a wheel: pressing the left and right buttons together does a middle click."
            Switch {
                checked: page.flag("input.mouse.middle-emulation", false)
                onToggled: Niri.setFlag("input.mouse.middle-emulation", checked)
            }
        }
    }

    // ---- touchpad ----
    readonly property bool touchpadOn: !flag("input.touchpad.off", false)
    readonly property bool tapOn: flag("input.touchpad.tap", false)
    DeviceCard {
        visible: page.tab === "touchpad"
        icon: "touch_app-fill"
        names: Hw.touchpads.map(page.touchpadName)
        none: "No touchpad found"
        noneHint: "These settings are for a laptop's touchpad, or one you connect. They'll apply when one is there."
        some: "These settings are for the touchpad only, not a mouse."
    }
    SettingsGroup {
        visible: page.tab === "touchpad"
        width: parent.width
        SettingsRow {
            title: "Use the touchpad"
            description: "Turn it off completely, or only while a mouse is connected, so a palm or a sleeve can't move the pointer."
            Select {
                width: Math.round(260 * Math.max(1, Theme.textScale))
                options: [
                    { "value": "on", "label": "Always" },
                    { "value": "external", "label": "Only without a mouse" },
                    { "value": "off", "label": "Never" }
                ]
                value: !page.touchpadOn ? "off" : page.flag("input.touchpad.disabled-on-external-mouse", false) ? "external" : "on"
                onActivated: v => {
                    Niri.setFlag("input.touchpad.off", v === "off");
                    Niri.setFlag("input.touchpad.disabled-on-external-mouse", v === "external");
                }
            }
        }
        SettingsRow {
            title: "Pointer speed"
            wide: true
            enabled: page.touchpadOn
            Slider {
                width: parent.width
                from: -1
                to: 1
                stepSize: 0.05
                value: page.arg("input.touchpad.accel-speed", 0)
                format: page.speedText
                onMoved: Niri.set("input.touchpad.accel-speed", [Math.round(value * 100) / 100])
                marks: [{ "value": -1, "label": "Slower" }, { "value": 0, "label": "Normal" }, { "value": 1, "label": "Faster" }]
            }
        }
        SettingsRow {
            title: "Pointer acceleration"
            description: "The pointer travels further when you swipe quickly, and less when you move slowly. Turn it off if you want the same finger movement to always move the pointer the same distance."
            enabled: page.touchpadOn
            Switch {
                checked: page.arg("input.touchpad.accel-profile", "adaptive") !== "flat"
                onToggled: Niri.set("input.touchpad.accel-profile", [checked ? "adaptive" : "flat"])
            }
        }
        SettingsRow {
            title: "Ignore the touchpad while typing"
            description: "For a moment after each key you press, touches are ignored, so a palm resting on the touchpad doesn't move the pointer."
            enabled: page.touchpadOn
            Switch {
                checked: page.flag("input.touchpad.dwt", false)
                onToggled: Niri.setFlag("input.touchpad.dwt", checked)
            }
        }
    }
    SettingsGroup {
        visible: page.tab === "touchpad"
        width: parent.width
        title: "Clicking"
        SettingsRow {
            title: "Tap to click"
            description: "A light tap counts as a click, so you don't have to press the touchpad down."
            enabled: page.touchpadOn
            Switch {
                checked: page.tapOn
                onToggled: Niri.setFlag("input.touchpad.tap", checked)
            }
        }
        SettingsRow {
            visible: page.tapOn
            title: "Tap with two fingers to"
            description: "With three fingers, you get the other one."
            enabled: page.touchpadOn
            Tabs {
                options: [{ "value": "left-right-middle", "label": "Right click" }, { "value": "left-middle-right", "label": "Middle click" }]
                value: page.arg("input.touchpad.tap-button-map", "left-right-middle")
                onActivated: v => Niri.set("input.touchpad.tap-button-map", [v])
            }
        }
        SettingsRow {
            visible: page.tapOn
            title: "Tap and drag"
            description: "Tap, then quickly put your finger back down and slide it to drag something, without pressing the touchpad."
            enabled: page.touchpadOn
            Switch {
                checked: page.arg("input.touchpad.drag", true) !== false
                onToggled: Niri.set("input.touchpad.drag", [checked])
            }
        }
        SettingsRow {
            visible: page.tapOn && page.arg("input.touchpad.drag", true) !== false
            title: "Keep dragging after lifting your finger"
            description: "Lets you lift your finger for a moment in the middle of a drag, to reach further, without dropping what you're dragging."
            enabled: page.touchpadOn
            Switch {
                checked: page.flag("input.touchpad.drag-lock", false)
                onToggled: Niri.setFlag("input.touchpad.drag-lock", checked)
            }
        }
        SettingsRow {
            title: "Right click by pressing"
            description: "How to right-click when you press the touchpad down."
            enabled: page.touchpadOn
            RadioGroup {
                options: [
                    { "value": "clickfinger", "label": "With two fingers", "description": "Press anywhere with two fingers" },
                    { "value": "button-areas", "label": "In the corner", "description": "Press the bottom-right corner" }
                ]
                value: page.arg("input.touchpad.click-method", "button-areas")
                onActivated: v => Niri.set("input.touchpad.click-method", [v])
            }
        }
    }
    SettingsGroup {
        visible: page.tab === "touchpad"
        width: parent.width
        title: "Scrolling"
        SettingsRow {
            title: "Scroll with"
            enabled: page.touchpadOn
            Tabs {
                options: [{ "value": "two-finger", "label": "Two fingers" }, { "value": "edge", "label": "The right edge" }]
                value: page.arg("input.touchpad.scroll-method", "two-finger")
                onActivated: v => Niri.set("input.touchpad.scroll-method", [v])
            }
        }
        SettingsRow {
            title: "Scroll direction"
            description: "Natural: the page follows your fingers, like on a phone. Traditional: it moves the other way, like a scroll bar."
            enabled: page.touchpadOn
            Tabs {
                options: [{ "value": false, "label": "Traditional" }, { "value": true, "label": "Natural" }]
                value: page.flag("input.touchpad.natural-scroll", false)
                onActivated: v => Niri.setFlag("input.touchpad.natural-scroll", v)
            }
        }
        SettingsRow {
            title: "Scroll speed"
            description: "How far the page moves for the same finger movement."
            wide: true
            enabled: page.touchpadOn
            Slider {
                width: parent.width
                from: 0.25
                to: 3
                stepSize: 0.25
                value: page.arg("input.touchpad.scroll-factor", 1)
                format: page.timesText
                onMoved: Niri.set("input.touchpad.scroll-factor", [value])
                marks: [{ "value": 0.25, "label": "Slower" }, { "value": 1, "label": "Normal" }, { "value": 3, "label": "Faster" }]
            }
        }
    }

    // ---- both ----
    readonly property real hideAfter: arg("cursor.hide-after-inactive-ms", 0)
    SettingsGroup {
        width: parent.width
        title: "Mouse and touchpad"
        SettingsRow {
            title: "Paste with the middle button"
            description: "Selecting text copies it on its own; a middle click pastes it. This is separate from the usual copy and paste."
            Switch {
                checked: !page.flag("clipboard.disable-primary", false)
                onToggled: Niri.setFlag("clipboard.disable-primary", !checked)
            }
        }
        SettingsRow {
            title: "Hide the pointer while typing"
            description: "It comes back as soon as you move it."
            Switch {
                checked: page.flag("cursor.hide-when-typing", false)
                onToggled: Niri.setFlag("cursor.hide-when-typing", checked)
            }
        }
        SettingsRow {
            title: "Hide the pointer when it's still"
            description: "Handy while watching or reading. It comes back as soon as you move it."
            Switch {
                checked: page.hideAfter > 0
                onToggled: checked ? Niri.set("cursor.hide-after-inactive-ms", [page.lastHide]) : Niri.remove("cursor.hide-after-inactive-ms")
            }
        }
        SettingsRow {
            visible: page.hideAfter > 0
            title: "Hide it after"
            wide: true
            Slider {
                width: parent.width
                from: 1
                to: 10
                stepSize: 1
                value: page.hideAfter / 1000
                format: v => Math.round(v) + (Math.round(v) === 1 ? " second" : " seconds")
                onMoved: {
                    page.lastHide = Math.round(value) * 1000;
                    Niri.set("cursor.hide-after-inactive-ms", [page.lastHide]);
                }
            }
        }
    }
    // the delay to come back to when the switch is turned on again
    property int lastHide: hideAfter > 0 ? hideAfter : 3000
}
