pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The machine: name, date and time, region, the user, hardware and OS facts, installed apps, default apps,
// startup apps. Read once (and again after a change); writes go through systemd's tools (hostnamectl,
// timedatectl, localectl), AccountsService, xdg-mime and ~/.config/autostart. In the sandbox (Env), the
// writes are logged instead.
Singleton {
    id: host

    // ---- name ----
    property string hostname: ""
    property string prettyName: ""
    function setPrettyName(name) {
        prettyName = name;
        const plain = name.toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "") || "localhost";
        Env.write(["hostnamectl", "set-hostname", "--pretty", name]);
        Env.write(["hostnamectl", "set-hostname", "--static", plain]);
    }

    // ---- date and time ----
    property string timezone: ""
    property bool ntp: false
    property bool ntpAvailable: true
    property var timezones: []
    function setTimezone(tz) {
        timezone = tz;
        Env.write(["timedatectl", "set-timezone", tz]);
    }
    function setNtp(on) {
        ntp = on;
        Env.write(["timedatectl", "set-ntp", on ? "true" : "false"]);
    }
    function loadTimezones() {
        if (timezones.length)
            return;
        Env.read(["timedatectl", "list-timezones"], (code, out) => host.timezones = out.trim().split("\n").filter(l => l));
    }

    // ---- region ----
    property string locale: ""        // LANG
    property string formats: ""       // LC_TIME (the formats people see), "" = same as the language
    property var locales: []
    function loadLocales() {
        if (locales.length)
            return;
        Env.read(["localectl", "list-locales"], (code, out) => host.locales = out.trim().split("\n").filter(l => l));
    }
    function setLocale(lang) {
        locale = lang;
        Env.write(["localectl", "set-locale", "LANG=" + lang].concat(formats && formats !== lang ? ["LC_TIME=" + formats, "LC_NUMERIC=" + formats, "LC_MEASUREMENT=" + formats, "LC_PAPER=" + formats, "LC_MONETARY=" + formats] : []));
    }
    function setFormats(f) {
        formats = f;
        Env.write(["localectl", "set-locale", "LANG=" + locale, "LC_TIME=" + f, "LC_NUMERIC=" + f, "LC_MEASUREMENT=" + f, "LC_PAPER=" + f, "LC_MONETARY=" + f]);
    }

    // ---- the user ----
    property string user: Quickshell.env("USER") || ""
    property string realName: ""
    property string iconFile: ""
    property string accountType: ""
    readonly property string _userPath: "/org/freedesktop/Accounts/User" + uid
    property int uid: 1000
    function setRealName(name) {
        realName = name;
        Env.write(["busctl", "call", "org.freedesktop.Accounts", _userPath, "org.freedesktop.Accounts.User", "SetRealName", "s", name]);
    }
    function setIcon(file) {
        iconFile = file;
        Env.write(["busctl", "call", "org.freedesktop.Accounts", _userPath, "org.freedesktop.Accounts.User", "SetIconFile", "s", file]);
    }

    // ---- about ----
    property var about: ({})   // { os, osVersion, logo, kernel, cpu, memory, gpu, disk, model, niri }

    // ---- apps ----
    // installed apps: [{ id (desktop file name), name, icon, mime: [types], exec }]
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
                "id": e.id + ".desktop",
                "name": e.name,
                "icon": e.icon,
                "exec": e.execString,
                "categories": e.categories || []
            })).sort((a, b) => a.name.localeCompare(b.name))
    function appName(id) {
        const a = apps.find(x => x.id === id);
        return a ? a.name : id.replace(/\.desktop$/, "");
    }
    function appIcon(id) {
        const a = apps.find(x => x.id === id);
        return a ? a.icon : "";
    }
    // default apps by role: { web: "firefox.desktop", ... }
    readonly property var roles: ({
        "web": "x-scheme-handler/https",
        "mail": "x-scheme-handler/mailto",
        "calendar": "text/calendar",
        "music": "audio/mpeg",
        "video": "video/mp4",
        "photos": "image/jpeg",
        "files": "inode/directory",
        "text": "text/plain",
        "pdf": "application/pdf"
    })
    readonly property var roleExtra: ({
        "web": ["x-scheme-handler/http", "text/html"],
        "music": ["audio/flac", "audio/ogg", "audio/x-wav"],
        "video": ["video/x-matroska", "video/webm"],
        "photos": ["image/png", "image/webp", "image/gif"]
    })
    property var defaults: ({})
    function readDefaults() {
        for (const role in roles) {
            const r = role;
            Env.read(["xdg-mime", "query", "default", roles[r]], (code, out) => {
                const next = Object.assign({}, host.defaults);
                next[r] = out.trim();
                host.defaults = next;
            });
        }
    }
    function setDefault(role, id) {
        const next = Object.assign({}, defaults);
        next[role] = id;
        defaults = next;
        for (const mime of [roles[role]].concat(roleExtra[role] || []))
            Env.write(["xdg-mime", "default", id, mime]);
    }
    // apps that can open a role's type, from their desktop files' MimeType= line (Quickshell's
    // DesktopEntry doesn't expose it, so the files are read here: once, and again when apps change).
    // The current default is always listed, even if its file doesn't claim the type.
    function appsFor(role) {
        const mime = roles[role];
        const list = apps.filter(a => (mimeTypes[a.id] || []).indexOf(mime) >= 0);
        const cur = defaults[role];
        if (cur && !list.some(a => a.id === cur))
            list.push({ "id": cur, "name": appName(cur), "icon": appIcon(cur) });
        return list.sort((a, b) => a.name.localeCompare(b.name));
    }
    // { "org.gnome.Nautilus.desktop": ["inode/directory", ...] }
    property var mimeTypes: ({})
    function readMimeTypes() {
        // every applications folder, most important first (like xdg); prints "<dir>\t<file>:MimeType=..."
        const script = 'IFS=:; for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do '
            + '[ -d "$d/applications" ] || continue; '
            + 'find "$d/applications" -name "*.desktop" -exec grep -H -m1 "^MimeType=" {} + 2>/dev/null | sed "s|^|$d/applications/\t|"; done';
        Env.read(["sh", "-c", script], (code, out) => {
            const map = {};
            for (const line of out.split("\n")) {
                const m = line.match(/^([^\t]*)\t(.*?):MimeType=(.*)$/);
                if (!m)
                    continue;
                // the desktop id: the path under applications/, with "/" as "-"
                const id = m[2].substring(m[1].length).replace(/\//g, "-");
                if (!(id in map))
                    map[id] = m[3].split(";").filter(t => t !== "");
            }
            host.mimeTypes = map;
        });
    }
    readonly property int _appCount: DesktopEntries.applications.values.length
    on_AppCountChanged: mimeTimer.restart()
    Timer {
        id: mimeTimer
        interval: 300
        onTriggered: host.readMimeTypes()
    }

    // ---- startup apps: ~/.config/autostart/*.desktop (Hidden=true means off) ----
    readonly property string autostartDir: (Env.sandboxed ? Env.sandbox : Env.home + "/.config") + "/autostart"
    property var startup: []   // [{ file, id, name, icon, enabled }]
    function readStartup() {
        Env.read(["sh", "-c", "for f in \"$1\"/*.desktop; do [ -f \"$f\" ] || continue; printf '%s\\t' \"$f\"; grep -m1 -E '^Name=' \"$f\" | cut -d= -f2- | tr -d '\\n'; printf '\\t'; grep -m1 -E '^Icon=' \"$f\" | cut -d= -f2- | tr -d '\\n'; printf '\\t'; grep -m1 -E '^Hidden=' \"$f\" | cut -d= -f2- | tr -d '\\n'; printf '\\n'; done", "sh", autostartDir], (code, out) => {
            host.startup = out.trim().split("\n").filter(l => l).map(l => {
                const f = l.split("\t");
                return { "file": f[0], "id": f[0].split("/").pop(), "name": f[1] || f[0].split("/").pop(), "icon": f[2] || "", "enabled": f[3] !== "true" };
            }).sort((a, b) => a.name.localeCompare(b.name));
        });
    }
    // add an installed app: copy its desktop file into autostart
    function addStartup(id) {
        const e = DesktopEntries.applications.values.find(x => x.id + ".desktop" === id);
        if (!e)
            return;
        const text = "[Desktop Entry]\nType=Application\nName=" + e.name + "\nExec=" + e.execString + "\nIcon=" + (e.icon || "") + "\nX-Settings-Added=true\n";
        _writeFile(autostartDir + "/" + id, text, () => host.readStartup());
    }
    function setStartupEnabled(file, on) {
        Env.write(["sh", "-c", "grep -q '^Hidden=' \"$1\" && sed -i \"s/^Hidden=.*/Hidden=$2/\" \"$1\" || printf 'Hidden=%s\\n' \"$2\" >> \"$1\"", "sh", file, on ? "false" : "true"], () => host.readStartup());
    }
    function removeStartup(file) {
        Env.write(["rm", "-f", file], () => host.readStartup());
    }
    // write a small file (the autostart folder is ours to write, also in the sandbox, where it lives there)
    function _writeFile(path, text, done) {
        Env.read(["mkdir", "-p", path.substring(0, path.lastIndexOf("/"))], () => writer.createObject(host, { "target": path, "content": text, "done": done }));
    }
    Component {
        id: writer
        FileView {
            property string target
            property string content
            property var done
            Component.onCompleted: {
                path = target;
                setText(content);
            }
            onSaved: {
                if (done)
                    done();
                destroy();
            }
        }
    }

    function refresh() {
        Env.read(["hostnamectl", "--json=short"], (code, out) => {
            try {
                const j = JSON.parse(out);
                host.hostname = j.StaticHostname || j.Hostname || "";
                host.prettyName = j.PrettyHostname || "";
                const ab = Object.assign({}, host.about);
                ab.model = [j.HardwareVendor, j.HardwareModel].filter(x => x).join(" ");
                ab.os = j.OperatingSystemPrettyName || "";
                ab.kernel = j.KernelRelease || "";
                ab.chassis = j.Chassis || "";
                host.about = ab;
            } catch (e) {}
        });
        Env.read(["timedatectl", "show"], (code, out) => {
            for (const l of out.split("\n")) {
                const [k, v] = [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)];
                if (k === "Timezone") host.timezone = v;
                if (k === "NTP") host.ntp = v === "yes";
                if (k === "CanNTP") host.ntpAvailable = v === "yes";
            }
        });
        Env.read(["localectl", "status"], (code, out) => {
            const lang = out.match(/LANG=(\S+)/);
            const time = out.match(/LC_TIME=(\S+)/);
            host.locale = lang ? lang[1] : "";
            host.formats = time ? time[1] : "";
        });
        Env.read(["id", "-u"], (code, out) => {
            host.uid = parseInt(out) || 1000;
            Env.read(["busctl", "get-property", "org.freedesktop.Accounts", host._userPath, "org.freedesktop.Accounts.User", "RealName"], (c, o) => {
                const m = o.match(/"(.*)"/);
                host.realName = m ? m[1] : "";
            });
            Env.read(["busctl", "get-property", "org.freedesktop.Accounts", host._userPath, "org.freedesktop.Accounts.User", "IconFile"], (c, o) => {
                const m = o.match(/"(.*)"/);
                host.iconFile = m ? m[1] : "";
            });
            Env.read(["busctl", "get-property", "org.freedesktop.Accounts", host._userPath, "org.freedesktop.Accounts.User", "AccountType"], (c, o) => {
                host.accountType = /i 1/.test(o) ? "Administrator" : "Standard";
            });
        });
        Env.read(["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; nproc; grep MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2; lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3; df -B1 --output=size / | tail -1; . /etc/os-release; echo \"$LOGO\"; niri --version 2>/dev/null; qs --version 2>/dev/null | head -1"], (code, out) => {
            const f = out.split("\n");
            const ab = Object.assign({}, host.about);
            ab.cpu = (f[0] || "").trim().replace(/\(R\)|\(TM\)/g, "").replace(/\s+/g, " ");
            ab.cores = parseInt(f[1]) || 0;
            ab.memory = Math.round((parseInt(f[2]) || 0) / 1024 / 1024);
            ab.gpu = (f[3] || "").trim().replace(/\[|\]/g, "").replace(/\s*\(rev [^)]*\)/, "");
            ab.disk = Math.round((parseInt(f[4]) || 0) / 1e9);
            ab.logo = (f[5] || "").trim();
            ab.niri = (f[6] || "").trim();
            ab.quickshell = (f[7] || "").trim().replace(/\s*\(.*$/, "");
            host.about = ab;
        });
        readDefaults();
        readMimeTypes();
        readStartup();
    }
    Component.onCompleted: refresh()
}
