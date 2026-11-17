pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// niri's config, as the app sees it.
//   config.kdl    the user's file. Read only, except for one line: on start the app makes sure it ends
//                 with `include optional=true "settings.kdl"` (appended if missing, every time).
//   settings.kdl  the app's file, written whole from `own`. Included last, so its values win; it only
//                 holds what the user changed in the app.
// Reading a setting: the app's value, else config.kdl's, else niri's default (the caller's `def`).
// Sections niri doesn't merge (a pointing device's block, struts, column width presets, an animation)
// are copied whole from config.kdl into the app's file the first time one of their values changes, so
// nothing the user set there is lost. Every write is checked with `niri validate` first; a file niri
// would reject is never written (lastError says why). Outputs (screens) also come live from niri.
Singleton {
    id: niri

    property var main: []
    property var own: []
    // bumps whenever main or own changes: bind to it to re-read (`Niri.revision, Niri.arg(...)`)
    property int revision: 0
    property string lastError: ""
    property bool ready: false
    // [{ name, make, model, serial, modes: [{ width, height, refresh (Hz), preferred }], mode (index),
    //    x, y, width, height (logical), scale, transform, vrrSupported, vrrEnabled, enabled }]
    property var outputs: []

    readonly property string ownPath: Env.niriDir + "/settings.kdl"
    readonly property var nonMerging: ["input.touchpad", "input.mouse", "input.trackpoint", "input.trackball", "input.tablet", "input.touch", "layout.struts", "layout.preset-column-widths", "layout.preset-window-heights", "animations.workspace-switch", "animations.window-open", "animations.window-close", "animations.horizontal-view-movement", "animations.window-movement", "animations.window-resize", "animations.config-notification-open-close", "animations.screenshot-ui-open", "animations.overview-open-close"]
    readonly property string header: "// Written by Settings. Changes made in the app land here; config.kdl includes this file at its end,\n// so these values win over the same ones set there. Safe to delete (the include is optional).\n\n"

    // ---- reading ----
    function _find(list, path) {
        let level = list;
        let found = null;
        for (let k = 0; k < path.length; k++) {
            found = null;
            for (const node of level || [])
                if (node.name === path[k])
                    found = node; // the last one wins, like niri
            if (!found)
                return null;
            level = found.children;
        }
        return found;
    }
    function _blockOf(path) {
        const key = path.join(".");
        for (const p of nonMerging)
            if (key === p || key.startsWith(p + "."))
                return p.split(".");
        return null;
    }
    // the node niri would use for this path (null = not set anywhere)
    function node(path) {
        if (typeof path === "string")
            path = path.split(".");
        const block = _blockOf(path);
        if (block && _find(own, block))
            return _find(own, path);
        return _find(own, path) || _find(main, path);
    }
    // first argument of a setting, or def
    function arg(path, def) {
        const n = node(path);
        return n && n.args.length ? n.args[0] : def;
    }
    // a flag (`natural-scroll`, `natural-scroll false`), or def when it's absent
    function flag(path, def) {
        const n = node(path);
        if (!n)
            return def;
        return n.args.length ? n.args[0] !== false : true;
    }
    // a section that is on / off by `on` / `off` children (border, focus-ring, shadow...)
    // (the section is merged across files: config.kdl's `off` stands unless the app's file says `on`)
    function onOff(path, def) {
        if (typeof path === "string")
            path = path.split(".");
        let state = def;
        const mainNode = _find(main, path);
        // niri's special case: in the main file, a `border { }` without on / off turns the border on
        if (mainNode && path.join(".") === "layout.border")
            state = true;
        for (const n of [mainNode, _find(own, path)]) {
            if (!n || !n.children)
                continue;
            for (const c of n.children) {
                if (c.name === "on" && c.args[0] !== false)
                    state = true;
                if (c.name === "off" && c.args[0] !== false)
                    state = false;
            }
        }
        return state;
    }
    // where a value comes from: "app", "config" or "default"
    function origin(path) {
        if (typeof path === "string")
            path = path.split(".");
        return _find(own, path) ? "app" : _find(main, path) ? "config" : "default";
    }

    // ---- writing ----
    function _ensure(list, path) {
        let level = list;
        let found = null;
        for (const name of path) {
            found = null;
            for (const n of level)
                if (n.name === name)
                    found = n;
            if (!found) {
                found = Kdl.node(name, [], {}, []);
                level.push(found);
            }
            if (!found.children)
                found.children = [];
            level = found.children;
        }
        return found;
    }
    // copy a non-merging block from config.kdl into own before changing a value inside it
    function _prepare(path) {
        const block = _blockOf(path);
        if (block && !_find(own, block)) {
            const theirs = _find(main, block);
            const parent = _ensure(own, block.slice(0, -1));
            const copy = theirs ? Kdl.clone(theirs) : Kdl.node(block[block.length - 1], [], {}, []);
            if (!copy.children)
                copy.children = [];
            (block.length > 1 ? parent.children : own).push(copy);
        }
    }
    // set a setting's arguments / properties: set("layout.gaps", [12])
    function set(path, args, props) {
        if (typeof path === "string")
            path = path.split(".");
        const next = Kdl.clone(own);
        const saved = own;
        own = next;
        _prepare(path);
        const parent = path.length > 1 ? _ensure(own, path.slice(0, -1)).children : own;
        const name = path[path.length - 1];
        const keep = parent.filter(n => n.name !== name);
        const existing = parent.find(n => n.name === name);
        const n = Kdl.node(name, args || [], props || {}, existing ? existing.children : null);
        parent.length = 0;
        for (const k of keep)
            parent.push(k);
        parent.push(n);
        _changed(saved);
    }
    // a section with children given whole: setBlock("layout.default-column-width", [Kdl.node("proportion", [0.5])])
    function setBlock(path, children) {
        if (typeof path === "string")
            path = path.split(".");
        const saved = own;
        own = Kdl.clone(own);
        _prepare(path);
        const parent = path.length > 1 ? _ensure(own, path.slice(0, -1)).children : own;
        const name = path[path.length - 1];
        const kept = parent.filter(n => n.name !== name);
        parent.length = 0;
        for (const k of kept)
            parent.push(k);
        parent.push(Kdl.node(name, [], {}, children));
        _changed(saved);
    }
    // the proportions inside a block ("layout.preset-column-widths" -> [0.33333, 0.5, 0.66667])
    function proportions(path, def) {
        const n = node(path);
        if (!n || !n.children)
            return def;
        const p = n.children.filter(c => c.name === "proportion").map(c => c.args[0]);
        return p.length ? p : def;
    }
    // a flag on / off. Inside a block niri doesn't merge, off = absent; elsewhere it's written `false`
    // (so it beats config.kdl's)
    function setFlag(path, on) {
        if (typeof path === "string")
            path = path.split(".");
        if (on && noFalse.indexOf(path.join(".")) >= 0 && _uncommentMain(path))
            return;
        if (on)
            set(path, []);
        else if (_blockOf(path))
            remove(path);
        else if (noFalse.indexOf(path.join(".")) >= 0) {
            remove(path);
            _commentOutMain(path);
        } else
            set(path, [false]);
    }
    // flags niri can't turn off with `false` (checked with niri validate, 26.04): an included file can't
    // undo them, so turning one off also comments out its line in config.kdl
    readonly property var noFalse: ["input.focus-follows-mouse", "input.warp-mouse-to-focus"]
    // turning it back on restores the user's own line (with its options) when we commented it out
    function _uncommentMain(path) {
        const name = path[path.length - 1];
        let done = 0;
        const lines = mainFile.text().split("\n").map(l => {
            const m = l.match(/^(\s*)\/\/ (.*) \/\/ turned off in Settings$/);
            if (m && (m[2] === name || m[2].startsWith(name + " ") || m[2].startsWith(name + ";"))) {
                done++;
                return m[1] + m[2];
            }
            return l;
        });
        if (!done)
            return false;
        mainWriter.path = Env.niriConfig;
        mainWriter.setText(lines.join("\n"));
        // the line is back in config.kdl: config.kdl wins unless the app's file also says it
        remove(path);
        return true;
    }
    function _commentOutMain(path) {
        if (!_find(main, path))
            return;
        const name = path[path.length - 1];
        const re = new RegExp("^(\\s*)(" + name.replace(/-/g, "\\-") + ")(\\s|;|$)");
        let done = 0;
        const lines = mainFile.text().split("\n").map(l => {
            // one-line nodes only: a line opening a block is left alone
            if (re.test(l) && l.indexOf("{") < 0) {
                done++;
                return l.replace(re, "$1// $2$3") + " // turned off in Settings";
            }
            return l;
        });
        if (done) {
            mainWriter.path = Env.niriConfig;
            mainWriter.setText(lines.join("\n"));
            console.warn("Niri: commented out " + name + " in " + Env.niriConfig);
        }
    }
    // a section's `on` / `off` child
    function setOnOff(path, on) {
        if (typeof path === "string")
            path = path.split(".");
        const saved = own;
        own = Kdl.clone(own);
        const sec = _ensure(own, path);
        sec.children = sec.children.filter(c => c.name !== "on" && c.name !== "off");
        sec.children.unshift(Kdl.node(on ? "on" : "off"));
        _changed(saved);
    }
    function remove(path) {
        if (typeof path === "string")
            path = path.split(".");
        const saved = own;
        own = Kdl.clone(own);
        _prepare(path);
        const parent = path.length > 1 ? _find(own, path.slice(0, -1)) : { "children": own };
        if (parent && parent.children) {
            const kept = parent.children.filter(n => n.name !== path[path.length - 1]);
            parent.children.length = 0;
            for (const k of kept)
                parent.children.push(k);
        }
        _changed(saved);
    }
    // replace every top-level node of one kind that `match` accepts (window rules, outputs...) with `nodes`
    function replaceNodes(match, nodes) {
        const saved = own;
        own = own.filter(n => !match(n)).concat(nodes);
        _changed(saved);
    }
    // the app's nodes of one kind (e.g. its window rules)
    function ownNodes(match) {
        return own.filter(match);
    }
    function mainNodes(match) {
        return main.filter(match);
    }
    // binds: every key, config.kdl's then the app's (the app's win)
    function binds() {
        const out = {};
        for (const list of [main, own])
            for (const b of list.filter(n => n.name === "binds"))
                for (const k of b.children || [])
                    out[k.name] = { "key": k.name, "props": k.props, "action": (k.children || [])[0] || null, "origin": list === own ? "app" : "config" };
        return out;
    }
    // remove a shortcut wherever it is: from the app's file, and from config.kdl by commenting out its
    // lines (an included file can't take a key back from config.kdl)
    function removeBind(key) {
        setBind(key, null);
        const lines = mainFile.text().split("\n");
        const re = new RegExp("^(\\s*)" + key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "(\\s|\\{)", "i");
        let inBinds = false, depth = 0, done = false;
        for (let i = 0; i < lines.length && !done; i++) {
            const l = lines[i];
            if (!inBinds) {
                if (/^\s*binds\s*\{/.test(l))
                    inBinds = true;
                continue;
            }
            if (/^\s*\}/.test(l) && depth === 0)
                break;
            if (!re.test(l))
                continue;
            // this bind, through its closing brace
            let open = 0, j = i;
            do {
                open += (lines[j].match(/\{/g) || []).length - (lines[j].match(/\}/g) || []).length;
                lines[j] = lines[j].replace(/^(\s*)/, "$1// ") + (j === i ? " // removed in Settings" : "");
                j++;
            } while (open > 0 && j < lines.length);
            done = true;
        }
        if (done) {
            mainWriter.path = Env.niriConfig;
            mainWriter.setText(lines.join("\n"));
        }
    }
    function setBind(key, actionNode, props) {
        const saved = own;
        own = Kdl.clone(own);
        const b = _ensure(own, ["binds"]);
        b.children = b.children.filter(c => c.name !== key);
        if (actionNode)
            b.children.push(Kdl.node(key, [], props || {}, [actionNode]));
        _changed(saved);
    }

    function _changed(previous) {
        revision++;
        _previous = _previous === null ? previous : _previous;
        saveTimer.restart();
    }
    property var _previous: null
    Timer {
        id: saveTimer
        interval: 350
        onTriggered: niri.save()
    }
    // check, then write; a rejected file is never written and the change is undone. The candidate is
    // written, validated and deleted by one shell command, under its own name: written from QML, the
    // write could land after niri had already looked ("No such file or directory"), and a second
    // save's file could be deleted by the first one's cleanup. One save at a time; a change made during
    // a check is saved right after it.
    property bool _saving: false
    property bool _saveAgain: false
    property int _checks: 0
    function save() {
        if (_saving) {
            _saveAgain = true;
            return;
        }
        _saving = true;
        const text = header + Kdl.write(own);
        const candidate = Env.niriDir + "/.settings.kdl.check-" + (++_checks);
        Env.read(["sh", "-c", 'printf "%s" "$1" > "$2" || exit 97; niri validate -c "$2"; rc=$?; rm -f "$2"; exit $rc', "sh", text, candidate], (code, out, err) => {
            if (code === 0) {
                lastError = "";
                _previous = null;
                _writing = true;
                ownFile.setText(text);
            } else {
                const msg = code === 97 ? "couldn't write in " + Env.niriDir : (err || out).split("\n").filter(l => /error|×|invalid|unknown|expected/i.test(l)).map(l => l.replace(/\x1b\[[0-9;]*m/g, "").trim()).slice(0, 3).join(" ");
                lastError = msg || "niri rejected the change";
                console.warn("Niri: change rejected: " + lastError);
                if (_previous !== null) {
                    own = _previous;
                    _previous = null;
                    revision++;
                }
            }
            _saving = false;
            if (_saveAgain) {
                _saveAgain = false;
                save();
            }
        });
    }
    property bool _writing: false

    // ---- the files ----
    FileView {
        id: mainFile
        path: Env.niriConfig
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                niri.main = Kdl.parse(text());
            } catch (e) {
                console.warn("Niri: can't read config.kdl: " + e.message);
                niri.main = [];
            }
            niri.revision++;
            niri._ensureInclude(text());
            niri.ready = true;
            niri.readOutputs();
        }
        onLoadFailed: niri.ready = true
    }
    FileView {
        id: ownFile
        path: niri.ownPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: {
            if (niri._writing)
                niri._writing = false;
            else
                reload();
        }
        onLoaded: {
            try {
                niri.own = Kdl.parse(text());
            } catch (e) {
                console.warn("Niri: can't read settings.kdl: " + e.message);
            }
            niri.revision++;
        }
        onSaved: Qt.callLater(niri.readOutputs)
        // no file yet: start one, so niri doesn't warn about a missing include on every reload
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                // after this failed read has finished
                Qt.callLater(() => {
                    niri._writing = true;
                    ownFile.setText(niri.header);
                });
            }
        }
    }

    // config.kdl must end by including the app's file: checked every time the app opens (and whenever
    // config.kdl changes while it runs). A commented-out include doesn't count.
    function _ensureInclude(text) {
        const has = text.split("\n").some(l => /^\s*include\s+(optional=(true|#true)\s+)?"(\.\/)?settings\.kdl"/.test(l));
        if (has)
            return;
        const add = (text.endsWith("\n") ? "" : "\n") + "\n// Settings app: its choices live in settings.kdl and win over the lines above.\ninclude optional=true \"settings.kdl\"\n";
        mainWriter.path = Env.niriConfig;
        mainWriter.setText(text + add);
        console.warn("Niri: added the settings.kdl include to " + Env.niriConfig);
    }
    FileView {
        id: mainWriter
        atomicWrites: true
    }

    // ---- outputs, live from niri ----
    function readOutputs() {
        Env.read(["niri", "msg", "--json", "outputs"], (code, out) => {
            if (code !== 0)
                return;
            try {
                const o = JSON.parse(out);
                niri.outputs = Object.keys(o).sort().map(name => {
                    const d = o[name];
                    const l = d.logical || {};
                    return {
                        "name": name,
                        "make": d.make || "",
                        "model": d.model || "",
                        "serial": d.serial || "",
                        "physical": d.physical_size || null,
                        "modes": (d.modes || []).map(m => ({ "width": m.width, "height": m.height, "refresh": m.refresh_rate / 1000, "preferred": m.is_preferred })),
                        "mode": d.current_mode === null || d.current_mode === undefined ? -1 : d.current_mode,
                        "x": l.x || 0,
                        "y": l.y || 0,
                        "width": l.width || 0,
                        "height": l.height || 0,
                        "scale": l.scale || 1,
                        "transform": l.transform || "Normal",
                        "vrrSupported": !!d.vrr_supported,
                        "vrrEnabled": !!d.vrr_enabled,
                        "enabled": !!d.logical
                    };
                });
            } catch (e) {
                console.warn("Niri: bad outputs JSON: " + e.message);
            }
        });
    }
    // While a page shows the screens (watchOutputs), re-read them each time niri has applied its config
    // (ConfigLoaded) or a screen came or went (WorkspacesChanged). Reading right after writing the file
    // was too early: niri hadn't reloaded yet, so the page showed the previous settings until the next
    // click.
    property bool watchOutputs: false
    Process {
        running: niri.watchOutputs
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                if (/^\{"(ConfigLoaded|WorkspacesChanged)"/.test(line))
                    outputsTimer.restart();
            }
        }
    }
    Timer {
        id: outputsTimer
        interval: 80
        onTriggered: niri.readOutputs()
    }
    // write one output's whole block (its config.kdl block is the base, so nothing set there is lost)
    function setOutput(name, fields) {
        const saved = own;
        const base = _find(own.filter(n => n.name === "output" && n.args[0] === name), []) || null;
        const theirs = main.filter(n => n.name === "output" && n.args[0] === name).pop();
        const mine = own.filter(n => n.name === "output" && n.args[0] === name).pop();
        const block = Kdl.clone(mine || theirs || Kdl.node("output", [name], {}, []));
        if (!block.children)
            block.children = [];
        for (const key in fields) {
            block.children = block.children.filter(c => c.name !== key);
            const v = fields[key];
            if (v !== undefined && v !== null)
                block.children.push(v);
        }
        own = own.filter(n => !(n.name === "output" && n.args[0] === name)).concat([block]);
        _changed(saved);
    }
    function outputNode(name) {
        return own.filter(n => n.name === "output" && n.args[0] === name).pop() || main.filter(n => n.name === "output" && n.args[0] === name).pop() || null;
    }

    // ---- wallpaper: swaybg started by niri ----
    // The app's own line (`sh -c "pkill -x swaybg; exec swaybg ..."`) comes after config.kdl's, so it
    // replaces whatever config.kdl starts. The picture shown: the app's, else config.kdl's swaybg -i.
    readonly property string wallpaper: {
        revision;
        const pick = list => {
            let found = "";
            for (const n of list.filter(n => n.name === "spawn-at-startup")) {
                const a = n.args.map(String);
                if (a[0] === "swaybg") {
                    const i = a.indexOf("-i");
                    if (i >= 0)
                        found = a[i + 1];
                } else if (a[0] === "sh" && /swaybg/.test(a[2] || "") && a.length > 4) {
                    found = a[4];
                }
            }
            return found;
        };
        return (pick(own) || pick(main)).replace(/^~/, Env.home);
    }
    readonly property string wallpaperMode: {
        revision;
        const n = own.filter(n => n.name === "spawn-at-startup" && n.args[0] === "sh" && /swaybg/.test(n.args[2] || "")).pop();
        const m = n ? /-m (\w+)/.exec(n.args[2]) : null;
        return m ? m[1] : "fill";
    }
    function setWallpaper(path, mode) {
        const script = "pkill -x swaybg; exec swaybg -m " + (mode || "fill") + " -i \"$1\"";
        const args = ["sh", "-c", script, "sh", path];
        replaceNodes(n => n.name === "spawn-at-startup" && n.args[0] === "sh" && /swaybg/.test(n.args[2] || ""), [Kdl.node("spawn-at-startup", args)]);
        Env.launch(args);
    }

    // ---- actions (niri msg) ----
    function action(args) {
        Env.write(["niri", "msg", "action"].concat(args));
    }
}
