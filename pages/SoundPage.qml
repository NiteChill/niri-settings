import QtQuick
import Quickshell.Services.Pipewire
import "../theme"
import "../services"
import "../components"

// Sound: output (device, volume, balance, a test sound), input (device, volume, a live level meter while
// this page is open, a recording to hear yourself: components/MicTest), the volume mixer (each stream's
// volume), and the island's alert sounds.
Column {
    id: page
    Component.onCompleted: Hw.soundWatch = true
    Component.onDestruction: Hw.soundWatch = false
    spacing: Theme.spacing * 8

    // past 100 % only through the island (its volume keys and this slider share its limit)
    readonly property real maxVolume: Island.installed ? Island.value("volume.max", 1.2) : 1
    // the highest volume to come back to when the switch is turned on again
    property real lastBoost: maxVolume > 1 ? maxVolume : 1.2

    SettingsGroup {
        width: parent.width
        title: "Output"
        SettingsRow {
            title: "Output device"
            description: "Where the sound plays: speakers, headphones or a screen."
            Select {
                width: Math.round(260 * Math.max(1, Theme.textScale))
                options: Hw.sinks.map(s => ({ "value": s.id, "label": s.name }))
                value: Hw.sink ? Hw.sink.id : -1
                onActivated: v => Hw.setDefaultSink(v)
            }
        }
        SettingsRow {
            wide: true
            title: "Volume"
            Row {
                width: parent.width
                spacing: Theme.spacing * 3
                Button {
                    anchors.bottom: parent.bottom
                    variant: "ghost"
                    size: "sm"
                    iconName: Hw.sink && Hw.sink.audio && Hw.sink.audio.muted ? Theme.volumeMuted : "island-volume-up"
                    onClicked: if (Hw.sink) Hw.setMuted(Hw.sink.id, !Hw.sink.audio.muted)
                }
                Slider {
                    width: parent.width - 32 - Theme.spacing * 3
                    from: 0
                    to: page.maxVolume
                    stepSize: 0.01
                    value: Hw.sink && Hw.sink.audio ? Hw.level(Hw.sink.audio) : 0
                    format: v => Math.round(v * 100) + " %"
                    marks: page.maxVolume > 1 ? [{ "value": 0, "label": "0" }, { "value": 1, "label": "100 %" }, { "value": page.maxVolume, "label": Math.round(page.maxVolume * 100) + " %" }] : []
                    onMoved: if (Hw.sink) Hw.setVolume(Hw.sink.id, value)
                }
            }
        }
        SettingsRow {
            wide: true
            title: "Balance"
            description: "How loud the left speaker is compared with the right one."
            visible: Hw.sink && Hw.sink.audio && Hw.sink.audio.volumes.length === 2
            Slider {
                width: parent.width
                from: -1
                to: 1
                stepSize: 0.05
                format: v => Math.abs(v) < 0.025 ? "Centre" : (v < 0 ? "Left " : "Right ") + Math.round(Math.abs(v) * 100) + " %"
                value: Hw.balance
                marks: [{ "value": -1, "label": "Left" }, { "value": 0, "label": "Centre" }, { "value": 1, "label": "Right" }]
                onMoved: Hw.setBalance(value)
            }
        }
        SettingsRow {
            title: "Over-amplification"
            islandOnly: true
            description: "Lets you turn the volume up past 100 % when a video or a call is too quiet. Above 100 %, sound can crackle or distort, and small speakers can rattle."
            Switch {
                checked: page.maxVolume > 1
                onToggled: Island.set("volume.max", checked ? page.lastBoost : 1)
            }
        }
        SettingsRow {
            visible: Island.installed && (page.maxVolume > 1)
            wide: true
            title: "Maximum volume"
            islandOnly: true
            description: "How far past 100 % the volume can go, with the volume keys and here."
            Slider {
                width: parent.width
                from: 1.05
                to: 1.5
                stepSize: 0.05
                value: page.maxVolume
                format: v => Math.round(v * 100) + " %"
                marks: [{ "value": 1.05, "label": "A little louder" }, { "value": 1.5, "label": "Loudest" }]
                onMoved: {
                    const v = Math.round(value * 100) / 100;
                    page.lastBoost = v;
                    Island.set("volume.max", v);
                }
            }
        }
        // the tests play and record through PipeWire's own tools
        Missing {
            needs: ["pipewire"]
            what: "Testing your speakers and microphone"
        }
        SettingsRow {
            visible: Deps.has("pipewire")
            title: "Test"
            description: "Plays a short sound so you can check the volume."
            Button {
                text: "Play a sound"
                iconName: "play_arrow-fill"
                variant: "secondary"
                size: "sm"
                onClicked: Env.launch(["pw-play", Env.islandDir + "/assets/sounds/notification.wav"])
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Input"
        SettingsRow {
            title: "Microphone"
            description: "Which microphone apps listen to."
            Select {
                width: Math.round(260 * Math.max(1, Theme.textScale))
                options: Hw.sources.map(s => ({ "value": s.id, "label": s.name }))
                value: Hw.source ? Hw.source.id : -1
                onActivated: v => Hw.setDefaultSource(v)
            }
        }
        SettingsRow {
            wide: true
            title: "Input volume"
            description: "How loud your voice is for others. If people say you sound too quiet, turn it up."
            Slider {
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.01
                value: Hw.source && Hw.source.audio ? Hw.level(Hw.source.audio) : 0
                format: v => Math.round(v * 100) + " %"
                onMoved: if (Hw.source) Hw.setVolume(Hw.source.id, value)
            }
        }
        SettingsRow {
            wide: true
            title: "Level"
            description: "Say something: the dots light up when your microphone hears you."
            // live input level: 24 dots that light up with the peak
            Row {
                spacing: Theme.spacing * 1.5
                PwNodePeakMonitor {
                    id: meter
                    node: Hw.source
                    enabled: page.visible
                }
                Repeater {
                    model: 24
                    Rectangle {
                        required property int index
                        width: (page.width - 2 * Theme.card.padding - 23 * Theme.spacing * 1.5) / 24
                        height: Theme.spacing * 2
                        radius: height / 2
                        color: index / 24 < Math.sqrt(meter.peak) ? (index > 20 ? Theme.c.danger : Theme.c.accent) : Theme.c.default
                    }
                }
            }
        }
        // try the microphone: record a few seconds, then hear them back (components/MicTest)
        SettingsRow {
            visible: Deps.has("pipewire")
            wide: true
            title: "Test your microphone"
            description: micTest.mode === "recording" ? "Recording… say something. It stops by itself after " + micTest.maxSeconds + " seconds." : micTest.mode === "" ? "Record a few seconds, then play them back to hear how you sound to others." : "This is how you sound to others."
            MicTest {
                id: micTest
                width: parent.width
                peak: meter.peak
                available: !!Hw.source
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Volume mixer"
        description: Hw.streams.length === 0 ? "Each app playing sound shows up here, with its own volume." : "Each app's own volume. A browser shows each tab that plays sound."
        // one row per stream: what's playing (a browser has one per tab), from which app and site, its
        // live level, mute and volume
        Repeater {
            model: KeyedModel {
                values: Hw.streams
                key: "id"
            }
            SettingsRow {
                id: streamRow
                required property var model
                readonly property var modelData: model
                // the app's own icon: its desktop entry when the stream names it, else the stream's icon
                readonly property var entry: Host.apps.find(a => a.id === model.appId + ".desktop" || a.id.toLowerCase() === (model.appId + ".desktop").toLowerCase()) || null
                wide: true
                title: model.title !== "" ? model.title : model.app
                description: [model.title !== "" ? (entry ? entry.name : model.app) : "", model.site].filter(x => x).join(" · ")
                appIcon: entry && entry.icon ? entry.icon : (model.icon || model.appId || model.app.toLowerCase())
                appIconFallback: entry ? entry.name : model.app
                Column {
                    width: parent.width
                    spacing: Theme.spacing * 1.5
                    Row {
                        width: parent.width
                        spacing: Theme.spacing * 3
                        Button {
                            anchors.verticalCenter: parent.verticalCenter
                            variant: "ghost"
                            size: "sm"
                            iconName: streamRow.model.muted ? Theme.volumeMuted : "island-volume-up"
                            onClicked: Hw.setMuted(streamRow.model.id, !streamRow.model.muted)
                        }
                        Slider {
                            width: parent.width - 32 - Theme.spacing * 3
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            stepSize: 0.01
                            format: v => streamRow.model.muted ? "Muted" : Math.round(v * 100) + " %"
                            value: streamRow.model.volume
                            onMoved: Hw.setVolume(streamRow.model.id, value)
                        }
                    }
                    // what it's playing right now: a thin line that moves with the sound (still = silent)
                    Item {
                        x: 32 + Theme.spacing * 3
                        width: parent.width - x
                        height: 4
                        PwNodePeakMonitor {
                            id: level
                            node: Hw._node(streamRow.model.id)
                            enabled: page.visible
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Theme.c.default
                        }
                        Rectangle {
                            // square root: quiet sound still shows, like the microphone's dots
                            width: parent.width * Math.min(1, Math.sqrt(level.peak))
                            height: parent.height
                            radius: height / 2
                            color: streamRow.model.muted ? Theme.c.muted : Theme.c.success
                            Behavior on width {
                                NumberAnimation { duration: Theme.dur(80) }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Alert sounds"
        islandOnly: true
        description: "Short, soft sounds for things worth hearing when you're not looking at the screen, such as a new message or a low battery."
        SettingsRow {
            title: "Alert sounds"
            Switch {
                checked: Island.value("sounds.enabled", true)
                onToggled: Island.set("sounds.enabled", checked)
            }
        }
        SettingsRow {
            visible: Island.value("sounds.enabled", true)
            wide: true
            title: "Alert volume"
            Slider {
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.05
                value: Island.value("sounds.volume", 0.45)
                format: v => Math.round(v * 100) + " %"
                onMoved: Island.set("sounds.volume", Math.round(value * 100) / 100)
            }
        }
        Repeater {
            model: [["notification", "Notifications"], ["lowBattery", "Low battery"], ["charging", "Charging"], ["headphones", "Headphones connected"], ["wifiConnected", "Wi-Fi connected"]]
            SettingsRow {
                required property var modelData
                visible: Island.value("sounds.enabled", true)
                title: modelData[1]
                Row {
                    spacing: Theme.spacing * 2
                    Button {
                        visible: Deps.has("pipewire")
                        size: "sm"
                        variant: "ghost"
                        iconName: "play_arrow-fill"
                        onClicked: Env.launch(["pw-play", "--volume", String(Island.value("sounds.volume", 0.45)), Env.islandDir + "/assets/sounds/" + modelData[0] + ".wav"])
                    }
                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Island.value("sounds." + modelData[0] + ".enabled", true)
                        onToggled: Island.set("sounds." + modelData[0] + ".enabled", checked)
                    }
                }
            }
        }
    }
}
