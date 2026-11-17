import QtQuick
import Quickshell.Wayland
import "../theme"

// One action's keyboard shortcuts, edited by pressing them. Shows each shortcut as key caps (click one to
// change it, × to remove it), "Set shortcut" when there's none, and + to add another. While it listens,
// the window asks the compositor to pass every key to it (keyboard-shortcuts-inhibit), so even a
// combination that's already in use reaches us instead of running. Escape cancels.
// `conflict(key)` (from the page) names what a key already does ("" = free): a taken key asks first.
// Emits assign(oldKey, newKey) (oldKey "" = a new one) and remove(key). Keys are niri's names
// ("Mod+Shift+T", "XF86AudioRaiseVolume"); Mod is the Super key.
Item {
    id: field

    property var keys: []
    property var conflict: k => ""
    property var window: null
    signal assign(string oldKey, string newKey)
    signal remove(string key)

    // "" idle; "listen": waiting for keys; "confirm": the key is taken, ask
    property string mode: ""
    property string replacing: ""     // the key being changed ("" = adding)
    property string pending: ""       // the key pressed, waiting for confirmation
    property string held: ""          // modifiers held right now, shown while listening

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, Theme.kbd.height + 8)

    function start(oldKey) {
        replacing = oldKey;
        pending = "";
        held = "";
        mode = "listen";
        catcher.forceActiveFocus();
    }
    function stop() {
        mode = "";
        held = "";
    }

    // true while the compositor really hands us every key
    readonly property bool grabbing: inhibitor.active
    ShortcutInhibitor {
        id: inhibitor
        window: field.window
        enabled: field.mode === "listen" && field.window !== null
    }

    // ---- key names: Qt's key events -> niri's key names ----
    readonly property var named: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Space]: "Space", [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause", [Qt.Key_Menu]: "Menu",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MicMute]: "XF86AudioMicMute",
        [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
        [Qt.Key_MediaPause]: "XF86AudioPause", [Qt.Key_MediaStop]: "XF86AudioStop",
        [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_Calculator]: "XF86Calculator", [Qt.Key_Search]: "XF86Search", [Qt.Key_Explorer]: "XF86Explorer",
        [Qt.Key_HomePage]: "XF86HomePage", [Qt.Key_LaunchMail]: "XF86Mail", [Qt.Key_Launch0]: "XF86Launch0"
    })
    // keys that type a different character with Shift held: named by where they are (X keycodes,
    // evdev + 8), so Super+Shift+1 stays "1" rather than "exclam"
    readonly property var byPlace: ({
        10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
        20: "Minus", 21: "Equal", 34: "BracketLeft", 35: "BracketRight", 47: "Semicolon", 48: "Apostrophe",
        49: "Grave", 51: "Backslash", 59: "Comma", 60: "Period", 61: "Slash"
    })
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock, Qt.Key_NumLock]
    function mods(m) {
        const out = [];
        if (m & Qt.MetaModifier)
            out.push("Mod");
        if (m & Qt.ControlModifier)
            out.push("Ctrl");
        if (m & Qt.AltModifier)
            out.push("Alt");
        if (m & Qt.ShiftModifier)
            out.push("Shift");
        return out;
    }
    function keyName(e) {
        if (e.key in named)
            return named[e.key];
        if (e.nativeScanCode in byPlace)
            return byPlace[e.nativeScanCode];
        if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F35)
            return "F" + (e.key - Qt.Key_F1 + 1);
        if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z)
            return String.fromCharCode(e.key);
        if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9)
            return String.fromCharCode(e.key);
        return "";
    }

    Item {
        id: catcher
        focus: field.mode === "listen"
        Keys.onPressed: e => {
            e.accepted = true;
            if (field.modifierKeys.indexOf(e.key) >= 0) {
                field.held = field.mods(e.modifiers).join("+");
                return;
            }
            if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) {
                field.stop();
                return;
            }
            const k = field.keyName(e);
            if (k === "")
                return;
            const combo = field.mods(e.modifiers).concat([k]).join("+");
            if (field.conflict(combo) !== "" && combo.toLowerCase() !== field.replacing.toLowerCase()) {
                field.pending = combo;
                field.mode = "confirm";
                return;
            }
            field.stop();
            if (combo.toLowerCase() !== field.replacing.toLowerCase())
                field.assign(field.replacing, combo);
        }
        Keys.onReleased: e => {
            if (field.mode === "listen")
                field.held = field.mods(e.modifiers & ~(e.key === Qt.Key_Shift ? Qt.ShiftModifier : e.key === Qt.Key_Control ? Qt.ControlModifier : e.key === Qt.Key_Alt ? Qt.AltModifier : (e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) ? Qt.MetaModifier : 0)).join("+");
        }
        onActiveFocusChanged: if (!activeFocus && field.mode === "listen") field.stop()
    }

    Row {
        id: row
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing * 2
        layoutDirection: Qt.RightToLeft

        // + another shortcut / set the first one
        Button {
            visible: field.mode === ""
            anchors.verticalCenter: parent.verticalCenter
            size: "sm"
            variant: "ghost"
            iconName: field.keys.length ? "add" : ""
            text: field.keys.length ? "" : "Set shortcut"
            onClicked: field.start("")
        }

        // listening
        Rectangle {
            visible: field.mode === "listen"
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.kbd.height + 8
            width: listenRow.implicitWidth + 2 * Theme.spacing * 3
            radius: height / 2
            color: Theme.c.accentSoft
            border.width: 1.5
            border.color: Theme.c.accent
            Row {
                id: listenRow
                anchors.centerIn: parent
                spacing: Theme.spacing * 2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.c.accent
                    SequentialAnimation on opacity {
                        running: field.mode === "listen" && !Theme.reduceMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: Theme.dur(600); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Theme.dur(600); easing.type: Easing.InOutSine }
                    }
                }
                Kbd {
                    visible: field.held !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    keys: field.labels(field.held + "+…")
                }
                Label {
                    visible: field.held === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Press the keys…"
                    color: Theme.c.accent
                    weight: Theme.weightMedium
                }
            }
        }
        Button {
            visible: field.mode === "listen"
            anchors.verticalCenter: parent.verticalCenter
            size: "sm"
            variant: "ghost"
            text: "Cancel"
            onClicked: field.stop()
        }

        // the key is taken: ask
        Button {
            visible: field.mode === "confirm"
            anchors.verticalCenter: parent.verticalCenter
            size: "sm"
            text: "Use it here"
            onClicked: {
                const k = field.pending;
                field.stop();
                field.assign(field.replacing, k);
            }
        }
        Button {
            visible: field.mode === "confirm"
            anchors.verticalCenter: parent.verticalCenter
            size: "sm"
            variant: "ghost"
            text: "Cancel"
            onClicked: field.stop()
        }
        Label {
            visible: field.mode === "confirm"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            text: field.mode === "confirm" ? field.labels(field.pending).join(" + ") + " already " + field.conflict(field.pending) + "." : ""
            color: Theme.c.warning
            wrapMode: Text.Wrap
        }

        // the shortcuts
        Repeater {
            model: field.mode === "" ? field.keys : []
            Rectangle {
                id: chip
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.kbd.height + 8
                width: chipRow.implicitWidth + Theme.spacing * 2 + (hover.hovered ? 0 : 0)
                radius: Theme.radius.md
                color: hover.hovered ? Theme.c.surfaceHover : "transparent"
                HoverHandler {
                    id: hover
                }
                Row {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.spacing
                    spacing: Theme.spacing
                    Kbd {
                        anchors.verticalCenter: parent.verticalCenter
                        keys: field.labels(chip.modelData)
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: field.start(chip.modelData)
                        }
                    }
                    CloseButton {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: hover.hovered ? 1 : 0.45
                        onClicked: field.remove(chip.modelData)
                    }
                }
            }
        }
    }

    // ---- key caps: niri's names -> what's printed on the keys ----
    readonly property var printed: ({
        "mod": "Super", "super": "Super", "ctrl": "Ctrl", "control": "Ctrl", "alt": "Alt", "shift": "Shift",
        "return": "Enter", "kp_enter": "Enter", "backspace": "Backspace", "page_up": "Page Up", "page_down": "Page Down",
        "print": "Print Screen", "space": "Space", "escape": "Esc", "delete": "Delete", "insert": "Insert",
        "minus": "-", "equal": "=", "comma": ",", "period": ".", "slash": "/", "backslash": "\\",
        "bracketleft": "[", "bracketright": "]", "semicolon": ";", "apostrophe": "'", "grave": "`",
        "xf86audioraisevolume": "Volume Up", "xf86audiolowervolume": "Volume Down", "xf86audiomute": "Mute",
        "xf86audiomicmute": "Mic Mute", "xf86audioplay": "Play", "xf86audiopause": "Pause",
        "xf86audiostop": "Stop", "xf86audionext": "Next Track", "xf86audioprev": "Previous Track",
        "xf86monbrightnessup": "Brightness Up", "xf86monbrightnessdown": "Brightness Down",
        "wheelscrollup": "Scroll Up", "wheelscrolldown": "Scroll Down", "wheelscrollleft": "Scroll Left",
        "wheelscrollright": "Scroll Right", "touchpadscrollup": "Swipe Up", "touchpadscrolldown": "Swipe Down"
    })
    function labels(key) {
        return key.split("+").map(p => printed[p.toLowerCase()] || (p.length === 1 ? p.toUpperCase() : p.replace(/^XF86/, "")));
    }
}
