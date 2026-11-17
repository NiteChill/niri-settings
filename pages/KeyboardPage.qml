import QtQuick
import "../theme"
import "../services"
import "../components"

// Keyboard: input sources (layouts, in order, with their variants), the keys that switch them, compose and
// Caps Lock, key repeat with a field to try it. The Shortcuts tab is pages/ShortcutsTab.qml.
Column {
    id: page
    spacing: Theme.spacing * 8

    // the app's window: the shortcut recorder asks the compositor to hand it every key
    property var window: null
    property string tab: "typing"
    property bool shortcutsOpened: false
    onTabChanged: if (tab === "shortcuts") shortcutsOpened = true
    readonly property int rev: Niri.revision
    // The layout in use. While niri's config names none, niri uses the system's (localectl's X11 layout,
    // e.g. French AZERTY), so that's what's shown, never a made-up "us". And as soon as the config sets
    // any keyboard field, niri stops reading the system's: so every change writes the layout, variant and
    // options together, starting from what's really in use (a Caps Lock change once turned AZERTY to US).
    property var system: ({ "layout": "", "variant": "", "options": "" })
    readonly property bool configured: (rev, Niri.node("input.keyboard.xkb.layout") !== null)
    function current(key, def) {
        return configured ? String((rev, Niri.arg("input.keyboard.xkb." + key, def))) : (system[key] || def);
    }
    readonly property var layouts: current("layout", "us").split(",").filter(x => x !== "")
    readonly property var variants: current("variant", "").split(",")
    readonly property var options: current("options", "").split(",").filter(x => x !== "")
    function writeXkb(ls, vs, opts) {
        Niri.set("input.keyboard.xkb.layout", [ls.join(",")]);
        Niri.set("input.keyboard.xkb.variant", [ls.map((l, i) => vs[i] || "").join(",")]);
        Niri.set("input.keyboard.xkb.options", [opts.join(",")]);
    }
    function option(prefix) {
        return options.find(o => o.startsWith(prefix + ":")) || "";
    }
    function setOption(prefix, value) {
        const next = options.filter(o => !o.startsWith(prefix + ":"));
        if (value)
            next.push(value);
        writeXkb(layouts, variants, next);
    }
    function setLayouts(ls, vs) {
        writeXkb(ls, vs, options);
    }

    // xkb's list of layouts and variants, read once
    property var known: []          // [{ code, name }]
    property var knownVariants: ({}) // code -> [{ code, name }]
    // the system's layout (what niri uses while its config names none)
    Item {
        Component.onCompleted: Env.readFor(page, ["localectl", "status"], (code, out) => {
            const get = k => ((out.match(new RegExp("X11 " + k + ":\\s*(\\S+)")) || [])[1] || "");
            page.system = { "layout": get("Layout"), "variant": get("Variant"), "options": get("Options") };
        })
    }
    Component.onCompleted: Env.readFor(page, ["cat", "/usr/share/X11/xkb/rules/evdev.lst"], (code, out) => {
        let section = "";
        const ls = [], vs = {};
        for (const line of out.split("\n")) {
            if (line.startsWith("!")) {
                section = line.slice(2).trim();
                continue;
            }
            const m = /^\s+(\S+)\s+(.*)$/.exec(line);
            if (!m)
                continue;
            if (section === "layout")
                ls.push({ "code": m[1], "name": m[2] });
            else if (section === "variant") {
                const v = /^(\S+):\s*(.*)$/.exec(m[2]);
                if (v)
                    (vs[v[1]] = vs[v[1]] || []).push({ "code": m[1], "name": v[2] });
            }
        }
        page.known = ls.sort((a, b) => a.name.localeCompare(b.name));
        page.knownVariants = vs;
    })
    function layoutName(code, variant) {
        const l = known.find(x => x.code === code);
        const v = variant ? (knownVariants[code] || []).find(x => x.code === variant) : null;
        return v ? v.name : l ? l.name : code;
    }

    Tabs {
        anchors.horizontalCenter: parent.horizontalCenter
        options: [{ "value": "typing", "label": "Typing", "icon": "keyboard-fill" }, { "value": "shortcuts", "label": "Shortcuts", "icon": "keyboard_command_key" }]
        value: page.tab
        onActivated: v => page.tab = v
    }

    // ---- typing ----
    SettingsGroup {
        visible: page.tab === "typing"
        width: parent.width
        title: "Keyboard layouts"
        description: "The keyboard layouts you type with. The first one is used when you log in."
        Repeater {
            model: page.layouts
            SettingsRow {
                required property string modelData
                required property int index
                title: page.layoutName(modelData, page.variants[index] || "")
                description: index === 0 ? "Used when you log in" : ""
                Row {
                    spacing: Theme.spacing
                    Select {
                        width: Math.round(200 * Math.max(1, Theme.textScale))
                        readonly property var vs: page.knownVariants[modelData] || []
                        visible: vs.length > 0
                        placeholder: "Variant"
                        options: [{ "value": "", "label": "Standard" }].concat(vs.map(v => ({ "value": v.code, "label": v.name })))
                        value: page.variants[index] || ""
                        onActivated: v => {
                            const vs2 = page.layouts.map((l, i) => i === index ? v : (page.variants[i] || ""));
                            page.setLayouts(page.layouts, vs2);
                        }
                    }
                    Button {
                        visible: index > 0
                        size: "sm"
                        variant: "ghost"
                        iconName: "arrow_upward"
                        onClicked: {
                            const ls = page.layouts.slice(), vs = page.layouts.map((l, i) => page.variants[i] || "");
                            [ls[index - 1], ls[index]] = [ls[index], ls[index - 1]];
                            [vs[index - 1], vs[index]] = [vs[index], vs[index - 1]];
                            page.setLayouts(ls, vs);
                        }
                    }
                    Button {
                        visible: page.layouts.length > 1
                        size: "sm"
                        variant: "ghost"
                        iconName: "delete-fill"
                        onClicked: page.setLayouts(page.layouts.filter((l, i) => i !== index), page.layouts.map((l, i) => page.variants[i] || "").filter((v, i) => i !== index))
                    }
                }
            }
        }
        SettingsRow {
            title: "Add a layout"
            Select {
                width: Math.round(260 * Math.max(1, Theme.textScale))
                placeholder: "Choose…"
                options: page.known.filter(l => page.layouts.indexOf(l.code) < 0).map(l => ({ "value": l.code, "label": l.name }))
                onActivated: v => page.setLayouts(page.layouts.concat([v]), page.layouts.map((l, i) => page.variants[i] || "").concat([""]))
            }
        }
        SettingsRow {
            visible: page.layouts.length > 1
            title: "Switch with"
            description: "The keys that switch from one layout to the next."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                options: [{ "value": "", "label": "No key" }, { "value": "grp:win_space_toggle", "label": "Super + Space" }, { "value": "grp:alt_shift_toggle", "label": "Alt + Shift" }, { "value": "grp:ctrl_shift_toggle", "label": "Ctrl + Shift" }, { "value": "grp:caps_toggle", "label": "Caps Lock" }]
                value: page.option("grp")
                onActivated: v => page.setOption("grp", v)
            }
        }
    }
    SettingsGroup {
        visible: page.tab === "typing"
        width: parent.width
        title: "Special keys"
        SettingsRow {
            title: "Compose key"
            description: "Press it, then two keys to type a character: ' then e makes é."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                options: [{ "value": "", "label": "Off" }, { "value": "compose:ralt", "label": "Right Alt" }, { "value": "compose:rwin", "label": "Right Super" }, { "value": "compose:menu", "label": "Menu" }, { "value": "compose:rctrl", "label": "Right Ctrl" }, { "value": "compose:caps", "label": "Caps Lock" }]
                value: page.option("compose")
                onActivated: v => page.setOption("compose", v)
            }
        }
        SettingsRow {
            title: "Caps Lock"
            description: "What the Caps Lock key does."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                readonly property string cur: page.options.find(o => /^(ctrl:nocaps|caps:)/.test(o)) || ""
                options: [{ "value": "", "label": "Caps Lock" }, { "value": "ctrl:nocaps", "label": "Another Ctrl" }, { "value": "caps:escape", "label": "Escape" }, { "value": "caps:backspace", "label": "Backspace" }, { "value": "caps:none", "label": "Nothing" }]
                value: cur
                onActivated: v => {
                    const next = page.options.filter(o => !/^(ctrl:nocaps|caps:)/.test(o));
                    if (v)
                        next.push(v);
                    page.writeXkb(page.layouts, page.variants, next);
                }
            }
        }
        SettingsRow {
            title: "Num Lock on at start"
            description: "The number pad types numbers as soon as you log in."
            Switch {
                checked: (page.rev, Niri.flag("input.keyboard.numlock", false))
                onToggled: Niri.setFlag("input.keyboard.numlock", checked)
            }
        }
    }
    SettingsGroup {
        visible: page.tab === "typing"
        width: parent.width
        title: "Key repeat"
        description: "Holding a key down types it again and again."
        SettingsRow {
            wide: true
            title: "Delay before repeating"
            description: "How long you hold a key before it starts repeating."
            Slider {
                width: parent.width
                from: 150
                to: 1000
                stepSize: 25
                value: (page.rev, Niri.arg("input.keyboard.repeat-delay", 600))
                format: v => Math.round(v) + " ms"
                marks: [{ "value": 150, "label": "Short" }, { "value": 1000, "label": "Long" }]
                onMoved: Niri.set("input.keyboard.repeat-delay", [Math.round(value)])
            }
        }
        SettingsRow {
            wide: true
            title: "Speed"
            description: "How fast a held key repeats."
            Slider {
                width: parent.width
                from: 10
                to: 60
                stepSize: 1
                value: (page.rev, Niri.arg("input.keyboard.repeat-rate", 25))
                format: v => Math.round(v) + " per second"
                marks: [{ "value": 10, "label": "Slow" }, { "value": 60, "label": "Fast" }]
                onMoved: Niri.set("input.keyboard.repeat-rate", [Math.round(value)])
            }
        }
        SettingsRow {
            title: "Try it"
            TextField {
                width: Math.round(260 * Math.max(1, Theme.textScale))
                placeholder: "Hold a key down here"
                clearable: true
            }
        }
    }

    // ---- shortcuts ----
    // built the first time the tab is opened (79 rows: it doubled the page's opening time), then kept
    Loader {
        active: page.shortcutsOpened
        visible: page.tab === "shortcuts"
        width: parent.width
        sourceComponent: ShortcutsTab {
            width: page.width
            window: page.window
        }
    }
}
