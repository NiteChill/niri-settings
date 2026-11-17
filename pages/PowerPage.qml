import QtQuick
import "../theme"
import "../services"
import "../components"

// Power: the battery as one big bar (the island's colors: green charging, yellow power saver, red low),
// the power modes as three pictures to pick from, then when the screen blanks and the laptop sleeps
// (through swayidle, which this page sets up and restarts).
Column {
    id: page
    spacing: Theme.spacing * 8

    function duration(s) {
        if (s <= 0)
            return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }
    readonly property color batteryColor: Hw.battery.charging ? Theme.c.success : Hw.profile === "saver" ? Theme.c.warning : Hw.battery.percent <= 15 ? Theme.c.danger : Theme.c.foreground

    // ---- battery ----
    // a battery but nothing reporting it (Deps: the doctor only counts UPower missing on a laptop)
    Missing {
        width: parent.width
        needs: ["upower"]
        what: "The battery level"
    }
    Rectangle {
        visible: Hw.battery.present
        width: parent.width
        // grows with its text (Accessibility > Text size)
        height: Math.max(Theme.spacing * 40, batteryColumn.height + Theme.spacing * 12)
        radius: Theme.card.radius
        color: Theme.c.surface
        border.width: Theme.cardBorder
        border.color: Theme.c.border
        Column {
            id: batteryColumn
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.spacing * 8
            spacing: Theme.spacing * 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing
                Label {
                    text: Hw.battery.percent
                    size: "3xl"
                    weight: Theme.weightSemibold
                    font.pixelSize: Theme.px(48)
                    font.features: { "tnum": 1 }
                }
                Label {
                    anchors.baseline: parent.children[0].baseline
                    text: "%"
                    size: "xl"
                    weight: Theme.weightSemibold
                    color: Theme.c.muted
                }
            }
            // the bar: a capsule filled to the level, the island's battery look stretched out
            Rectangle {
                width: parent.width
                height: Theme.spacing * 6
                radius: height / 2
                color: Theme.c.default
                Rectangle {
                    width: Math.max(height, parent.width * Hw.battery.percent / 100)
                    height: parent.height
                    radius: height / 2
                    color: page.batteryColor
                    Behavior on width {
                        Spring {
                            s: Theme.springSoft
                        }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.motion.slow }
                    }
                    Icon {
                        visible: Hw.battery.charging
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bolt-fill"
                        size: 16
                        color: Theme.c.successForeground
                    }
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Hw.battery.full ? "Fully charged" : Hw.battery.charging ? (page.duration(Hw.battery.timeToFull) ? "Full in " + page.duration(Hw.battery.timeToFull) : "Charging") : (page.duration(Hw.battery.timeToEmpty) ? page.duration(Hw.battery.timeToEmpty) + " left" : "On battery")
                color: Theme.c.muted
            }
        }
    }

    // ---- power mode ----
    Column {
        width: parent.width
        spacing: Theme.spacing * 2
        Label {
            leftPadding: Theme.spacing
            text: "Power mode"
            weight: Theme.weightSemibold
        }
        Missing {
            width: parent.width
            needs: ["powerprofiles"]
            what: "Changing the power mode"
        }
        Row {
            visible: Deps.has("powerprofiles")
            spacing: Theme.spacing * 4
            Repeater {
                model: [
                    { "value": "saver", "label": "Power saver", "sub": "Battery lasts longest", "icon": "island-eco-mode", "color": Theme.c.warning },
                    { "value": "balanced", "label": "Balanced", "sub": "Recommended", "icon": "island-gauge-balanced", "color": Theme.c.foreground },
                    { "value": "performance", "label": "Performance", "sub": "Fastest, but warmer and louder", "icon": "island-speed", "color": Theme.c.danger }
                ]
                TileOption {
                    id: mode
                    required property var modelData
                    visible: modelData.value !== "performance" || Hw.performanceAvailable
                    width: (page.width - 2 * Theme.spacing * 4) / 3
                    previewHeight: Theme.spacing * 24
                    label: modelData.label
                    sublabel: modelData.sub
                    selected: Hw.profile === modelData.value
                    onClicked: Hw.setProfile(modelData.value)
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.spacing * 14
                        height: width
                        radius: width / 2
                        color: mode.selected ? modelData.color : Theme.c.default
                        Behavior on color {
                            ColorAnimation { duration: Theme.motion.slow }
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: Theme.spacing * 7
                            color: mode.selected ? Theme.onColor(modelData.color) : Theme.c.muted
                        }
                    }
                }
            }
        }
    }

    // ---- blank and sleep: swayidle ----
    readonly property var idleNode: (Niri.revision, Niri.ownNodes(n => n.name === "spawn-at-startup" && n.args[0] === "swayidle")[0] || null)
    function idleTimeout(action, def) {
        if (!idleNode)
            return def;
        const a = idleNode.args;
        for (let i = 0; i < a.length - 2; i++)
            if (a[i] === "timeout" && a[i + 2].indexOf(action) >= 0)
                return Number(a[i + 1]);
        return 0;
    }
    readonly property int blankAfter: idleTimeout("power-off-monitors", 0)
    readonly property int suspendAfter: idleTimeout("systemctl suspend", 0)
    readonly property bool lockOnBlank: idleNode ? idleNode.args.join(" ").indexOf("swaylock") >= 0 && blankAfter > 0 : false
    function setIdle(blank, suspend, lock) {
        const args = ["swayidle", "-w"];
        if (lock && blank > 0)
            args.push("timeout", String(Math.max(1, blank - 5)), "swaylock -f -c 000000");
        if (blank > 0)
            args.push("timeout", String(blank), "niri msg action power-off-monitors");
        if (suspend > 0)
            args.push("timeout", String(suspend), "systemctl suspend");
        if (lock)
            args.push("before-sleep", "swaylock -f -c 000000");
        const on = blank > 0 || suspend > 0;
        Niri.replaceNodes(n => n.name === "spawn-at-startup" && n.args[0] === "swayidle", on ? [Kdl.node("spawn-at-startup", args)] : []);
        Env.write(["pkill", "-x", "swayidle"], () => {
            if (on)
                Env.launch(args);
        });
    }
    readonly property var lowLevels: {
        const l = Island.value("lowBattery.levels", [15, 5]);
        return l && l.length ? l : [15];
    }
    readonly property var times: [{ "value": 0, "label": "Never" }, { "value": 60, "label": "1 minute" }, { "value": 120, "label": "2 minutes" }, { "value": 300, "label": "5 minutes" }, { "value": 600, "label": "10 minutes" }, { "value": 900, "label": "15 minutes" }, { "value": 1800, "label": "30 minutes" }, { "value": 3600, "label": "1 hour" }]
    SettingsGroup {
        width: parent.width
        title: "When you're away"
        description: "What happens when you haven't touched the keyboard or the mouse for a while."
        Missing {
            needs: ["swayidle"]
            what: "Turning the screen off and sleeping"
        }
        SettingsRow {
            visible: Deps.has("swayidle")
            title: "Turn the screen off after"
            iconName: "dark_mode-fill"
            Select {
                width: Math.round(160 * Math.max(1, Theme.textScale))
                options: page.times
                value: page.blankAfter
                onActivated: v => page.setIdle(v, page.suspendAfter, page.lockOnBlank)
            }
        }
        SettingsRow {
            visible: Deps.has("swayidle")
            title: "Sleep after"
            iconName: "bedtime-fill"
            Select {
                width: Math.round(160 * Math.max(1, Theme.textScale))
                options: page.times
                value: page.suspendAfter
                onActivated: v => page.setIdle(page.blankAfter, v, page.lockOnBlank)
            }
        }
        Missing {
            visible: Deps.has("swayidle") && gone.length > 0
            needs: ["swaylock"]
            what: "Locking the screen"
        }
        SettingsRow {
            visible: Deps.has("swayidle") && Deps.has("swaylock")
            title: "Lock when the screen turns off"
            description: "Your password is needed to get back in. The computer also locks before it goes to sleep."
            iconName: "lock-fill"
            Switch {
                checked: page.lockOnBlank
                onToggled: page.setIdle(page.blankAfter || 300, page.suspendAfter, checked)
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Battery"
        SettingsRow {
            visible: Hw.battery.health >= 0
            title: "Battery health"
            description: "How much charge the battery can still hold, compared with when it was new. Batteries slowly wear out over the years."
            Chip {
                text: Hw.battery.health + " %"
                tone: Hw.battery.health < 70 ? "warning" : "success"
                variant: "soft"
            }
        }
        SettingsRow {
            title: "Low battery warning"
            islandOnly: true
            description: "A warning at the top of the screen, with a button to save power, when the battery runs low."
            Switch {
                checked: Island.value("lowBattery.enabled", true)
                onToggled: Island.set("lowBattery.enabled", checked)
            }
        }
        SettingsRow {
            visible: Island.installed && (Island.value("lowBattery.enabled", true))
            wide: true
            title: "Warn me at"
            islandOnly: true
            Slider {
                width: parent.width
                from: 10
                to: 30
                stepSize: 5
                value: page.lowLevels[0]
                format: v => Math.round(v) + " %"
                marks: [{ "value": 10, "label": "Later" }, { "value": 30, "label": "Earlier" }]
                onMoved: Island.set("lowBattery.levels", page.lowLevels.length > 1 ? [Math.round(value), 5] : [Math.round(value)])
            }
        }
        SettingsRow {
            visible: Island.installed && (Island.value("lowBattery.enabled", true))
            title: "Warn again at 5 %"
            islandOnly: true
            description: "A last reminder just before the computer turns itself off."
            Switch {
                checked: page.lowLevels.length > 1
                onToggled: Island.set("lowBattery.levels", checked ? [page.lowLevels[0], 5] : [page.lowLevels[0]])
            }
        }
        SettingsRow {
            title: "Show the charge when plugging in"
            islandOnly: true
            description: "A short animation at the top of the screen with the battery level, when you connect the charger."
            Switch {
                checked: Island.value("charging.enabled", true)
                onToggled: Island.set("charging.enabled", checked)
            }
        }
    }
}
