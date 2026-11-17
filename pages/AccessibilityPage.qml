import QtQuick
import "../theme"
import "../services"
import "../components"

// Accessibility: bigger text, a bigger pointer (pictures of the sizes), less motion, more contrast, the
// screen reader.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Niri.revision
    readonly property real textScale: Desktop.get("interface", "text-scaling-factor", 1)
    // the size the slider is on: the sample follows it while dragging; the whole app (and the desktop)
    // takes it on release, so the page doesn't grow under the pointer mid-drag
    property real previewScale: textScale
    onTextScaleChanged: previewScale = textScale
    function applyTextScale(v) {
        Desktop.set("interface", "text-scaling-factor", Math.round(v * 100) / 100);
    }
    readonly property int cursorSize: Desktop.get("interface", "cursor-size", 24)

    SettingsGroup {
        width: parent.width
        title: "Seeing"
        SettingsRow {
            wide: true
            title: "Text size"
            description: "Makes text bigger or smaller in apps and menus. A few older apps may not follow it."
            Column {
                width: parent.width
                spacing: Theme.spacing * 3
                Slider {
                    width: parent.width
                    from: 0.8
                    to: 1.6
                    stepSize: 0.05
                    value: page.textScale
                    format: v => Math.round(v * 100) + " %"
                    marks: [{ "value": 0.8, "label": "Smaller" }, { "value": 1, "label": "Normal" }, { "value": 1.6, "label": "Larger" }]
                    onMoved: {
                        page.previewScale = value;
                        if (!pressed)
                            page.applyTextScale(value);   // keys, wheel: at once
                    }
                    onPressedChanged: if (!pressed && Math.abs(value - page.textScale) > 0.001) page.applyTextScale(value)
                }
                Label {
                    text: "The quick brown fox jumps over the lazy dog."
                    font.pixelSize: Theme.text.sm / Theme.textScale * page.previewScale
                    color: Theme.c.muted
                }
            }
        }
        SettingsRow {
            title: "High contrast"
            description: "Stronger outlines and colours that are easier to tell apart, in apps that support it."
            Switch {
                checked: Desktop.get("a11y", "high-contrast", false)
                onToggled: Desktop.set("a11y", "high-contrast", checked)
            }
        }
    }

    // pointer size: the real arrow, drawn at each size
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Label {
            leftPadding: Theme.spacing
            text: "Pointer size"
            weight: Theme.weightSemibold
        }
        Row {
            spacing: Theme.spacing * 3
            Repeater {
                model: [[24, "Default"], [32, "Medium"], [48, "Large"], [64, "Larger"]]
                TileOption {
                    required property var modelData
                    width: (page.width - 3 * Theme.spacing * 3) / 4
                    previewHeight: 96
                    label: modelData[1]
                    selected: page.cursorSize === modelData[0]
                    onClicked: {
                        Desktop.set("interface", "cursor-size", modelData[0]);
                        Niri.set("cursor.xcursor-size", [modelData[0]]);
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: "arrow_selector_tool-fill"
                        size: modelData[0]
                        color: Theme.c.foreground
                    }
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Motion"
        SettingsRow {
            title: "Reduce animation"
            description: "Windows and menus appear and switch instantly instead of sliding and fading. Helpful if motion on screen makes you feel unwell."
            Switch {
                // niri's animations { on / off } (`off false` isn't valid KDL for niri)
                checked: (page.rev, !Niri.onOff("animations", true))
                onToggled: {
                    Niri.setOnOff("animations", !checked);
                    Desktop.set("interface", "enable-animations", !checked);
                }
            }
        }
        SettingsRow {
            visible: (page.rev, Niri.onOff("animations", true))
            wide: true
            title: "Animation speed"
            description: "How fast windows and workspaces slide when they move."
            Slider {
                width: parent.width
                from: 2
                to: 0.5
                stepSize: 0.1
                value: (page.rev, Niri.arg("animations.slowdown", 1))
                format: v => v === 1 ? "Normal" : (1 / v).toFixed(1) + "× speed"
                marks: [{ "value": 2, "label": "Slower" }, { "value": 1, "label": "Normal" }, { "value": 0.5, "label": "Faster" }]
                onMoved: Niri.set("animations.slowdown", [Math.round(value * 10) / 10])
            }
        }
    }

    property bool hasOrca: false
    Component.onCompleted: Env.readFor(page, ["sh", "-c", "command -v orca"], code => page.hasOrca = code === 0)
    SettingsGroup {
        width: parent.width
        title: "Hearing and reading"
        SettingsRow {
            title: "Screen reader"
            description: "Reads aloud what's on the screen and what you type, for people who are blind or have low vision."
            enabled: page.hasOrca
            Switch {
                checked: Desktop.get("a11yApps", "screen-reader-enabled", false)
                onToggled: {
                    Desktop.set("a11yApps", "screen-reader-enabled", checked);
                    if (checked)
                        Env.launch(["orca"]);
                    else
                        Env.write(["pkill", "-x", "orca"]);
                }
            }
        }
        SettingsRow {
            title: "Visual alerts"
            islandOnly: true
            description: "Alerts appear on the screen only, without a sound. Alert sounds stay off while this is on."
            Switch {
                checked: !Island.value("sounds.enabled", true)
                onToggled: Island.set("sounds.enabled", !checked)
            }
        }
    }
}
