pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

// Live hardware state and actions: Wi-Fi, wired / VPN connections, Bluetooth, sound, battery, power
// mode. Event-driven (Quickshell's services); the Wi-Fi scan and Bluetooth discovery run only while a
// page asks for them (wifiScan / bluetoothScan). Pages get plain values; actions take names / addresses,
// and the live object is looked up when acting. In the sandbox (Env), actions are logged, not done.
Singleton {
    id: hw

    // ==================== Wi-Fi ====================
    readonly property var wifiDevice: {
        const devs = Networking.devices ? Networking.devices.values : [];
        return devs.find(d => d.type === DeviceType.Wifi) || null;
    }
    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: !!Networking.wifiEnabled
    property bool wifiScan: false
    Binding {
        when: hw.wifiDevice !== null
        target: hw.wifiDevice
        property: "scannerEnabled"
        value: hw.wifiScan
    }
    // [{ name, bars 0-3, secure, known, connected, connecting, failed }], connected / saved first
    property var wifiNetworks: []
    property string _wifiSig: ""
    property string wifiFailed: ""
    readonly property var _wifiList: {
        if (!wifiDevice || !wifiDevice.networks)
            return [];
        const byName = {};
        for (const n of wifiDevice.networks.values) {
            if (!n.name)
                continue;
            const s = n.signalStrength;
            const item = {
                "name": n.name,
                "strength": s,
                "bars": s > 0.66 ? 3 : s > 0.4 ? 2 : s > 0.15 ? 1 : 0,
                "secure": n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
                "known": n.known,
                "connected": n.connected,
                "connecting": n.state === ConnectionState.Connecting,
                "failed": n.name === wifiFailed
            };
            const old = byName[n.name];
            if (!old || item.connected || (!old.connected && s > old.strength))
                byName[n.name] = item;
        }
        const rank = n => n.connected ? 2 : n.known ? 1 : 0;
        return Object.values(byName).sort((a, b) => rank(b) - rank(a) || b.bars - a.bars || a.name.localeCompare(b.name));
    }
    // a scan adds networks one by one: publish once per batch, not once per network
    on_WifiListChanged: Qt.callLater(_publishWifi)
    function _publishWifi() {
        const shown = _wifiList.map(n => ({ "name": n.name, "bars": n.bars, "secure": n.secure, "known": n.known, "connected": n.connected, "connecting": n.connecting, "failed": n.failed }));
        const sig = JSON.stringify(shown);
        if (sig !== _wifiSig) {
            _wifiSig = sig;
            wifiNetworks = shown;
        }
    }
    readonly property string wifiConnected: {
        const n = wifiNetworks.find(x => x.connected);
        return n ? n.name : "";
    }
    function setWifiEnabled(on) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would turn Wi-Fi " + on);
        Networking.wifiEnabled = on;
    }
    function _network(name) {
        if (!wifiDevice || !wifiDevice.networks)
            return null;
        let best = null;
        for (const n of wifiDevice.networks.values)
            if (n.name === name && (!best || n.connected || n.signalStrength > best.signalStrength))
                best = n;
        return best;
    }
    property var _pending: null
    function connectWifi(name, psk) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would join " + name);
        const n = _network(name);
        if (!n)
            return;
        wifiFailed = "";
        _pending = n;
        if (psk)
            n.connectWithPsk(psk);
        else
            n.connect();
    }
    function disconnectWifi(name) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would leave " + name);
        const n = _network(name);
        if (n)
            n.disconnect();
    }
    function forgetWifi(name) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would forget " + name);
        const n = _network(name);
        if (n)
            n.forget();
    }
    Connections {
        target: hw._pending
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            hw.wifiFailed = hw._pending ? hw._pending.name : "";
        }
    }

    // ==================== connections (wired, VPN, hotspot): nmcli ====================
    // [{ name, uuid, type: "ethernet" | "vpn" | "wireguard" | "wifi" | ..., active, device }]
    property var connections: []
    function readConnections() {
        Env.read(["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,DEVICE", "connection", "show"], (code, out) => {
            if (code !== 0)
                return;
            hw.connections = out.trim().split("\n").filter(l => l).map(l => {
                const f = l.replace(/\\:/g, "\u0000").split(":").map(x => x.replace(/\u0000/g, ":"));
                const type = f[2].replace("802-3-ethernet", "ethernet").replace("802-11-wireless", "wifi");
                return { "name": f[0], "uuid": f[1], "type": type, "active": f[3] === "yes", "device": f[4] || "" };
            });
        });
    }
    // [{ device, type, state, connection }]
    property var netDevices: []
    function readDevices() {
        Env.read(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], (code, out) => {
            if (code !== 0)
                return;
            hw.netDevices = out.trim().split("\n").filter(l => l).map(l => {
                const f = l.split(":");
                return { "device": f[0], "type": f[1], "state": f[2], "connection": f[3] || "" };
            });
        });
    }
    function connectionUp(uuid, on) {
        Env.write(["nmcli", "connection", on ? "up" : "down", "uuid", uuid], () => Qt.callLater(hw.refreshNet));
    }
    function importVpn(file) {
        const type = file.endsWith(".conf") ? "wireguard" : "openvpn";
        Env.write(["nmcli", "connection", "import", "type", type, "file", file], () => hw.refreshNet());
    }
    function deleteConnection(uuid) {
        Env.write(["nmcli", "connection", "delete", "uuid", uuid], () => hw.refreshNet());
    }
    // details of a device: { "IP4.ADDRESS[1]": ..., "GENERAL.HWADDR": ... }
    function deviceDetails(device, done) {
        Env.read(["nmcli", "-t", "device", "show", device], (code, out) => {
            const d = {};
            for (const l of out.split("\n")) {
                const i = l.indexOf(":");
                if (i > 0)
                    d[l.slice(0, i)] = l.slice(i + 1).replace(/\\:/g, ":");
            }
            done(d);
        });
    }
    function refreshNet() {
        readConnections();
        readDevices();
    }
    // NetworkManager's own event stream: re-read on each change (debounced). Only while a page shows
    // connections (netWatch: the Network page); nothing runs for it otherwise.
    property bool netWatch: false
    onNetWatchChanged: if (netWatch) refreshNet()
    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: hw.netWatch
        stdout: SplitParser {
            onRead: netDebounce.restart()
        }
        onExited: if (hw.netWatch) nmRestart.start()
    }
    Timer {
        id: nmRestart
        interval: 2000
        onTriggered: nmMonitor.running = hw.netWatch
    }
    Timer {
        id: netDebounce
        interval: 300
        onTriggered: hw.refreshNet()
    }

    // ==================== Bluetooth ====================
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: btAdapter !== null
    readonly property bool btEnabled: !!btAdapter && btAdapter.enabled
    property bool bluetoothScan: false
    Binding {
        when: hw.bluetoothScan && hw.btEnabled
        target: hw.btAdapter
        property: "discovering"
        value: true
    }
    // [{ address, name, icon, kind, paired, connected, busy, battery }]
    property var btDevices: []
    property string _btSig: ""
    readonly property var _btList: {
        const a = btAdapter;
        if (!a || !a.enabled)
            return [];
        const out = [];
        for (const d of a.devices.values) {
            if (!d.paired && !d.deviceName)
                continue;
            out.push({
                "address": d.address,
                "name": d.name || d.address,
                "kind": _btKind(d.icon),
                "paired": d.paired,
                "connected": d.connected,
                "busy": d.pairing ? "Pairing…" : d.state === BluetoothDeviceState.Connecting ? "Connecting…" : d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : "",
                "battery": d.batteryAvailable ? Math.round(d.battery * 100) : -1
            });
        }
        const rank = d => d.connected ? 2 : d.paired ? 1 : 0;
        return out.sort((x, y) => rank(y) - rank(x) || x.name.localeCompare(y.name));
    }
    on_BtListChanged: Qt.callLater(_publishBt)
    function _publishBt() {
        const sig = JSON.stringify(_btList);
        if (sig !== _btSig) {
            _btSig = sig;
            btDevices = _btList;
        }
    }
    function _btKind(icon) {
        const i = icon || "";
        if (/headset|headphone|audio-card/.test(i)) return "headphones";
        if (/speaker/.test(i)) return "speaker";
        if (/mouse/.test(i)) return "mouse";
        if (/keyboard/.test(i)) return "keyboard";
        if (/gaming|joystick/.test(i)) return "gamepad";
        if (/phone/.test(i)) return "phone";
        if (/computer/.test(i)) return "computer";
        return "other";
    }
    function _bt(address) {
        return btAdapter ? btAdapter.devices.values.find(d => d.address === address) || null : null;
    }
    function setBluetoothEnabled(on) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would turn Bluetooth " + on);
        if (btAdapter)
            btAdapter.enabled = on;
    }
    // a saved device connects; a new one is paired, trusted, then connected
    function btConnect(address) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would connect " + address);
        const d = _bt(address);
        if (!d)
            return;
        if (d.paired) {
            d.connect();
        } else {
            _btPairing = d;
            d.pair();
        }
    }
    property var _btPairing: null
    Connections {
        target: hw._btPairing
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = hw._btPairing;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
                hw._btPairing = null;
            }
        }
    }
    function btDisconnect(address) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would disconnect " + address);
        const d = _bt(address);
        if (d)
            d.disconnect();
    }
    function btForget(address) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would forget " + address);
        const d = _bt(address);
        if (d)
            d.forget();
    }

    // ==================== mice and touchpads ====================
    // What's plugged in, so the Mouse & Touchpad page can say which device each tab is for. From udev's
    // tags: a mouse is ID_INPUT_MOUSE on USB or Bluetooth (a touchpad's companion "Mouse" node and a
    // TrackPoint aren't), a touchpad is ID_INPUT_TOUCHPAD. Read when a page asks (pointerWatch), then
    // again on each plug / unplug (udevadm monitor), never polled.
    property bool pointerWatch: false
    property var mice: []        // names
    property var touchpads: []   // names
    property bool pointersKnown: false
    function readPointers() {
        // udev's database files directly (one udevadm per device took over a second)
        const script = 'for e in /sys/class/input/event*; do d=/run/udev/data/c$(cat "$e/dev"); [ -r "$d" ] || continue; '
            + 'n=$(cat "$e/device/name"); '
            + 'if grep -q "^E:ID_INPUT_TOUCHPAD=1" "$d"; then echo "touchpad\t$n"; '
            + 'elif grep -q "^E:ID_INPUT_MOUSE=1" "$d" && ! grep -q "^E:ID_INPUT_POINTINGSTICK=1" "$d" && grep -qE "^E:ID_BUS=(usb|bluetooth)" "$d"; then echo "mouse\t$n"; fi; done';
        Env.read(["sh", "-c", script], (code, out) => {
            const m = [], t = [];
            for (const line of out.split("\n")) {
                const [kind, name] = line.split("\t");
                const clean = (name || "").trim();
                if (!clean)
                    continue;
                const list = kind === "mouse" ? m : t;
                if (list.indexOf(clean) < 0)
                    list.push(clean);
            }
            hw.mice = m;
            hw.touchpads = t;
            hw.pointersKnown = true;
        });
    }
    onPointerWatchChanged: if (pointerWatch) readPointers()
    Process {
        running: hw.pointerWatch
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=input"]
        stdout: SplitParser {
            onRead: line => {
                if (/ (add|remove) /.test(line))
                    pointerTimer.restart();
            }
        }
    }
    Timer {
        id: pointerTimer
        interval: 400
        onTriggered: hw.readPointers()
    }

    // ==================== sound ====================
    // live volumes need their nodes tracked; every node only while the Sound page is open (soundWatch),
    // otherwise just the default output and input
    property bool soundWatch: false
    PwObjectTracker {
        objects: hw.soundWatch && Pipewire.nodes ? Pipewire.nodes.values : [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(n => n)
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // [{ id, name }]: devices you can pick
    readonly property var sinks: (Pipewire.nodes ? Pipewire.nodes.values : []).filter(n => n.isSink && !n.isStream && n.audio).map(n => ({ "id": n.id, "name": n.description || n.nickname || n.name }))
    readonly property var sources: (Pipewire.nodes ? Pipewire.nodes.values : []).filter(n => !n.isSink && !n.isStream && n.audio && !/\.monitor$/.test(n.name)).map(n => ({ "id": n.id, "name": n.description || n.nickname || n.name }))
    // apps playing sound: [{ id, name, icon, volume, muted }]
    // apps playing sound, one entry per stream (a browser has one per tab or player):
    // [{ id, app, appId, icon, title, site, volume, muted }]. `title`: what's playing, from the stream's
    // media.name ("Encouragement | YouTube Music" -> title "Encouragement", site "YouTube Music"; a tab's
    // "(12) " unread count dropped); "" when the stream only has a generic name. `appId`: the app's
    // desktop id when the stream says (sandboxed apps: the portal's app id), else its program's name.
    readonly property var streams: (Pipewire.nodes ? Pipewire.nodes.values : []).filter(n => n.isStream && n.isSink && n.audio).map(n => {
        const p = n.properties;
        const app = p["application.name"] || n.description || n.name;
        const t = hw._streamTitle(p["media.name"] || "", app);
        return {
            "id": n.id,
            "app": app,
            "appId": p["pipewire.access.portal.app_id"] || p["application.id"] || p["application.process.binary"] || "",
            "icon": p["application.icon-name"] || "",
            "title": t.title,
            "site": t.site,
            "volume": hw.level(n.audio),
            "muted": n.audio.muted
        };
    })
    function _streamTitle(media, app) {
        let t = media.replace(/^\(\d+\)\s*/, "").trim();
        // a sound file played by a little player (pw-play, paplay): its name
        if (/^\/\S+\.\w{2,4}$/.test(t))
            t = t.split("/").pop().replace(/\.\w+$/, "");
        if (t === "" || t.toLowerCase() === app.toLowerCase() || /^(playback|playback stream|audio|audio stream|output|stream|simple dbus api|alsa playback)$/i.test(t))
            return { "title": "", "site": "" };
        // "Title - Site" / "Title | Site": a short last part is the site
        const m = t.match(/^(.*\S)\s+[-|\u2014\u00b7]\s+([^-|\u2014\u00b7]{2,32})$/);
        return m ? { "title": m[1], "site": m[2].trim() } : { "title": t, "site": "" };
    }
    function _node(id) {
        return (Pipewire.nodes ? Pipewire.nodes.values : []).find(n => n.id === id) || null;
    }
    function setDefaultSink(id) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would use output " + id);
        const n = _node(id);
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }
    function setDefaultSource(id) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would use input " + id);
        const n = _node(id);
        if (n)
            Pipewire.preferredDefaultAudioSource = n;
    }
    function setVolume(id, v) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would set volume " + id + " " + v);
        const n = _node(id);
        if (n && n.audio) {
            _setLevel(n.audio, v);
            if (v > 0 && n.audio.muted)
                n.audio.muted = false;
        }
    }
    function setMuted(id, m) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would mute " + id + " " + m);
        const n = _node(id);
        if (n && n.audio)
            n.audio.muted = m;
    }
    // A node's volume = its loudest channel. Pipewire's `volume` is the channels' average, and setting it
    // gives every channel the same level: the balance was computed from that average, so each move of
    // the balance slider lowered the volume a little more, down to 0, and changing the volume erased the
    // balance. Read the loudest channel; change the volume by scaling the channels (keeps the balance).
    // The island's Sys does the same.
    function level(a) {
        const vs = a ? a.volumes || [] : [];
        return vs.length ? Math.max(...vs) : a ? a.volume : 0;
    }
    function _setLevel(a, v) {
        const vs = a.volumes || [];
        const top = vs.length ? Math.max(...vs) : 0;
        if (vs.length > 1 && top > 0)
            a.volumes = vs.map(c => c * v / top);
        else
            a.volume = v;
    }
    // left / right balance -1..1 from the channel volumes
    readonly property real balance: {
        if (!sink || !sink.audio || sink.audio.volumes.length !== 2)
            return 0;
        const l = sink.audio.volumes[0], r = sink.audio.volumes[1];
        const m = Math.max(l, r);
        return m === 0 ? 0 : (r - l) / m;
    }
    function setBalance(b) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would set balance " + b);
        if (!sink || !sink.audio || sink.audio.volumes.length !== 2)
            return;
        // the louder side keeps the volume, the other one is turned down
        const v = level(sink.audio);
        if (v > 0)
            sink.audio.volumes = [v * Math.max(0, Math.min(1, 1 - b)), v * Math.max(0, Math.min(1, 1 + b))];
    }

    // ==================== battery and power ====================
    readonly property var battery: {
        const d = UPower.displayDevice;
        const ready = d && d.ready && d.isLaptopBattery;
        return {
            "present": !!ready,
            "percent": ready ? Math.round(d.percentage * 100) : 0,
            "charging": ready && (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged || d.state === UPowerDeviceState.PendingCharge),
            "full": ready && d.state === UPowerDeviceState.FullyCharged,
            "timeToFull": ready ? d.timeToFull : 0,
            "timeToEmpty": ready ? d.timeToEmpty : 0,
            "health": ready && d.healthSupported ? Math.round(d.healthPercentage) : -1
        };
    }
    readonly property bool onBattery: UPower.onBattery
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property bool performanceAvailable: PowerProfiles.hasPerformanceProfile
    function setProfile(p) {
        if (Env.sandboxed)
            return console.warn("SANDBOX would set power mode " + p);
        PowerProfiles.profile = p === "saver" ? PowerProfile.PowerSaver : p === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }

    
}
