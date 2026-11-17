pragma Singleton
import QtQuick
import Quickshell

// What this computer lacks for the app, from `settings --doctor --quick --json` (bin/settings-doctor.py):
// read once at start (~0.1 s, one process). Pages ask has("wlsunset") / lacks(["networkmanager"]) and show
// a components/Missing banner instead of controls that can't work. Until the answer is in, everything
// counts as present (no banner flashing in on every start).
// install(ids): opens a terminal running this distro's install command (sudo asks for the password there),
// then checks again every few seconds until those things are present (at most installWatch), so the page
// fills in by itself. No terminal found, or no package for this distro: canInstall is false (the banner
// offers to copy what's needed instead).
// SETTINGS_PRETEND_MISSING=a,b (read by the doctor) shows the app without those things, for testing.
Singleton {
    id: deps

    property bool ready: false
    // id -> the doctor's entry { id, name, pages, package, install, note, url }, for what's missing
    property var missing: ({})
    // ids being installed right now (the banner says to finish in the terminal)
    property var installing: []

    function has(id) {
        return !missing[id];
    }
    // the entries missing among `ids`
    function lacks(ids) {
        const m = missing;
        return (ids || []).filter(id => m[id]).map(id => m[id]);
    }
    function canInstall(ids) {
        const gone = lacks(ids);
        return terminal !== "" && gone.length > 0 && gone.every(e => e.install !== "");
    }
    function isInstalling(ids) {
        return (ids || []).some(id => installing.indexOf(id) >= 0);
    }

    function refresh() {
        Env.read(["python3", Env.appDir + "/bin/settings-doctor.py", "--quick", "--json"], (code, out) => {
            let list = [];
            try {
                list = JSON.parse(out);
            } catch (e) {
                console.warn("Deps: the dependency check gave no answer: " + e.message);
                return;
            }
            const next = {};
            for (const e of list)
                if (!e.ok && !e.skipped)
                    next[e.id] = e;
            // replaced only when it changed: every page's banners and rows depend on it
            if (JSON.stringify(Object.keys(next).sort()) !== JSON.stringify(Object.keys(deps.missing).sort()))
                deps.missing = next;
            deps.installing = deps.installing.filter(id => next[id]);
            if (deps.installing.length === 0)
                watch.stop();
            deps.ready = true;
        });
    }
    Component.onCompleted: {
        refresh();
        findTerminal();
    }

    // ---- installing ----
    // the terminal to run the install in: the desktop's choice (xdg-terminal-exec, $TERMINAL), else the
    // first common one found; with how each takes a command to run
    property string terminal: ""
    readonly property var _terminals: ({
            "xdg-terminal-exec": [],
            "ghostty": ["-e"],
            "kitty": [],
            "foot": [],
            "alacritty": ["-e"],
            "wezterm": ["start", "--"],
            "ptyxis": ["--"],
            "kgx": ["--"],
            "gnome-terminal": ["--"],
            "konsole": ["-e"],
            "xfce4-terminal": ["-x"],
            "xterm": ["-e"]
        })
    function findTerminal() {
        const own = Quickshell.env("TERMINAL") || "";
        const names = ["xdg-terminal-exec"].concat(own && _terminals[own.split("/").pop()] !== undefined ? [own.split("/").pop()] : []).concat(Object.keys(_terminals).filter(n => n !== "xdg-terminal-exec"));
        Env.read(["sh", "-c", "for t in \"$@\"; do command -v \"$t\" >/dev/null && { echo \"$t\"; exit; }; done", "sh"].concat(names), (code, out) => deps.terminal = out.trim());
    }
    function install(ids) {
        const gone = lacks(ids).filter(e => e.install !== "");
        if (gone.length === 0 || terminal === "")
            return;
        // one command for all of them: this distro's install command, then every package
        const first = gone[0];
        const prefix = first.install.slice(0, first.install.length - first.package.length).trim().split(" ");
        const packages = gone.map(e => e.package).filter((p, i, all) => all.indexOf(p) === i);
        const say = "Installing what Settings needs for " + gone.map(e => e.name).join(", ") + ".";
        const script = "printf '%s\\n\\n' \"$1\"; shift; \"$@\"; echo; printf 'Done. Press Enter to close this window.'; read _";
        Env.launch([terminal].concat(_terminals[terminal] || []).concat(["sh", "-c", script, "sh", say]).concat(prefix).concat(packages));
        installing = installing.concat(ids.filter(id => installing.indexOf(id) < 0));
        watched = 0;
        watch.restart();
    }
    // after an install starts: check again until it's there (or give up after installWatch checks)
    property int watched: 0
    readonly property int installWatch: 200
    Timer {
        id: watch
        interval: 3000
        repeat: true
        onTriggered: {
            if (++deps.watched > deps.installWatch) {
                stop();
                deps.installing = [];
                return;
            }
            deps.refresh();
        }
    }
    // no way to install from here: what to tell someone who can (a plain text, for the clipboard)
    function describe(ids) {
        return lacks(ids).map(e => e.name + (e.package ? " (package: " + e.package + ")" : "") + (e.note ? ", " + e.note : "") + (e.url ? ", " + e.url : "")).join("\n");
    }
}
