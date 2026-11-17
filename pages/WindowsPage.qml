import QtQuick
import "../theme"
import "../services"
import "../components"

// Windows & Workspaces: how niri lays windows out, shown rather than told. The width of new windows and
// where the focused one sits are picked from little live pictures of your desktop; the rest are
// switches. Advanced: struts, the empty workspace, back-and-forth.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Niri.revision
    readonly property real gaps: (rev, Niri.arg("layout.gaps", 16))
    readonly property real corner: (rev, Niri.arg("window-rule.geometry-corner-radius", 0))
    readonly property real width0: (rev, Niri.proportions("layout.default-column-width", [0.5])[0])
    readonly property string centerMode: (rev, Niri.arg("layout.center-focused-column", "never"))
    // hot corners: the corners on (none = off); niri uses the top-left one when the block names none
    readonly property var hotCorners: {
        rev;
        const n = Niri.node("gestures.hot-corners");
        if (!n || !n.children)
            return ["top-left"];
        const names = n.children.map(c => c.name);
        if (names.indexOf("off") >= 0)
            return [];
        const on = names.filter(c => ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(c) >= 0);
        return on.length ? on : ["top-left"];
    }
    // the corners to bring back when the switch is turned on again
    property var lastCorners: []
    function setHotCorners(list) {
        if (hotCorners.length)
            lastCorners = hotCorners;
        Niri.setBlock("gestures.hot-corners", list.length ? list.map(c => Kdl.node(c)) : [Kdl.node("off")]);
    }

    component Preview: WindowPreview {
        gaps: page.gaps
        radius: page.corner
        ringOn: (page.rev, Niri.onOff("layout.focus-ring", true))
        borderOn: (page.rev, Niri.onOff("layout.border", false))
        shadowOn: (page.rev, Niri.onOff("layout.shadow", false))
    }

    // ---- new windows ----
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Column {
            leftPadding: Theme.spacing
            spacing: Theme.spacing / 2
            Label {
                text: "Width of new windows"
                weight: Theme.weightSemibold
            }
            Label {
                text: "Windows open side by side in a row that you scroll through, so nothing ever gets squeezed. This is how much of the screen a new window takes at first. You can always resize it afterwards."
                color: Theme.c.muted
                width: page.width - Theme.spacing
                wrapMode: Text.Wrap
            }
        }
        Row {
            spacing: Theme.spacing * 3
            Repeater {
                model: [[1 / 3, "A third"], [0.5, "Half"], [2 / 3, "Two thirds"], [1, "Full"]]
                TileOption {
                    required property var modelData
                    width: (page.width - 3 * Theme.spacing * 3) / 4
                    previewHeight: width * 0.62
                    label: modelData[1]
                    selected: Math.abs(page.width0 - modelData[0]) < 0.01
                    onClicked: Niri.setBlock("layout.default-column-width", [Kdl.node("proportion", [Math.round(modelData[0] * 100000) / 100000])])
                    Preview {
                        anchors.fill: parent
                        columns: [modelData[0], modelData[0], modelData[0]]
                        center: true
                    }
                }
            }
        }
    }

    // ---- focused window position ----
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Column {
            leftPadding: Theme.spacing
            spacing: Theme.spacing / 2
            Label {
                text: "The window you're using"
                weight: Theme.weightSemibold
            }
            Label {
                text: "Where it sits on the screen when you move from one window to the next."
                color: Theme.c.muted
                width: page.width - Theme.spacing
                wrapMode: Text.Wrap
            }
        }
        Row {
            spacing: Theme.spacing * 3
            Repeater {
                model: [["never", "Where it is", "The view moves only as much as needed"], ["always", "In the middle", "Always centred on the screen"], ["on-overflow", "In the middle when needed", "Centred only if it wouldn't fit beside the others"]]
                TileOption {
                    required property var modelData
                    width: (page.width - 2 * Theme.spacing * 3) / 3
                    previewHeight: width * 0.5
                    label: modelData[1]
                    sublabel: modelData[2]
                    selected: page.centerMode === modelData[0]
                    onClicked: Niri.set("layout.center-focused-column", [modelData[0]])
                    Preview {
                        anchors.fill: parent
                        columns: [0.4, 0.4, 0.4, 0.4]
                        focused: 1
                        center: modelData[0] === "always"
                    }
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Windows"
        SettingsRow {
            title: "Centre a window that's alone"
            description: "When only one window is open on a screen, it sits in the middle instead of against the left edge."
            Switch {
                checked: (page.rev, Niri.flag("layout.always-center-single-column", false))
                onToggled: Niri.setFlag("layout.always-center-single-column", checked)
            }
        }
        SettingsRow {
            title: "Windows placed together show"
            description: "When you put several windows in the same spot, they can be stacked one above the other, or shown one at a time with tabs."
            Tabs {
                options: [{ "value": "normal", "label": "Stacked" }, { "value": "tabbed", "label": "Tabs" }]
                value: (page.rev, Niri.arg("layout.default-column-display", "normal"))
                onActivated: v => Niri.set("layout.default-column-display", [v])
            }
        }
        SettingsRow {
            title: "Select windows by pointing"
            description: "The window under the pointer becomes the one you type in, without clicking it."
            Switch {
                checked: (page.rev, Niri.flag("input.focus-follows-mouse", false))
                onToggled: Niri.setFlag("input.focus-follows-mouse", checked)
            }
        }
        SettingsRow {
            title: "Move the pointer with the keyboard"
            description: "When you switch windows with the keyboard, the pointer jumps to the window you switched to."
            Switch {
                checked: (page.rev, Niri.flag("input.warp-mouse-to-focus", false))
                onToggled: Niri.setFlag("input.warp-mouse-to-focus", checked)
            }
        }
        SettingsRow {
            title: "Window switcher"
            description: "Hold Alt and press Tab to see your recent windows with previews, then let go on the one you want."
            Switch {
                checked: (page.rev, Niri.onOff("recent-windows", true))
                onToggled: Niri.setOnOff("recent-windows", checked)
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Overview"
        SettingsRow {
            title: "Hot corners"
            description: "Push the pointer into a corner of the screen to see all your windows and workspaces at once."
            Switch {
                checked: page.hotCorners.length > 0
                onToggled: page.setHotCorners(checked ? (page.lastCorners.length ? page.lastCorners : ["top-left"]) : [])
            }
        }
        SettingsRow {
            visible: page.hotCorners.length > 0
            title: "Which corners"
            description: "Click a corner to turn it on or off."
            CornerPicker {
                corners: page.hotCorners
                onToggled: name => {
                    const next = page.hotCorners.indexOf(name) >= 0 ? page.hotCorners.filter(c => c !== name) : page.hotCorners.concat([name]);
                    page.setHotCorners(next);
                }
            }
        }
        SettingsRow {
            wide: true
            title: "Size of windows in the overview"
            description: "How big your windows look when you see them all at once."
            Slider {
                width: parent.width
                from: 0.25
                to: 0.75
                stepSize: 0.05
                value: (page.rev, Niri.arg("overview.zoom", 0.5))
                format: v => Math.round(v * 100) + " %"
                marks: [{ "value": 0.25, "label": "Smaller" }, { "value": 0.75, "label": "Larger" }]
                onMoved: Niri.set("overview.zoom", [Math.round(value * 100) / 100])
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Advanced"
        SettingsRow {
            title: "Keep an empty workspace at the top"
            description: "There's always a free workspace above the first one, as well as below the last one."
            Switch {
                checked: (page.rev, Niri.flag("layout.empty-workspace-above-first", false))
                onToggled: Niri.setFlag("layout.empty-workspace-above-first", checked)
            }
        }
        SettingsRow {
            title: "Go back with the same shortcut"
            description: "Pressing the shortcut for the workspace you're already on takes you back to the one you came from."
            Switch {
                checked: (page.rev, Niri.flag("input.workspace-auto-back-and-forth", false))
                onToggled: Niri.setFlag("input.workspace-auto-back-and-forth", checked)
            }
        }
        SettingsRow {
            wide: true
            title: "Space kept free at the edges"
            description: "Windows stay this many pixels away from each edge of the screen, to leave room for a dock or a panel. A negative number lets windows go closer than the usual gap."
            // four labelled fields; they wrap onto two lines in a narrow window
            Flow {
                width: parent.width
                spacing: Theme.spacing * 3
                Repeater {
                    model: ["top", "bottom", "left", "right"]
                    NumberField {
                        required property string modelData
                        width: Math.round(150 * Math.max(1, Theme.textScale))
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        suffix: "px"
                        from: -200
                        to: 400
                        value: (page.rev, Niri.arg("layout.struts." + modelData, 0))
                        onValueModified: v => Niri.set("layout.struts." + modelData, [v])
                    }
                }
            }
        }
    }
}
