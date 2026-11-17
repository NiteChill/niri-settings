pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop-wide settings (gsettings / dconf), the ones GTK apps, portals and the island read. Every schema
// below is read once (one process), then followed by a single `dconf watch /` (a path line, then the new
// value or "unset"; nothing polls). get("interface", "color-scheme", "default"); set("interface",
// "accent-color", "blue"). Writes show at once and reach dconf after a short pause, the latest value per
// key only: a slider dragged across 20 steps runs gsettings once, not 20 times.
// Short schema names: interface, privacy, a11y, a11yApps, proxy, location, sound, notifications.
Singleton {
    id: desktop

    readonly property var schemas: ({
        "interface": "org.gnome.desktop.interface",
        "privacy": "org.gnome.desktop.privacy",
        "a11y": "org.gnome.desktop.a11y.interface",
        "a11yApps": "org.gnome.desktop.a11y.applications",
        "proxy": "org.gnome.system.proxy",
        "location": "org.gnome.system.location",
        "sound": "org.gnome.desktop.sound",
        "notifications": "org.gnome.desktop.notifications"
    })
    // "schema key" -> value
    property var values: ({})

    function get(schema, key, def) {
        const v = values[schemas[schema] + " " + key];
        return v === undefined ? def : v;
    }
    property var _writes: ({})   // "schema key" -> [schema, key, text], waiting for writeTimer
    function set(schema, key, value) {
        const full = schemas[schema];
        const next = Object.assign({}, values);
        next[full + " " + key] = value;
        values = next;
        _writes[full + " " + key] = [full, key, typeof value === "string" ? value : String(value)];
        writeTimer.restart();
    }
    Timer {
        id: writeTimer
        interval: 150
        onTriggered: {
            const w = desktop._writes;
            desktop._writes = {};
            for (const id in w)
                Env.write(["gsettings", "set"].concat(w[id]));
        }
    }

    // a GVariant as gsettings prints it -> a JS value
    function _value(text) {
        const t = text.trim();
        if (/^'.*'$/.test(t))
            return t.slice(1, -1).replace(/\\'/g, "'");
        if (t === "true" || t === "false")
            return t === "true";
        const num = t.replace(/^(u?int(16|32|64)|byte|double)\s+/, "");
        if (/^-?\d+(\.\d+)?(e-?\d+)?$/.test(num))
            return Number(num);
        return t;
    }
    function _store(schema, key, raw) {
        const id = schema + " " + key;
        const v = _value(raw);
        if (values[id] === v)
            return;
        const next = Object.assign({}, values);
        next[id] = v;
        values = next;
    }

    // every schema at once: "org.gnome.desktop.interface accent-color 'blue'"
    function readAll() {
        Env.read(["sh", "-c", "for s in \"$@\"; do gsettings list-recursively \"$s\"; done", "sh"].concat(Object.values(schemas)), (code, out) => {
            const next = Object.assign({}, desktop.values);
            for (const line of out.split("\n")) {
                const m = line.match(/^(\S+)\s+(\S+)\s+(.*)$/);
                if (m)
                    next[m[1] + " " + m[2]] = desktop._value(m[3]);
            }
            desktop.values = next;
        });
    }
    // dconf path -> [schema, key]: /org/gnome/desktop/interface/accent-color
    function _fromPath(path) {
        const i = path.lastIndexOf("/");
        return [path.slice(1, i).replace(/\//g, "."), path.slice(i + 1)];
    }
    property string _path: ""
    Process {
        id: watch
        command: ["dconf", "watch", "/"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("/")) {
                    desktop._path = line.trim();
                    return;
                }
                const v = line.trim();
                if (v === "" || desktop._path === "")
                    return;
                const [schema, key] = desktop._fromPath(desktop._path);
                desktop._path = "";
                if (v === "unset")
                    // back to its default: ask gsettings what that is
                    Env.read(["gsettings", "get", schema, key], (code, out) => {
                        if (code === 0)
                            desktop._store(schema, key, out);
                    });
                else
                    desktop._store(schema, key, v);
            }
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 1000
        onTriggered: {
            watch.running = true;
            desktop.readAll();
        }
    }
    Component.onCompleted: readAll()
}
