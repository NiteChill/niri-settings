import QtQuick
import "../theme"
import "../services"
import "../components"

// Displays: your screens drawn to scale (drag one to arrange them; it snaps to its neighbours' edges),
// then the chosen screen's resolution, refresh rate, scale, rotation, variable refresh rate. Changes apply
// at once through niri's config; a bar then asks to keep them and puts everything back after 15 seconds
// without an answer (a screen you can't read can't be fixed by hand). Brightness for built-in screens,
// night light through wlsunset.
Column {
    id: page
    spacing: Theme.spacing * 8

    property string selected: Niri.outputs.length ? Niri.outputs[0].name : ""
    readonly property var live: Niri.outputs.find(o => o.name === selected) || null
    // the chosen screen as it will be: niri's state with the changes just made on top. niri applies a
    // change a moment after the file is written; until it reports back, the controls show what you
    // picked rather than snapping back to the old value. A pending value goes when niri shows it, or
    // after a few seconds whatever happened.
    property var pending: ({})    // { output name: { size, refresh, scale, transform, enabled } }
    readonly property var out: {
        if (!live)
            return null;
        const p = pending[selected] || {};
        const o = Object.assign({}, live);
        if ("scale" in p) o.scale = p.scale;
        if ("transform" in p) o.transform = p.transform;
        if ("enabled" in p) o.enabled = p.enabled;
        if ("size" in p || "refresh" in p) {
            const cur = live.mode >= 0 ? live.modes[live.mode] : null;
            const size = p.size || (cur ? cur.width + "x" + cur.height : "");
            const want = live.modes.map((m, i) => ({ "m": m, "i": i })).filter(x => x.m.width + "x" + x.m.height === size);
            const hit = want.find(x => p.refresh !== undefined && x.m.refresh.toFixed(3) === p.refresh) || want.sort((a, b) => b.m.refresh - a.m.refresh)[0];
            if (hit)
                o.mode = hit.i;
        }
        return o;
    }
    function expect(fields) {
        const next = Object.assign({}, pending);
        next[selected] = Object.assign({}, next[selected] || {}, fields);
        pending = next;
        pendingTimer.restart();
    }
    // drop what niri now shows
    function settle() {
        const next = {};
        for (const name in pending) {
            const o = Niri.outputs.find(x => x.name === name);
            const p = Object.assign({}, pending[name]);
            if (o) {
                const cur = o.mode >= 0 ? o.modes[o.mode] : null;
                if (cur && p.size === cur.width + "x" + cur.height && (p.refresh === undefined || p.refresh === cur.refresh.toFixed(3))) {
                    delete p.size;
                    delete p.refresh;
                }
                if (p.scale !== undefined && Math.abs(p.scale - o.scale) < 0.001) delete p.scale;
                if (p.transform !== undefined && p.transform === o.transform) delete p.transform;
                if (p.enabled !== undefined && p.enabled === o.enabled) delete p.enabled;
            }
            if (Object.keys(p).length)
                next[name] = p;
        }
        pending = next;
    }
    Connections {
        target: Niri
        function onOutputsChanged() {
            page.settle();
        }
        function onLastErrorChanged() {
            if (Niri.lastError !== "")
                page.pending = {};
        }
    }
    Timer {
        id: pendingTimer
        interval: 4000
        onTriggered: page.pending = {}
    }
    readonly property var cfg: (Niri.revision, Niri.outputNode(selected))
    function cfgHas(name) {
        return !!(cfg && cfg.children && cfg.children.find(c => c.name === name && c.args[0] !== false));
    }

    // ---- keep or revert ----
    property var _before: null       // the app's output blocks before this round of changes
    property int countdown: 0
    function change(fields) {
        if (_before === null)
            _before = Kdl.clone(Niri.ownNodes(n => n.name === "output"));
        Niri.setOutput(selected, fields);
        countdown = 15;
        tick.restart();
    }
    function keep() {
        _before = null;
        countdown = 0;
        tick.stop();
    }
    function revert() {
        pending = {};
        if (_before !== null)
            Niri.replaceNodes(n => n.name === "output", _before);
        keep();
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown--;
            if (page.countdown <= 0)
                page.revert();
        }
    }
    Component.onCompleted: {
        Niri.watchOutputs = true;
        Niri.readOutputs();
        readBrightness();
    }
    function readBrightness() {
        Env.readFor(page, ["brightnessctl", "-m", "-c", "backlight"], (code, out) => {
            const f = out.trim().split(",");
            if (code === 0 && f.length >= 4) {
                page.backlight = f[0];
                page.brightness = parseInt(f[3]);
            }
        });
    }
    // installed while the page is open (Missing's Install): read the brightness now
    readonly property bool hasBrightnessTool: Deps.has("brightnessctl")
    onHasBrightnessToolChanged: if (hasBrightnessTool)
        readBrightness()
    Component.onDestruction: {
        Niri.watchOutputs = false;
        if (countdown > 0)
            revert();
    }

    Banner {
        visible: page.countdown > 0
        tone: "warning"
        iconName: "timer-fill"
        title: "Keep these display settings?"
        description: "Going back in " + page.countdown + " s."
        actionText: "Keep"
        onAction: page.keep()
        Button {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing * 3 + 76
            anchors.verticalCenter: parent.verticalCenter
            size: "sm"
            variant: "ghost"
            text: "Revert"
            onClicked: page.revert()
        }
    }
    Banner {
        visible: Niri.lastError !== ""
        tone: "danger"
        title: "These display settings couldn't be used"
        description: "Your screens keep their previous settings. Try another resolution or refresh rate."
    }

    // ---- arrangement ----
    Rectangle {
        id: stage
        width: parent.width
        height: Theme.spacing * 64
        radius: Theme.card.radius
        color: Theme.c.surface
        border.width: Theme.cardBorder
        border.color: Theme.c.border

        readonly property var box: {
            const os = Niri.outputs.filter(o => o.enabled);
            if (!os.length)
                return { "x": 0, "y": 0, "w": 1, "h": 1 };
            const x0 = Math.min(...os.map(o => o.x)), y0 = Math.min(...os.map(o => o.y));
            const x1 = Math.max(...os.map(o => o.x + o.width)), y1 = Math.max(...os.map(o => o.y + o.height));
            return { "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0 };
        }
        readonly property real k: Math.min((width - 96) / box.w, (height - 64) / box.h)
        readonly property real ox: (width - box.w * k) / 2
        readonly property real oy: (height - box.h * k) / 2

        Repeater {
            model: Niri.outputs.filter(o => o.enabled)
            Rectangle {
                id: screen
                required property var modelData
                readonly property bool chosen: modelData.name === page.selected
                x: stage.ox + (modelData.x - stage.box.x) * stage.k
                y: stage.oy + (modelData.y - stage.box.y) * stage.k
                width: modelData.width * stage.k
                height: modelData.height * stage.k
                radius: Theme.radius.xl
                color: chosen ? Theme.c.accentSoft : Theme.c.surfaceTertiary
                border.width: 2
                border.color: chosen ? Theme.c.accent : Theme.c.border
                Behavior on x {
                    enabled: !drag.active
                    Spring {}
                }
                Behavior on y {
                    enabled: !drag.active
                    Spring {}
                }
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacing
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (screen.modelData.make + " " + screen.modelData.model).trim() || screen.modelData.name
                        weight: Theme.weightSemibold
                        width: Math.min(implicitWidth, screen.width - 16)
                        elide: Text.ElideRight
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.modelData.name + " · " + Math.round(screen.modelData.scale * 100) + " %"
                        size: "xs"
                        color: Theme.c.muted
                    }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    cursorShape: Niri.outputs.length > 1 ? Qt.OpenHandCursor : Qt.ArrowCursor
                    drag.target: Niri.outputs.length > 1 ? screen : null
                    onPressed: page.selected = screen.modelData.name
                    onReleased: {
                        if (Niri.outputs.length < 2)
                            return;
                        // back to layout units, then snap to the other screens' edges
                        let lx = Math.round((screen.x - stage.ox) / stage.k + stage.box.x);
                        let ly = Math.round((screen.y - stage.oy) / stage.k + stage.box.y);
                        const w = screen.modelData.width, h = screen.modelData.height;
                        const reach = 48 / stage.k;
                        for (const o of Niri.outputs.filter(o => o.enabled && o.name !== screen.modelData.name)) {
                            for (const [a, b] of [[lx, o.x + o.width], [lx + w, o.x], [lx, o.x], [lx + w, o.x + o.width]])
                                if (Math.abs(a - b) < reach)
                                    lx += b - a;
                            for (const [a, b] of [[ly, o.y + o.height], [ly + h, o.y], [ly, o.y], [ly + h, o.y + o.height]])
                                if (Math.abs(a - b) < reach)
                                    ly += b - a;
                        }
                        page.change({ "position": Kdl.node("position", [], { "x": lx, "y": ly }) });
                    }
                }
            }
        }
        Label {
            visible: Niri.outputs.length > 1
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacing * 3
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drag a screen to place it"
            size: "xs"
            color: Theme.c.muted
        }
    }

    // ---- the chosen screen ----
    SettingsGroup {
        visible: page.out !== null
        width: parent.width
        title: page.out ? ((page.out.make + " " + page.out.model).trim() || page.out.name) : ""
        SettingsRow {
            visible: Niri.outputs.length > 1
            title: "Use this screen"
            description: "Turn it off to use only your other screens."
            Switch {
                checked: page.out ? page.out.enabled : false
                onToggled: {
                    page.expect({ "enabled": checked });
                    page.change({ "off": checked ? null : Kdl.node("off") });
                }
            }
        }
        SettingsRow {
            title: "Resolution"
            description: "How many pixels the screen shows. The highest is usually the sharpest."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                readonly property var sizes: {
                    if (!page.out)
                        return [];
                    const seen = {};
                    return page.out.modes.filter(m => {
                        const k = m.width + "x" + m.height;
                        if (seen[k])
                            return false;
                        seen[k] = true;
                        return true;
                    }).map(m => ({ "value": m.width + "x" + m.height, "label": m.width + " × " + m.height + (m.preferred ? "  (best)" : "") }));
                }
                options: sizes
                value: page.out && page.out.mode >= 0 ? page.out.modes[page.out.mode].width + "x" + page.out.modes[page.out.mode].height : ""
                onActivated: v => {
                    const best = page.out.modes.filter(m => m.width + "x" + m.height === v).sort((a, b) => b.refresh - a.refresh)[0];
                    page.expect({ "size": v, "refresh": best.refresh.toFixed(3) });
                    page.change({ "mode": Kdl.node("mode", [best.width + "x" + best.height + "@" + best.refresh.toFixed(3)]) });
                }
            }
        }
        SettingsRow {
            title: "Refresh rate"
            description: "How many times per second the picture is redrawn. Higher feels smoother but uses a little more power."
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                readonly property var cur: page.out && page.out.mode >= 0 ? page.out.modes[page.out.mode] : null
                options: !cur ? [] : page.out.modes.filter(m => m.width === cur.width && m.height === cur.height).map(m => ({ "value": m.refresh.toFixed(3), "label": m.refresh.toFixed(2) + " Hz" }))
                value: cur ? cur.refresh.toFixed(3) : ""
                onActivated: v => {
                    page.expect({ "size": cur.width + "x" + cur.height, "refresh": v });
                    page.change({ "mode": Kdl.node("mode", [cur.width + "x" + cur.height + "@" + v]) });
                }
            }
        }
        SettingsRow {
            title: "Scale"
            description: "Makes everything bigger or smaller on this screen. Text stays sharp at every size."
            Row {
                spacing: Theme.spacing * 2
                Tabs {
                    readonly property var steps: [1, 1.25, 1.5, 1.75, 2]
                    options: steps.map(s => ({ "value": s, "label": Math.round(s * 100) + " %" }))
                    value: page.out ? page.out.scale : 1
                    onActivated: v => {
                        page.expect({ "scale": v });
                        page.change({ "scale": Kdl.node("scale", [v]) });
                    }
                }
            }
        }
        SettingsRow {
            title: "Rotation"
            Tabs {
                options: [{ "value": "Normal", "label": "None" }, { "value": "_90", "label": "90°" }, { "value": "_180", "label": "180°" }, { "value": "_270", "label": "270°" }]
                value: page.out ? page.out.transform.replace(/^(\d)/, "_$1") : "Normal"
                onActivated: v => {
                    page.expect({ "transform": v === "Normal" ? "Normal" : v.slice(1) });
                    page.change({ "transform": Kdl.node("transform", [v === "Normal" ? "normal" : v.slice(1)]) });
                }
            }
        }
        SettingsRow {
            visible: page.out ? page.out.vrrSupported : false
            title: "Variable refresh rate"
            description: "The screen adjusts how often it redraws to match games and videos, for smoother motion without tearing. “When asked” turns it on only for apps that ask for it."
            Select {
                width: Math.round(160 * Math.max(1, Theme.textScale))
                options: [{ "value": "off", "label": "Off" }, { "value": "on", "label": "Always" }, { "value": "demand", "label": "When asked" }]
                value: !page.cfgHas("variable-refresh-rate") ? "off" : (page.cfg.children.find(c => c.name === "variable-refresh-rate").props["on-demand"] ? "demand" : "on")
                onActivated: v => page.change({ "variable-refresh-rate": v === "off" ? null : Kdl.node("variable-refresh-rate", [], v === "demand" ? { "on-demand": true } : {}) })
            }
        }
        SettingsRow {
            visible: Niri.outputs.length > 1
            title: "Main screen"
            description: "The screen you start on after logging in, where new windows open first."
            Switch {
                checked: page.cfgHas("focus-at-startup")
                onToggled: {
                    for (const o of Niri.outputs)
                        if (o.name !== page.selected)
                            Niri.setOutput(o.name, { "focus-at-startup": null });
                    page.change({ "focus-at-startup": checked ? Kdl.node("focus-at-startup") : null });
                }
            }
        }
    }

    // ---- brightness (built-in screens) ----
    property string backlight: ""
    property int brightness: 0
    SettingsGroup {
        // a built-in screen, or one the brightness tool would find (the check only counts it missing then)
        visible: page.backlight !== "" || !page.hasBrightnessTool
        width: parent.width
        title: "Brightness"
        Missing {
            needs: ["brightnessctl"]
            what: "Changing the brightness"
        }
        SettingsRow {
            visible: page.backlight !== "" && page.hasBrightnessTool
            wide: true
            title: "Built-in screen"
            Slider {
                width: parent.width
                from: 1
                to: 100
                stepSize: 1
                value: page.brightness
                suffix: " %"
                showOutput: true
                onMoved: {
                    page.brightness = value;
                    Env.write(["brightnessctl", "-q", "-d", page.backlight, "set", Math.round(value) + "%"]);
                }
            }
        }
    }

    // ---- night light (wlsunset) ----
    readonly property bool hasWlsunset: Deps.has("wlsunset")
    readonly property var nightNode: (Niri.revision, Niri.ownNodes(n => n.name === "spawn-at-startup" && n.args[0] === "wlsunset")[0] || null)
    readonly property bool nightOn: nightNode !== null
    function nightArg(flag, def) {
        if (!nightNode)
            return def;
        const i = nightNode.args.indexOf(flag);
        return i >= 0 ? nightNode.args[i + 1] : def;
    }
    function setNight(on, temp, from, to) {
        const args = ["wlsunset", "-t", String(temp), "-T", "6500", "-s", from, "-S", to];
        Niri.replaceNodes(n => n.name === "spawn-at-startup" && n.args[0] === "wlsunset", on ? [Kdl.node("spawn-at-startup", args)] : []);
        Env.write(["pkill", "-x", "wlsunset"], () => {
            if (on)
                Env.launch(args);
        });
    }
    SettingsGroup {
        width: parent.width
        title: "Night light"
        Missing {
            needs: ["wlsunset"]
            what: "Night light"
        }
        SettingsRow {
            visible: page.hasWlsunset
            title: "Night light"
            description: "Makes the screen warmer and less blue in the evening. It's easier on the eyes and may help you sleep."
            iconName: "bedtime-fill"
            Switch {
                checked: page.nightOn
                onToggled: page.setNight(checked, page.nightArg("-t", "4000"), page.nightArg("-s", "20:00"), page.nightArg("-S", "07:00"))
            }
        }
        SettingsRow {
            visible: page.hasWlsunset && page.nightOn
            title: "From"
            description: "The screen turns warmer at the first time, and back to normal at the second."
            Row {
                spacing: Theme.spacing * 2
                TextField {
                    width: Math.round(88 * Math.max(1, Theme.textScale))
                    text: page.nightArg("-s", "20:00")
                    onAccepted: page.setNight(true, page.nightArg("-t", "4000"), text, page.nightArg("-S", "07:00"))
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "to"
                    color: Theme.c.muted
                }
                TextField {
                    width: Math.round(88 * Math.max(1, Theme.textScale))
                    text: page.nightArg("-S", "07:00")
                    onAccepted: page.setNight(true, page.nightArg("-t", "4000"), page.nightArg("-s", "20:00"), text)
                }
            }
        }
        SettingsRow {
            visible: page.hasWlsunset && page.nightOn
            wide: true
            title: "Warmth"
            description: "How warm the screen gets at night."
            Slider {
                width: parent.width
                from: 6000
                to: 2500
                stepSize: 100
                format: v => Math.round((6000 - v) / 35) + " %"
                value: Number(page.nightArg("-t", "4000"))
                marks: [{ "value": 6000, "label": "Less" }, { "value": 2500, "label": "More" }]
                onMoved: page.setNight(true, Math.round(value), page.nightArg("-s", "20:00"), page.nightArg("-S", "07:00"))
            }
        }
    }
}
