import QtQuick
import "../theme"
import "../services"
import "../components"

// Notifications: Focus (the desktop's do-not-disturb, shared with the island's Focus switch), how
// notifications behave in the island, hiding them while sharing the screen, and each alert the island
// can show, on / off.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Island.revision
    readonly property bool focusOn: Desktop.get("notifications", "show-banners", true) === false

    // Focus: a big tile like the island's quick settings switch
    Rectangle {
        width: parent.width
        height: Theme.spacing * 24
        radius: Theme.card.radius
        color: page.focusOn ? Theme.c.accentSoft : Theme.c.surface
        Behavior on color {
            ColorAnimation { duration: Theme.motion.slow }
        }
        Row {
            x: Theme.spacing * 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing * 4
            Rectangle {
                width: Theme.spacing * 12
                height: width
                radius: width / 2
                color: page.focusOn ? Theme.c.accent : Theme.c.default
                Behavior on color {
                    ColorAnimation { duration: Theme.motion.slow }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "do_not_disturb_on-fill"
                    size: 26
                    color: page.focusOn ? Theme.c.accentForeground : Theme.c.muted
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing
                Label {
                    text: "Focus"
                    size: "lg"
                    weight: Theme.weightSemibold
                }
                Label {
                    text: page.focusOn ? "On: notifications wait quietly" : (Island.installed ? "Off: notifications show in the island" : "Off: notifications show as usual")
                    color: Theme.c.muted
                }
            }
        }
        Switch {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing * 6
            anchors.verticalCenter: parent.verticalCenter
            checked: page.focusOn
            onToggled: Desktop.set("notifications", "show-banners", !checked)
        }
    }

    SettingsGroup {
        width: parent.width
        title: "In the island"
        islandOnly: true
        SettingsRow {
            title: "Show notifications"
            description: "Messages from your apps appear at the top of the screen."
            Switch {
                checked: (page.rev, Island.value("notifications.enabled", true))
                onToggled: Island.set("notifications.enabled", checked)
            }
        }
        SettingsRow {
            wide: true
            title: "How long they stay"
            description: "How long a notification stays on the screen before it tucks itself away."
            Slider {
                width: parent.width
                from: 2000
                to: 15000
                stepSize: 500
                value: (page.rev, Island.value("notifications.timeout", 5000))
                format: v => (v / 1000).toFixed(v % 1000 ? 1 : 0) + " s"
                showOutput: true
                onMoved: Island.set("notifications.timeout", value)
            }
        }
        SettingsRow {
            title: "Urgent ones during Focus"
            description: "Important notifications, such as a low battery or an alarm, still appear while Focus is on."
            Switch {
                checked: (page.rev, Island.value("notifications.dndAllowsCritical", true))
                onToggled: Island.set("notifications.dndAllowsCritical", checked)
            }
        }
        SettingsRow {
            title: "Quiet during Focus"
            description: "No alert sounds while Focus is on, except the low battery warning."
            Switch {
                checked: (page.rev, Island.value("sounds.respectFocus", true))
                onToggled: Island.set("sounds.respectFocus", checked)
            }
        }
        SettingsRow {
            id: shareRow
            readonly property bool on: (Niri.revision, Niri.ownNodes(n => n.name === "layer-rule" && (n.children || []).some(c => c.name === "block-out-from")).length > 0)
            title: "Hide while sharing the screen"
            description: "When you share or record your screen, the people watching don't see your notifications."
            Switch {
                checked: shareRow.on
                onToggled: Niri.replaceNodes(n => n.name === "layer-rule" && (n.children || []).some(c => c.name === "block-out-from"), checked ? [Kdl.node("layer-rule", [], {}, [Kdl.node("match", [], { "namespace": "^quickshell$" }), Kdl.node("block-out-from", ["screencast"])])] : [])
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Alerts"
        islandOnly: true
        description: "Short messages that appear by themselves, for example when you plug in headphones or the battery is charging."
        Repeater {
            model: [
                ["volume", "Volume", "When you change the volume", "island-volume-up"],
                ["brightness", "Brightness", "When you change the brightness", "island-brightness-6"],
                ["microphone", "Microphone", "When you mute or unmute it", "island-mic"],
                ["lowBattery", "Low battery", "At 15 % and 5 %", "island-battery"],
                ["charging", "Charging", "When you plug in", "island-bolt"],
                ["wifiConnected", "Wi-Fi connected", "When you join a network", "island-wifi3"],
                ["headphones", "Headphones", "When headphones connect", "island-headphone"],
                ["nowPlaying", "Now playing", "When music starts after a break", "island-music-note"],
                ["message", "Messages", "Short messages from apps and scripts", "article-fill"]
            ]
            SettingsRow {
                required property var modelData
                title: modelData[1]
                description: modelData[2]
                iconName: modelData[3]
                Switch {
                    checked: (page.rev, Island.value(modelData[0] + ".enabled", true))
                    onToggled: Island.set(modelData[0] + ".enabled", checked)
                }
            }
        }
    }
}
