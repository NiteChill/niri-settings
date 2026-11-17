#!/usr/bin/env python3
"""Capture stills of the real Dynamic Island for the showcase (pages/IslandShowcase.qml).

Each still is the island itself (its own pixels, with transparency, at 2x), so the showcase shows exactly
what people get: it places them over the viewer's wallpaper. Run it again whenever the island's look
changes:   python3 tools/capture-island.py [island folder, default ~/.config/quickshell]

How: the island is copied to a temporary folder and staged there (never the real one): a fixed clock
(9:41), a neutral Wi-Fi name ("Home"), a made-up song and message with generated pictures; Focus only
inside the copy; no sounds, no alerts of its own, nothing run. It opens each state, waits for the island
to settle, and grabs it. Output: assets/island-shots/<name>.png + shots.json [{name, caption, file, x
(centre offset), y, w, h}]. The copy shows on screen for ~20 s.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

APP = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
ISLAND = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.config/quickshell")
OUT = os.path.join(APP, "assets", "island-shots")
SCALE = 2

# what's shown, in order, with what the showcase says about it
SHOTS = [
    ("rest", "At rest, it shows the time and what matters"),
    ("search", "Press Super + Space to find apps, files, settings and the web"),
    ("notification", "Notifications arrive softly, right where you look"),
    ("media", "Your music: the song, its cover and its controls"),
    ("battery", "The battery, with how long it lasts"),
    ("quickSettings", "Quick settings: Wi-Fi, Bluetooth, Focus, sound, brightness"),
    ("time", "The time, the day and the week"),
]


def patch(path, old, new):
    s = open(path, encoding="utf-8").read()
    if old not in s:
        raise SystemExit(f"capture-island: can't stage {os.path.basename(path)}: {old[:60]!r} not found")
    open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))


def gradient(path, size, a, b, round_=False):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)
            px[x, y] = tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3)) + (255,)
    if round_:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        img.putalpha(mask)
    img.save(path)


def main():
    work = tempfile.mkdtemp(prefix="island-shots-")
    shots = os.path.join(work, "shots")
    os.makedirs(shots)
    for name in ["assets", "config", "island", "modes", "services", "tools", "widgets", "shell.qml", "ScreenCorners.qml"]:
        src = os.path.join(ISLAND, name)
        (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(work, name))
    cover = os.path.join(work, "cover.png")
    gradient(cover, 256, (255, 150, 92), (194, 69, 122))
    avatar = os.path.join(work, "avatar.png")
    gradient(avatar, 128, (90, 200, 250), (88, 86, 214), round_=True)

    sys_qml = os.path.join(work, "services", "Sys.qml")
    patch(sys_qml, "readonly property date time: clock.date ? clock.date : new Date()",
          "readonly property date time: new Date(2026, 0, 1, 9, 41)")
    patch(sys_qml, '"ssid": _wifiActive ? (_wifiActive.ssid || _wifiActive.name || "") : "",', '"ssid": _wifiActive ? "Home" : "",')
    patch(sys_qml, '"name": _wifiActive ? (_wifiActive.name || "") : "",', '"name": _wifiActive ? "Home" : "",')
    patch(sys_qml, """        systemFocus = on;
        run(["gsettings", "set", "org.gnome.desktop.notifications", "show-banners", on ? "false" : "true"]);""",
          """        systemFocus = on;""")
    patch(sys_qml, "    function run(command) {", "    function run(command) {\n        return;")
    patch(sys_qml, "    function playSound(file) {", "    function playSound(file) {\n        return;")
    patch(sys_qml, "    readonly property var media: {", """    property var demoSearch: null
    property bool demoPlaying: false
    readonly property var media: demoPlaying ? ({
            "active": true, "playing": true, "title": "Golden Hour Drive", "artist": "Neon Coast", "album": "",
            "app": "Music", "artUrl": "file://%s", "length": 223, "canPlayPause": true, "canNext": true,
            "canPrevious": true, "canSeek": true
        }) : ({ "active": false, "playing": false, "title": "", "artist": "", "album": "", "app": "",
            "artUrl": "", "length": 0, "canPlayPause": false, "canNext": false, "canPrevious": false, "canSeek": false })
    readonly property var _realMedia: {""" % cover)
    patch(sys_qml, "    function mediaPositionNow() {", "    function mediaPositionNow() {\n        if (demoPlaying)\n            return 83;")
    patch(sys_qml, "    readonly property real mediaRate: _anchorRate", "    readonly property real mediaRate: demoPlaying ? 0 : _anchorRate")
    # only what the script shows: no alerts from the real computer while capturing
    patch(os.path.join(work, "services", "Activity.qml"), "    function show(kind, key, cls, data, timeout) {",
          "    property bool demoAllow: false\n    function show(kind, key, cls, data, timeout) {\n        if (cls !== \"panel\" && !demoAllow)\n            return;")
    cfg = os.path.join(work, "config", "config.jsonc")
    s = open(cfg, encoding="utf-8").read()
    s = re.sub(r'//\s*"realSound": true,', '"realSound": false,', s, count=1)
    s = re.sub(r'(//\s*)?"collapseDelay": \d+,', '"collapseDelay": 60000,', s, count=1)
    open(cfg, "w", encoding="utf-8").write(s)
    patch(os.path.join(work, "modes", "SearchMode.qml"), "    readonly property var layout: Config.search",
          "    readonly property var layout: Config.search\n    readonly property var demoInput: input\n    Component.onCompleted: Sys.demoSearch = mode")

    order = json.dumps([name for name, _ in SHOTS])
    shell = os.path.join(work, "shell.qml")
    patch(shell, "    IpcHandler {", """    // ---- capture-island.py: each state, settled, grabbed ----
    readonly property var demoOrder: %s
    property int demoIndex: -1
    property int demoTick: 0
    // a message from someone, as an app would send it
    readonly property var demoNote: ({
        "id": 9001, "appName": "Messages", "summary": "Alex", "body": "Dinner at 8? I booked the place by the river.",
        "appIcon": "", "image": "file://%s", "desktopEntry": "", "urgency": 1,
        "actions": [{ "identifier": "reply", "text": "Reply", "invoke": function() {} }],
        "expireTimeout": 0, "tracked": false, "dismiss": function() {}, "expire": function() {}
    })
    function demoOpen(name) {
        Activity.demoAllow = false;
        Sys.demoPlaying = false;
        if (name === "rest")
            root.open("idle", false);
        else if (name === "search") {
            root.open("search", false);
            Qt.callLater(() => Sys.demoSearch.demoInput.text = "night light");
        } else if (name === "notification") {
            root.open("idle", false);
            Activity.demoAllow = true;
            Activity.show("notification", "n9001", "notification", root.demoNote, 600000);
        } else if (name === "media") {
            Sys.demoPlaying = true;
            root.open("media", false);
        } else
            root.open(name, false);
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            root.demoTick++;
            // 1.5 s for each state: open it, let it settle, grab it
            const step = Math.floor(root.demoTick / 15) - 1;
            const phase = root.demoTick %% 15;
            if (step < 0)
                return;
            if (step >= root.demoOrder.length) {
                console.warn("DEMO-END");
                Qt.quit();
                return;
            }
            const name = root.demoOrder[step];
            if (phase === 0) {
                Activity.clear && Activity.clear();
                root.demoOpen(name);
            }
            if (phase === 13) {
                const p = island.mapToItem(null, 0, 0);
                const info = { "name": name, "x": p.x + island.width / 2 - island.Window.width / 2, "y": p.y, "w": island.width, "h": island.height };
                island.grabToImage(r => {
                    r.saveToFile("%s/" + name + ".png");
                    console.warn("DEMO-SHOT " + JSON.stringify(info));
                }, Qt.size(Math.ceil(island.width * %d), Math.ceil(island.height * %d)));
            }
        }
    }
    IpcHandler {""" % (order, avatar, shots, SCALE, SCALE))

    log = os.path.join(work, "run.log")
    with open(log, "w") as f:
        subprocess.run(["timeout", "-s", "INT", "40", "qs", "-p", work], stdout=f, stderr=subprocess.STDOUT)
    text = open(log, encoding="utf-8", errors="replace").read()
    infos = {i["name"]: i for i in (json.loads(m) for m in re.findall(r"DEMO-SHOT (\{.*?\})\s*$", text, re.M))}
    if "DEMO-END" not in text or len(infos) < len(SHOTS):
        raise SystemExit("capture-island: not every state was captured; see " + log)

    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    out = []
    for name, caption in SHOTS:
        info = infos[name]
        Image.open(os.path.join(shots, name + ".png")).save(os.path.join(OUT, name + ".png"), optimize=True)
        out.append({"name": name, "caption": caption, "file": name + ".png", "x": round(info["x"], 2),
                    "y": round(info["y"], 2), "w": round(info["w"], 2), "h": round(info["h"], 2)})
    json.dump({"scale": SCALE, "shots": out}, open(os.path.join(OUT, "shots.json"), "w"), indent=1)
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"capture-island: {len(out)} stills, {size / 1e3:.0f} kB in {OUT}")
    shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
