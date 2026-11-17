import QtQuick
import Quickshell.Widgets
import "../theme"
import "../services"
import "../components"

// Dynamic Island: every look picked from pictures of the island itself on your wallpaper (corner style,
// floating or attached, solid or blurred), then what the resting island shows and how it behaves. The
// ~650 finer settings stay in its config file (a button opens it).
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Island.revision
    readonly property string shape: (rev, Island.value("island.shape", "full"))
    readonly property bool attached: (rev, Island.value("island.attachToTop", false))
    readonly property bool blur: (rev, Island.value("island.blur", false))

    // ---- hero: the island as it is now ----
    // a ClippingRectangle: a plain Rectangle's `clip` cuts square, so the wallpaper covered its corners
    ClippingRectangle {
        width: parent.width
        height: width * 0.3
        radius: Theme.card.radius
        color: Theme.c.surface
        border.width: Theme.cardBorder
        border.color: Theme.c.border
        IslandPreview {
            anchors.fill: parent
            shape: page.shape
            attached: page.attached
            blur: page.blur
            islandShare: 0.5
        }
    }

    component Section: Column {
        id: section
        property string title
        property string description
        default property alias tiles: row.data
        width: page.width
        spacing: Theme.spacing * 3
        Column {
            leftPadding: Theme.spacing
            spacing: Theme.spacing / 2
            Label {
                text: section.title
                weight: Theme.weightSemibold
            }
            Label {
                visible: text !== ""
                text: section.description
                color: Theme.c.muted
                width: page.width - Theme.spacing
                wrapMode: Text.Wrap
            }
        }
        Row {
            id: row
            spacing: Theme.spacing * 3
        }
    }

    Section {
        title: "Corners"
        description: "How rounded the island at the top of the screen looks. Its buttons and lists follow the same style."
        Repeater {
            model: [["square", "Square"], ["soft", "Soft"], ["round", "Round"], ["full", "Full"]]
            TileOption {
                required property var modelData
                width: (page.width - 3 * Theme.spacing * 3) / 4
                previewHeight: width * 0.5
                label: modelData[1]
                selected: page.shape === modelData[0]
                onClicked: Island.set("island.shape", modelData[0])
                IslandPreview {
                    anchors.fill: parent
                    shape: modelData[0]
                    attached: page.attached
                    blur: page.blur
                }
            }
        }
    }

    Section {
        title: "Position"
        description: "Float the island just below the top edge of the screen, or attach it to the edge."
        Repeater {
            model: [[false, "Floating", "A small gap above it"], [true, "Attached to the top", "Grows out of the screen's edge"]]
            TileOption {
                required property var modelData
                width: (page.width - Theme.spacing * 3) / 2
                previewHeight: width * 0.32
                label: modelData[1]
                sublabel: modelData[2]
                selected: page.attached === modelData[0]
                onClicked: Island.set("island.attachToTop", modelData[0])
                IslandPreview {
                    anchors.fill: parent
                    shape: page.shape
                    attached: modelData[0]
                    blur: page.blur
                    islandShare: 0.6
                }
            }
        }
    }

    Section {
        title: "Material"
        description: "Solid black, or see-through glass that blurs what's behind it."
        Repeater {
            model: [[false, "Solid", "Black, like the iPhone's"], [true, "Blurred", "See-through, softens what's behind"]]
            TileOption {
                required property var modelData
                width: (page.width - Theme.spacing * 3) / 2
                previewHeight: width * 0.32
                label: modelData[1]
                sublabel: modelData[2]
                selected: page.blur === modelData[0]
                onClicked: Island.set("island.blur", modelData[0])
                IslandPreview {
                    anchors.fill: parent
                    shape: page.shape
                    attached: page.attached
                    blur: modelData[0]
                    islandShare: 0.6
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        SettingsRow {
            visible: page.blur
            wide: true
            title: "Background opacity"
            description: "How dark the glass is. Lower lets more of your wallpaper show through."
            Slider {
                width: parent.width
                from: 0.2
                to: 0.9
                stepSize: 0.05
                value: (page.rev, Island.value("island.blurOpacity", 0.55))
                format: v => Math.round(v * 100) + " %"
                marks: [{ "value": 0.2, "label": "Glassy" }, { "value": 0.9, "label": "Dark" }]
                onMoved: Island.set("island.blurOpacity", Math.round(value * 100) / 100)
            }
        }
        SettingsRow {
            wide: true
            title: "Corner smoothness"
            description: "Corners that curve gently into the straight edges, like on a phone. Turning it off saves a little power on older computers."
            Slider {
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.05
                format: v => v < 0.025 ? "Off" : Math.round(v * 100) + " %"
                value: (page.rev, Island.value("island.cornerSmoothing", 0.6))
                marks: [{ "value": 0, "label": "Off" }, { "value": 1, "label": "Smoothest" }]
                onMoved: Island.set("island.cornerSmoothing", Math.round(value * 100) / 100)
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "At rest"
        SettingsRow {
            title: "Date next to the clock"
            description: "Shows today's date beside the time."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                readonly property var now: new Date()
                options: ["", "ddd d", "d MMM", "ddd d MMM"].map(f => ({ "value": f, "label": f === "" ? "None" : Qt.formatDate(now, f) }))
                value: (page.rev, Island.value("idle.clock.dateFormat", ""))
                onActivated: v => Island.set("idle.clock.dateFormat", v)
            }
        }
        SettingsRow {
            title: "Music bars"
            description: "Little bars that move to the music while something plays. Click them to see what's playing."
            Row {
                spacing: Theme.spacing * 3
                Tabs {
                    visible: (page.rev, Island.value("idle.media.show", true))
                    options: [{ "value": true, "label": "Left" }, { "value": false, "label": "Right" }]
                    value: (page.rev, Island.value("idle.media.left", true))
                    onActivated: v => Island.set("idle.media.left", v)
                }
                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: (page.rev, Island.value("idle.media.show", true))
                    onToggled: Island.set("idle.media.show", checked)
                }
            }
        }
        SettingsRow {
            title: "Bluetooth icon"
            description: "Shown while a Bluetooth device, such as headphones, is connected."
            Switch {
                checked: (page.rev, Island.value("idle.bluetooth.show", true))
                onToggled: Island.set("idle.bluetooth.show", checked)
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Behaviour"
        SettingsRow {
            title: "Click the middle for quick settings"
            description: "Clicking the empty space between the clock and the icons opens quick controls for Wi-Fi, Bluetooth, Focus, sound and brightness."
            Switch {
                checked: (page.rev, Island.value("idle.middleOpensQuickSettings", true))
                onToggled: Island.set("idle.middleOpensQuickSettings", checked)
            }
        }
        SettingsRow {
            title: "Click outside to close"
            description: "An open panel closes when you click anywhere else on the screen."
            Switch {
                checked: (page.rev, Island.value("island.clickOutsideCloses", true))
                onToggled: Island.set("island.clickOutsideCloses", checked)
            }
        }
        SettingsRow {
            wide: true
            title: "Close after the pointer leaves"
            description: "How long an open panel waits before closing once the pointer moves away from it."
            Slider {
                width: parent.width
                from: 0
                to: 3000
                stepSize: 100
                value: (page.rev, Island.value("island.collapseDelay", 600))
                format: v => v === 0 ? "Right away" : (v / 1000).toFixed(1) + " s"
                showOutput: true
                onMoved: Island.set("island.collapseDelay", value)
            }
        }
        SettingsRow {
            title: "Say goodbye"
            description: "When you shut down or restart, the island writes “bye bye” by hand before the screen goes dark."
            Switch {
                checked: (page.rev, Island.value("goodbye.enabled", true))
                onToggled: Island.set("goodbye.enabled", checked)
            }
        }
    }

    Banner {
        tone: "default"
        iconName: "tune"
        title: "Everything else"
        description: "Sizes, colours, timings and motion: about 650 more settings to fine-tune the island, each explained in plain words. They are kept in a text file you can edit."
        actionText: "Open the file"
        onAction: Env.launch(["xdg-open", Env.islandDir + "/config/config.jsonc"])
    }
}
