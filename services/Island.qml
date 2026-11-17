pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The Dynamic Island's settings: its config/schema.json (every setting, with its default) and the
// user's config/config.jsonc (only the active lines are values; the rest is commented-out defaults).
// value("island.shape") = the user's value, else the default. set(key, value) makes that line active
// with the new value, then lets the island's own tool (tools/check-config.py --rewrite) rewrite the file
// in its usual shape, so it stays as tidy as when edited by hand. The island reloads by itself.
Singleton {
    id: island

    property var defaults: ({})
    property var active: ({})
    property var schema: null
    property bool available: false
    // the island is on this computer (its settings were found): its settings show only then.
    // Installed, not running: a restart must not make them flicker away.
    readonly property bool installed: available && !Env.noIsland
    property int revision: 0

    function _lookup(obj, key) {
        let o = obj;
        for (const part of key.split(".")) {
            if (o === null || typeof o !== "object" || !(part in o))
                return undefined;
            o = o[part];
        }
        return o;
    }
    function value(key, def) {
        const a = _lookup(active, key);
        if (a !== undefined)
            return a;
        const d = _lookup(defaults, key);
        return d === undefined ? def : d;
    }
    // the schema entry of a setting: { key, label, description, type, default, min, max, ... }
    function entry(key) {
        if (!schema)
            return null;
        for (const section of schema.sections || [])
            for (const group of section.groups || [])
                for (const s of group.settings || [])
                    if (s.key === key)
                        return s;
        return null;
    }
    property bool loaded: false
    property var _queued: []
    function set(key, v) {
        // before the file is read, a change would be overwritten by it: hold it until then
        if (!loaded) {
            _queued.push([key, v]);
            return;
        }
        const next = JSON.parse(JSON.stringify(active));
        let o = next;
        const parts = key.split(".");
        for (let i = 0; i < parts.length - 1; i++)
            o = o[parts[i]] = (o[parts[i]] && typeof o[parts[i]] === "object") ? o[parts[i]] : {};
        o[parts[parts.length - 1]] = v;
        active = next;
        revision++;
        writeTimer.restart();
    }
    Timer {
        id: writeTimer
        interval: 250
        onTriggered: {
            island._writing = true;
            userFile.setText(JSON.stringify(Object.assign({ "$schema": "./config.schema.json" }, island.active), null, 4) + "\n");
        }
    }
    property bool _writing: false

    function _jsonc(text) {
        let out = "";
        let comma = false;
        let i = 0;
        const n = text.length;
        while (i < n) {
            const c = text[i];
            if (c === "/" && text[i + 1] === "/") {
                while (i < n && text[i] !== "\n")
                    i++;
            } else if (c === "/" && text[i + 1] === "*") {
                const end = text.indexOf("*/", i + 2);
                i = end < 0 ? n : end + 2;
            } else if (c === " " || c === "\t" || c === "\n" || c === "\r") {
                out += c;
                i++;
            } else if (c === ",") {
                if (comma)
                    out += ",";
                comma = true;
                i++;
            } else {
                if (comma && c !== "}" && c !== "]")
                    out += ",";
                comma = false;
                if (c === '"') {
                    let j = i + 1;
                    while (j < n && text[j] !== '"')
                        j += text[j] === "\\" ? 2 : 1;
                    out += text.slice(i, j + 1);
                    i = j + 1;
                } else {
                    out += c;
                    i++;
                }
            }
        }
        return out;
    }
    function _defaults(s) {
        const out = {};
        for (const section of s.sections || [])
            for (const group of section.groups || [])
                for (const e of group.settings || []) {
                    const parts = e.key.split(".");
                    let o = out;
                    for (let i = 0; i < parts.length - 1; i++)
                        o = o[parts[i]] = o[parts[i]] || {};
                    o[parts[parts.length - 1]] = e.default;
                }
        return out;
    }

    FileView {
        id: schemaFile
        path: Env.islandDir + "/config/schema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                island.schema = JSON.parse(text());
                island.defaults = island._defaults(island.schema);
                island.available = true;
                island.revision++;
            } catch (e) {
                console.warn("Island: bad schema.json: " + e.message);
            }
        }
    }
    FileView {
        id: userFile
        path: Env.islandDir + "/config/config.jsonc"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const a = JSON.parse(island._jsonc(text()));
                delete a["$schema"];
                if (JSON.stringify(a) !== JSON.stringify(island.active)) {
                    island.active = a;
                    island.revision++;
                }
            } catch (e) {
                // half-written by someone else: keep the previous values
            }
            if (!island.loaded) {
                island.loaded = true;
                for (const q of island._queued)
                    island.set(q[0], q[1]);
                island._queued = [];
            }
        }
        onSaved: {
            if (!island._writing)
                return;
            island._writing = false;
            // back to the usual layout: every setting listed, commented out at its default
            Env.read(["python3", Env.islandDir + "/tools/check-config.py", "--rewrite"], (code, out, err) => {
                if (code !== 0)
                    console.warn("Island: check-config: " + (out + err).trim().split("\n").slice(-3).join(" "));
            });
        }
    }
}
