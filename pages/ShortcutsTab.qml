import QtQuick
import "../theme"
import "../services"
import "../components"

// Keyboard > Shortcuts: an editor. Every common action of the computer is listed, sorted by what it's
// about, with its shortcuts or "Set shortcut" when it has none yet, so adding one (power off, say) is
// filling a slot rather than writing a command. Shortcuts are recorded by pressing them
// (components/ShortcutField). Anything bound that isn't one of these actions is under Custom, where new
// commands are added too. A shortcut from config.kdl that's changed or removed is commented out there
// (Niri.removeBind); new ones go to the app's file with a hotkey-overlay-title, so niri's own shortcut
// list shows the same names.
Column {
    id: tab

    property var window: null
    property string filter: ""

    readonly property int rev: Niri.revision
    readonly property var binds: (rev, Niri.binds())

    spacing: Theme.spacing * 8

    // an action's signature, to recognise it whatever key it's on: "name arg arg"
    function sig(a) {
        return a ? [a.name].concat((a.args || []).map(String)).join(" ") : "";
    }
    function island(cmd) {
        return ["spawn", "qs", "ipc", "call", "island"].concat(cmd);
    }
    function osd(cmd) {
        return ["spawn", "qs", "ipc", "call", "osd"].concat(cmd);
    }
    // with the island, sound / brightness / music go through it (its pop-ups); without it, plain commands
    function viaIsland(withIsland, without) {
        return Island.installed ? withIsland : without;
    }
    readonly property var whenLocked: ({ "allow-when-locked": true })

    // The catalog. `action`: what's written ([name, args...]); `also`: other ways people bind the same
    // thing (a regex over the signature), so their shortcut shows up here too.
    readonly property var catalog: [
        { "title": "Dynamic Island", "island": true, "items": [
            { "id": "search", "label": "Search apps, files and the web", "action": island(["toggle", "search"]) },
            { "id": "quick", "label": "Open quick settings", "action": island(["toggle", "quickSettings"]) },
            { "id": "wifi", "label": "Open Wi-Fi", "action": island(["toggle", "wifi"]) },
            { "id": "bt", "label": "Open Bluetooth", "action": island(["toggle", "bluetooth"]) },
            { "id": "battery", "label": "Open battery", "action": island(["toggle", "battery"]) },
            { "id": "time", "label": "Open the clock and calendar", "action": island(["toggle", "time"]) },
            { "id": "media", "label": "Open what's playing", "action": island(["toggle", "media"]) },
            { "id": "focus", "label": "Turn Focus on or off", "action": island(["focus"]) }
        ] },
        { "title": "Windows", "items": [
            { "id": "close", "label": "Close the window", "action": ["close-window"] },
            { "id": "max", "label": "Make the window as wide as the screen", "action": ["maximize-column"] },
            { "id": "full", "label": "Full screen", "action": ["fullscreen-window"] },
            { "id": "float", "label": "Float the window above the others, or put it back", "action": ["toggle-window-floating"] },
            { "id": "center", "label": "Centre the window", "action": ["center-column"] },
            { "id": "wider", "label": "Make the window wider", "action": ["set-column-width", "+10%"] },
            { "id": "narrower", "label": "Make the window narrower", "action": ["set-column-width", "-10%"] },
            { "id": "preset", "label": "Switch between window widths", "action": ["switch-preset-column-width"] },
            { "id": "presetBack", "label": "Switch between window widths, backwards", "action": ["switch-preset-column-width-back"] },
            { "id": "tabs", "label": "Show windows in the same spot as tabs", "action": ["toggle-column-tabbed-display"] },
            { "id": "joinLeft", "label": "Put the window with the one on its left", "action": ["consume-or-expel-window-left"] },
            { "id": "joinRight", "label": "Put the window with the one on its right", "action": ["consume-or-expel-window-right"] },
            { "id": "moveLeft", "label": "Move the window left", "action": ["move-column-left"] },
            { "id": "moveRight", "label": "Move the window right", "action": ["move-column-right"] },
            { "id": "moveUp", "label": "Move the window up", "action": ["move-window-up"] },
            { "id": "moveDown", "label": "Move the window down", "action": ["move-window-down"] }
        ] },
        { "title": "Moving between windows", "items": [
            { "id": "left", "label": "Go to the window on the left", "action": ["focus-column-left"] },
            { "id": "right", "label": "Go to the window on the right", "action": ["focus-column-right"] },
            { "id": "up", "label": "Go to the window above", "action": ["focus-window-up"] },
            { "id": "down", "label": "Go to the window below", "action": ["focus-window-down"] },
            { "id": "first", "label": "Go to the first window", "action": ["focus-column-first"] },
            { "id": "last", "label": "Go to the last window", "action": ["focus-column-last"] },
            { "id": "overview", "label": "See all windows and workspaces", "action": ["toggle-overview"] }
        ] },
        { "title": "Workspaces", "items": [
            { "id": "wsUp", "label": "Go to the workspace above", "action": ["focus-workspace-up"] },
            { "id": "wsDown", "label": "Go to the workspace below", "action": ["focus-workspace-down"] },
            { "id": "wsMoveUp", "label": "Move the window to the workspace above", "action": ["move-column-to-workspace-up"] },
            { "id": "wsMoveDown", "label": "Move the window to the workspace below", "action": ["move-column-to-workspace-down"] },
            { "id": "wsSwapUp", "label": "Move the whole workspace up", "action": ["move-workspace-up"] },
            { "id": "wsSwapDown", "label": "Move the whole workspace down", "action": ["move-workspace-down"] }
        ].concat([1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => ({ "id": "ws" + n, "label": "Go to workspace " + n, "action": ["focus-workspace", n], "numbered": true })))
         .concat([1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => ({ "id": "wsTo" + n, "label": "Move the window to workspace " + n, "action": ["move-column-to-workspace", n], "numbered": true }))) },
        { "title": "Screens", "items": [
            { "id": "monLeft", "label": "Go to the screen on the left", "action": ["focus-monitor-left"] },
            { "id": "monRight", "label": "Go to the screen on the right", "action": ["focus-monitor-right"] },
            { "id": "monMoveLeft", "label": "Move the window to the screen on the left", "action": ["move-column-to-monitor-left"] },
            { "id": "monMoveRight", "label": "Move the window to the screen on the right", "action": ["move-column-to-monitor-right"] },
            { "id": "monOff", "label": "Turn the screens off", "action": ["power-off-monitors"] }
        ] },
        { "title": "Screenshots", "items": [
            { "id": "shot", "label": "Take a screenshot", "action": ["screenshot"] },
            { "id": "shotScreen", "label": "Take a screenshot of the whole screen", "action": ["screenshot-screen"] },
            { "id": "shotWindow", "label": "Take a screenshot of the window", "action": ["screenshot-window"] }
        ] },
        { "title": "Sound, brightness and music", "items": [
            { "id": "volUp", "label": "Volume up", "action": viaIsland(osd(["volume", "up"]), ["spawn-sh", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1"]), "props": whenLocked, "needs": viaIsland([], ["wireplumber"]), "also": /wpctl set-volume @DEFAULT_AUDIO_SINK@ [\d.]+%?\+/ },
            { "id": "volDown", "label": "Volume down", "action": viaIsland(osd(["volume", "down"]), ["spawn-sh", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"]), "props": whenLocked, "needs": viaIsland([], ["wireplumber"]), "also": /wpctl set-volume @DEFAULT_AUDIO_SINK@ [\d.]+%?-/ },
            { "id": "mute", "label": "Mute or unmute", "action": viaIsland(osd(["volume", "mute"]), ["spawn-sh", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]), "props": whenLocked, "needs": viaIsland([], ["wireplumber"]), "also": /wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle/ },
            { "id": "micMute", "label": "Mute or unmute the microphone", "action": viaIsland(osd(["mic", "mute"]), ["spawn-sh", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]), "props": whenLocked, "needs": viaIsland([], ["wireplumber"]), "also": /wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle/ },
            { "id": "brightUp", "label": "Brighter screen", "action": viaIsland(osd(["brightness", "up"]), ["spawn", "brightnessctl", "--class=backlight", "set", "+10%"]), "props": whenLocked, "needs": ["brightnessctl"], "also": /brightnessctl .*set \+/ },
            { "id": "brightDown", "label": "Dimmer screen", "action": viaIsland(osd(["brightness", "down"]), ["spawn", "brightnessctl", "--class=backlight", "set", "10%-"]), "props": whenLocked, "needs": ["brightnessctl"], "also": /brightnessctl .*set [\d.]+%?-/ },
            { "id": "play", "label": "Play or pause", "action": viaIsland(island(["media", "play-pause"]), ["spawn-sh", "playerctl play-pause"]), "props": whenLocked, "needs": viaIsland([], ["playerctl"]), "also": /playerctl play-pause/ },
            { "id": "next", "label": "Next track", "action": viaIsland(island(["media", "next"]), ["spawn-sh", "playerctl next"]), "props": whenLocked, "needs": viaIsland([], ["playerctl"]), "also": /playerctl next/ },
            { "id": "prev", "label": "Previous track", "action": viaIsland(island(["media", "previous"]), ["spawn-sh", "playerctl previous"]), "props": whenLocked, "needs": viaIsland([], ["playerctl"]), "also": /playerctl previous/ }
        ] },
        { "title": "System", "items": [
            { "id": "lock", "label": "Lock the screen", "action": ["spawn", "swaylock", "-f"], "needs": ["swaylock"], "also": /^spawn(-sh)? (swaylock|loginctl lock-session)/ },
            { "id": "logout", "label": "Log out", "action": ["quit"] },
            { "id": "sleep", "label": "Sleep", "action": ["spawn", "systemctl", "suspend"] },
            { "id": "restart", "label": "Restart", "action": ["spawn", "systemctl", "reboot"] },
            { "id": "poweroff", "label": "Power off", "action": ["spawn", "systemctl", "poweroff"] },
            { "id": "settings", "label": "Open Settings", "action": ["spawn", Env.appDir + "/bin/settings"], "also": /^spawn(-sh)? \S*settings( |$)/ },
            { "id": "help", "label": "Show the list of shortcuts", "action": ["show-hotkey-overlay"] }
        ] }
    ]
    readonly property var shownCatalog: catalog.filter(g => !g.island || Island.installed)
    readonly property var allItems: catalog.reduce((all, g) => all.concat(g.items), [])
    function itemFor(b) {
        if (!b.action)
            return null;
        const s = sig(b.action);
        for (const it of allItems)
            if (s === it.action.map(String).join(" ") || (it.also && it.also.test(s)))
                return it;
        return null;
    }
    // a key niri can't use any more: the app's old way of removing one (pointing it at nothing)
    function isHole(b) {
        return b.action && b.action.name === "spawn" && b.action.args.length === 1 && b.action.args[0] === "true";
    }
    // { itemId: [keys] } and the rest (custom)
    readonly property var sorted: {
        const by = {}, custom = [];
        for (const b of Object.values(binds)) {
            if (isHole(b))
                continue;
            const it = itemFor(b);
            if (it)
                (by[it.id] = by[it.id] || []).push(b.key);
            else
                custom.push(b);
        }
        return { "by": by, "custom": custom.sort((x, y) => customLabel(x).localeCompare(customLabel(y))) };
    }

    // the actions that have a key, as one string: a string only notifies when it really changes, so the
    // groups (which show a numbered workspace once it has a key) aren't rebuilt on every key change
    readonly property string boundIds: " " + Object.keys(sorted.by).sort().join(" ") + " "

    // what a custom shortcut does, in words
    function customLabel(b) {
        const t = b.props["hotkey-overlay-title"];
        if (t)
            return t;
        const a = b.action;
        if (!a)
            return "Nothing";
        if (a.name === "spawn" || a.name === "spawn-sh") {
            const cmd = a.name === "spawn-sh" ? String(a.args[0]).split(" ")[0] : String(a.args[0]);
            const bin = cmd.split("/").pop();
            const app = Host.apps.find(x => (x.exec || "").split(" ")[0].split("/").pop() === bin);
            return app ? "Open " + app.name : "Run " + a.args.join(" ");
        }
        const words = a.name.replace(/-/g, " ");
        return words.charAt(0).toUpperCase() + words.slice(1) + (a.args.length ? " " + a.args.join(" ") : "");
    }
    // what a key already does ("" = free), for ShortcutField's question
    function conflict(key) {
        const k = key.toLowerCase().replace(/^super\+/, "mod+");
        const b = Object.values(binds).find(x => x.key.toLowerCase().replace(/^super\+/, "mod+") === k && !isHole(x));
        if (!b)
            return "";
        const it = itemFor(b);
        return "does “" + (it ? it.label : customLabel(b)) + "”";
    }
    function node(list) {
        return Kdl.node(list[0], list.slice(1), {}, null);
    }
    // put `newKey` on an action (replacing `oldKey` when given)
    function assign(oldKey, newKey, action, props) {
        if (oldKey !== "")
            Niri.removeBind(oldKey);
        const other = Object.values(binds).find(x => x.key.toLowerCase() === newKey.toLowerCase());
        if (other && other.origin === "config")
            Niri.removeBind(other.key);
        Niri.setBind(newKey, action, props);
    }
    function assignItem(it, oldKey, newKey) {
        assign(oldKey, newKey, node(it.action), Object.assign({ "hotkey-overlay-title": it.label }, it.props || {}));
    }
    function assignCustom(b, oldKey, newKey) {
        assign(oldKey, newKey, Kdl.clone(b.action), b.props);
    }
    function matches(text) {
        return filter === "" || text.toLowerCase().indexOf(filter.toLowerCase()) >= 0;
    }

    SearchField {
        width: parent.width
        placeholder: "Search shortcuts"
        onEdited: tab.filter = text
    }

    Repeater {
        model: tab.shownCatalog
        SettingsGroup {
            id: grp
            required property var modelData
            property bool showNumbered: false
            readonly property var items: modelData.items.filter(it => tab.matches(it.label) && (!it.numbered || grp.showNumbered || tab.filter !== "" || tab.boundIds.indexOf(" " + it.id + " ") >= 0))
            readonly property int hiddenNumbered: modelData.items.filter(it => it.numbered).length - items.filter(it => it.numbered).length
            visible: items.length > 0
            width: tab.width
            title: modelData.title
            Repeater {
                model: grp.items
                SettingsRow {
                    id: item
                    required property var modelData
                    // what its keys would run isn't on this computer (`needs`, Deps): say so, offer it
                    readonly property bool lacking: Deps.lacks(modelData.needs).length > 0
                    title: modelData.label
                    description: !lacking ? "" : Deps.isInstalling(modelData.needs) ? "Finish installing in the window that opened." : "Its keys won't do anything yet: it needs a small extra program that isn't on this computer."
                    Row {
                        spacing: Theme.spacing * 2
                        Button {
                            visible: item.lacking && Deps.canInstall(item.modelData.needs) && !Deps.isInstalling(item.modelData.needs)
                            anchors.verticalCenter: parent.verticalCenter
                            size: "sm"
                            variant: "tertiary"
                            text: "Install…"
                            onClicked: Deps.install(item.modelData.needs)
                        }
                        ShortcutField {
                            window: tab.window
                            keys: tab.sorted.by[item.modelData.id] || []
                            conflict: tab.conflict
                            onAssign: (oldKey, newKey) => tab.assignItem(item.modelData, oldKey, newKey)
                            onRemove: key => Niri.removeBind(key)
                        }
                    }
                }
            }
            SettingsRow {
                visible: grp.hiddenNumbered > 0
                title: "Numbered workspaces"
                description: "Go straight to a workspace, or send a window there, by its number."
                Button {
                    size: "sm"
                    variant: "secondary"
                    text: "Show all"
                    onClicked: grp.showNumbered = true
                }
            }
        }
    }

    // ---- custom ----
    SettingsGroup {
        width: parent.width
        title: "Custom"
        description: "Your own shortcuts, to open an app or run a command."
        Repeater {
            model: tab.sorted.custom.filter(b => tab.matches(tab.customLabel(b)))
            SettingsRow {
                required property var modelData
                title: tab.customLabel(modelData)
                description: modelData.action && (modelData.action.name === "spawn" || modelData.action.name === "spawn-sh") ? modelData.action.args.join(" ") : ""
                ShortcutField {
                    window: tab.window
                    keys: [modelData.key]
                    conflict: tab.conflict
                    onAssign: (oldKey, newKey) => tab.assignCustom(modelData, oldKey === "" ? "" : oldKey, newKey)
                    onRemove: key => Niri.removeBind(key)
                }
            }
        }
        SettingsRow {
            wide: true
            title: "Add a shortcut"
            description: "Give it a name, choose an app or write a command, then press the keys you want."
            Column {
                width: parent.width
                spacing: Theme.spacing * 3
                Row {
                    spacing: Theme.spacing * 2
                    TextField {
                        id: newName
                        width: Math.round(200 * Math.max(1, Theme.textScale))
                        placeholder: "Name, e.g. Open the browser"
                    }
                    Select {
                        id: newApp
                        width: Math.round(220 * Math.max(1, Theme.textScale))
                        placeholder: "Choose an app…"
                        options: Host.apps.map(a => ({ "value": a.id, "label": a.name }))
                        onActivated: v => {
                            const a = Host.apps.find(x => x.id === v);
                            if (!a)
                                return;
                            newCmd.text = (a.exec || "").replace(/\s*%[fFuUick]/g, "").trim();
                            if (newName.text === "")
                                newName.text = "Open " + a.name;
                        }
                    }
                }
                Row {
                    spacing: Theme.spacing * 2
                    TextField {
                        id: newCmd
                        width: Math.round(422 * Math.max(1, Theme.textScale))
                        placeholder: "Or a command, e.g. firefox --private-window"
                    }
                    ShortcutField {
                        id: newKey
                        anchors.verticalCenter: parent.verticalCenter
                        window: tab.window
                        keys: []
                        conflict: tab.conflict
                        enabled: newCmd.text.trim() !== ""
                        opacity: enabled ? 1 : Theme.disabledOpacity
                        onAssign: (oldKey, key) => {
                            tab.assign("", key, Kdl.node("spawn-sh", [newCmd.text.trim()], {}, null), { "hotkey-overlay-title": newName.text.trim() || newCmd.text.trim() });
                            newName.text = "";
                            newCmd.text = "";
                        }
                    }
                }
            }
        }
    }
}
