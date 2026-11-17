import QtQuick
import Quickshell.Io
import "../theme"
import "../services"
import "../components"

// Privacy & Security: the screen lock (set up in Power), location, file history, the trash, and
// fingerprints: enrolling shows each touch as a dot filling in, live from fprintd.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property var ages: [{ "value": 1, "label": "1 day" }, { "value": 7, "label": "7 days" }, { "value": 30, "label": "30 days" }]

    Banner {
        tone: "default"
        iconName: "lock-fill"
        title: "Screen lock"
        description: "When the screen turns off and locks is chosen on the Power page."
        actionText: "Open Power"
        onAction: Nav.go("power")
    }

    SettingsGroup {
        width: parent.width
        title: "Location"
        SettingsRow {
            title: "Location services"
            description: "Lets apps (weather, maps, the night light) know roughly where you are."
            iconName: "location_on-fill"
            Switch {
                checked: Desktop.get("location", "enabled", false)
                onToggled: Desktop.set("location", "enabled", checked)
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "File history"
        SettingsRow {
            title: "Remember recent files"
            description: "Apps can show a list of the files you opened lately, so you can get back to them quickly."
            iconName: "history"
            Switch {
                checked: Desktop.get("privacy", "remember-recent-files", true)
                onToggled: Desktop.set("privacy", "remember-recent-files", checked)
            }
        }
        SettingsRow {
            visible: Desktop.get("privacy", "remember-recent-files", true)
            title: "Keep them for"
            description: "How long a file stays in the list after you last opened it."
            Select {
                width: Math.round(160 * Math.max(1, Theme.textScale))
                options: [{ "value": -1, "label": "Forever" }].concat(page.ages)
                value: Desktop.get("privacy", "recent-files-max-age", -1)
                onActivated: v => Desktop.set("privacy", "recent-files-max-age", v)
            }
        }
        SettingsRow {
            title: "Clear history"
            description: "Empties the list of recent files now. The files themselves aren't deleted."
            Button {
                size: "sm"
                variant: "danger-soft"
                text: "Clear"
                onClicked: Env.write(["rm", "-f", Env.home + "/.local/share/recently-used.xbel"])
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Trash and temporary files"
        SettingsRow {
            title: "Empty the trash automatically"
            description: "Permanently deletes files that have been in the trash for a while."
            iconName: "auto_delete-fill"
            Switch {
                checked: Desktop.get("privacy", "remove-old-trash-files", false)
                onToggled: Desktop.set("privacy", "remove-old-trash-files", checked)
            }
        }
        SettingsRow {
            title: "Delete temporary files automatically"
            description: "Cleans up leftover files that apps no longer need."
            Switch {
                checked: Desktop.get("privacy", "remove-old-temp-files", false)
                onToggled: Desktop.set("privacy", "remove-old-temp-files", checked)
            }
        }
        SettingsRow {
            visible: Desktop.get("privacy", "remove-old-trash-files", false) || Desktop.get("privacy", "remove-old-temp-files", false)
            title: "After"
            Select {
                width: Math.round(160 * Math.max(1, Theme.textScale))
                options: page.ages
                value: Desktop.get("privacy", "old-files-age", 30)
                onActivated: v => Desktop.set("privacy", "old-files-age", v)
            }
        }
    }

    // ---- fingerprints ----
    property var fingers: []
    property bool hasReader: false
    function readFingers() {
        Env.readFor(page, ["fprintd-list", Host.user], (code, out) => {
            page.hasReader = code === 0 && !/No devices available/.test(out);
            page.fingers = (out.match(/ - #\d+: (\S+)/g) || []).map(l => l.replace(/ - #\d+: /, ""));
        });
    }
    Component.onCompleted: readFingers()
    readonly property var fingerNames: ({ "right-index-finger": "Right index", "left-index-finger": "Left index", "right-thumb": "Right thumb", "left-thumb": "Left thumb", "right-middle-finger": "Right middle", "left-middle-finger": "Left middle" })
    property int stages: 0
    property string enrollState: ""   // "", "touch", "done", "failed"
    Process {
        id: enroll
        property string finger: "right-index-finger"
        command: ["fprintd-enroll", "-f", finger]
        stdout: SplitParser {
            onRead: line => {
                if (/enroll-stage-passed/.test(line))
                    page.stages++;
                else if (/enroll-completed/.test(line))
                    page.enrollState = "done";
                else if (/enroll-(failed|data-full|disconnected|unknown-error)/.test(line))
                    page.enrollState = "failed";
            }
        }
        onExited: {
            if (page.enrollState === "touch")
                page.enrollState = "failed";
            page.readFingers();
        }
    }
    function startEnroll() {
        const free = Object.keys(fingerNames).find(f => fingers.indexOf(f) < 0) || "right-index-finger";
        if (Env.sandboxed)
            return console.warn("SANDBOX would enroll " + free);
        enroll.finger = free;
        stages = 0;
        enrollState = "touch";
        enroll.running = true;
    }
    SettingsGroup {
        visible: page.hasReader
        width: parent.width
        title: "Fingerprints"
        description: "Unlock the computer and confirm actions with a touch instead of typing your password."
        Repeater {
            model: page.fingers
            SettingsRow {
                required property string modelData
                title: page.fingerNames[modelData] || modelData
                iconName: "fingerprint"
            }
        }
        // live enrolment
        SettingsRow {
            visible: page.enrollState !== ""
            wide: true
            title: page.enrollState === "done" ? "Added" : page.enrollState === "failed" ? "That didn't work, try again" : "Touch the sensor, lift, repeat"
            Row {
                spacing: Theme.spacing * 2
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        width: 18
                        height: 18
                        radius: 9
                        color: index < page.stages ? Theme.c.accent : Theme.c.default
                        scale: index === page.stages - 1 ? 1.15 : 1
                        Behavior on color {
                            ColorAnimation { duration: Theme.motion.slow }
                        }
                        Behavior on scale {
                            Spring {}
                        }
                    }
                }
            }
        }
        SettingsRow {
            title: page.fingers.length ? "Add another finger" : "Add a fingerprint"
            Row {
                spacing: Theme.spacing * 2
                Button {
                    visible: page.fingers.length > 0
                    size: "sm"
                    variant: "ghost"
                    text: "Remove all"
                    onClicked: Env.write(["fprintd-delete", Host.user], () => page.readFingers())
                }
                Button {
                    size: "sm"
                    variant: "secondary"
                    iconName: "fingerprint"
                    text: enroll.running ? "Touch the sensor…" : "Add"
                    pending: enroll.running
                    onClicked: page.startEnroll()
                }
            }
        }
    }
}
