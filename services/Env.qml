pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Where things live, and running commands.
//   SETTINGS_SANDBOX=<dir>  test mode: niri's config is <dir>/niri, the island's <dir>/island, and every
//                           command that would change the system is logged instead of run (reads still
//                           run). Set DCONF_PROFILE too so gsettings writes land in a test database.
//   ISLAND_DIR=<dir>        the island's folder (default ~/.config/quickshell)
//   SETTINGS_DEV=1          show the component gallery in the sidebar
//   SETTINGS_NO_ISLAND=1    act as if the Dynamic Island weren't installed
//   NIRI_CONFIG=<file>      niri's main config (niri's own variable; default ~/.config/niri/config.kdl)
Singleton {
    id: env

    readonly property string home: Quickshell.env("HOME")
    // SETTINGS_NO_ISLAND=1: act as if the Dynamic Island weren't installed (to see the app as people
    // without it do: its settings hidden, the island page a showcase)
    readonly property bool noIsland: Quickshell.env("SETTINGS_NO_ISLAND") === "1"
    // where people get the Dynamic Island (the showcase's button); empty = "coming soon"
    readonly property string islandHomepage: Quickshell.env("SETTINGS_ISLAND_URL") || ""
    // SETTINGS_DEV=1: show the developer pages (the component gallery)
    readonly property bool dev: Quickshell.env("SETTINGS_DEV") === "1"
    readonly property string sandbox: Quickshell.env("SETTINGS_SANDBOX") || ""
    readonly property bool sandboxed: sandbox !== ""
    readonly property string niriConfig: sandboxed ? sandbox + "/niri/config.kdl" : (Quickshell.env("NIRI_CONFIG") || home + "/.config/niri/config.kdl")
    readonly property string niriDir: niriConfig.substring(0, niriConfig.lastIndexOf("/"))
    readonly property string islandDir: sandboxed ? sandbox + "/island" : (Quickshell.env("ISLAND_DIR") || home + "/.config/quickshell")
    readonly property string appDir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/$/, "")

    // run a command that only reads; done(exitCode, stdout, stderr) when it ends
    function read(cmd, done) {
        readFor(env, cmd, done);
    }
    // the same, for a page: the command belongs to `owner` and goes with it, so a page you've already
    // left never gets an answer it can't hold any more
    function readFor(owner, cmd, done) {
        const p = proc.createObject(owner, { "command": cmd, "callback": done || null });
        p.running = true;
    }
    // run a command that changes something: in the sandbox it's only logged (done(0, "", "") still runs)
    function write(cmd, done) {
        if (sandboxed) {
            console.warn("SANDBOX would run: " + JSON.stringify(cmd));
            if (done)
                Qt.callLater(() => done(0, "", ""));
            return;
        }
        read(cmd, done);
    }
    // start something that outlives us (an app, a terminal); never in the sandbox
    function launch(cmd) {
        if (sandboxed) {
            console.warn("SANDBOX would launch: " + JSON.stringify(cmd));
            return;
        }
        // what started us stays ours: an app opened from here (a terminal through a file manager...)
        // mustn't inherit the settings app's QS_CONFIG_PATH, or `qs` in it would talk to us, not the island
        Quickshell.execDetached(["env", "-u", "QS_CONFIG_PATH", "-u", "QS_ICON_THEME", "-u", "SETTINGS_PAGE", "-u", "SETTINGS_SETTING"].concat(cmd));
    }

    Component {
        id: proc
        Process {
            id: p
            property var callback
            property string out: ""
            property string err: ""
            stdout: StdioCollector {
                onStreamFinished: p.out = text
            }
            stderr: StdioCollector {
                onStreamFinished: p.err = text
            }
            onExited: code => {
                // collectors finish just after exit: read them on the next turn
                Qt.callLater(() => {
                    if (p.callback)
                        p.callback(code, p.out, p.err);
                    p.destroy();
                });
            }
        }
    }
}
