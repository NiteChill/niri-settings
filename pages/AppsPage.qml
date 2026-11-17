import QtQuick
import "../theme"
import "../services"
import "../components"

// Apps: which app opens what (with their icons), apps that start when you log in, and per-app window
// rules (how an app's windows open, see-through, hidden from screen sharing), written as niri window rules.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Niri.revision

    SettingsGroup {
        width: parent.width
        title: "Default apps"
        description: "Which app opens each kind of file or link."
        Missing {
            needs: ["xdgutils"]
            what: "Choosing default apps"
        }
        Repeater {
            model: [["web", "Web", "public"], ["mail", "Mail", "article-fill"], ["calendar", "Calendar", "calendar_month-fill"], ["music", "Music", "music_note"], ["video", "Video", "play_arrow-fill"], ["photos", "Photos", "image-fill"], ["files", "Files", "folder-fill"], ["text", "Text", "text_fields"], ["pdf", "PDF documents", "article-fill"]]
            SettingsRow {
                required property var modelData
                visible: Deps.has("xdgutils")
                title: modelData[1]
                iconName: modelData[2]
                Select {
                    width: Math.round(240 * Math.max(1, Theme.textScale))
                    readonly property var choices: Host.appsFor(modelData[0])
                    options: choices.map(a => ({ "value": a.id, "label": a.name }))
                    placeholder: choices.length ? "Pick an app" : "No app installed"
                    value: Host.defaults[modelData[0]] || ""
                    onActivated: v => Host.setDefault(modelData[0], v)
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Startup apps"
        description: "Apps that open by themselves when you log in."
        Repeater {
            model: Host.startup
            SettingsRow {
                required property var modelData
                title: modelData.name
                appIcon: modelData.icon || modelData.name.toLowerCase()
                Row {
                    spacing: Theme.spacing * 2
                    Button {
                        size: "sm"
                        variant: "ghost"
                        iconName: "delete-fill"
                        onClicked: Host.removeStartup(modelData.file)
                    }
                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: modelData.enabled
                        onToggled: Host.setStartupEnabled(modelData.file, checked)
                    }
                }
            }
        }
        SettingsRow {
            title: "Add an app"
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                placeholder: "Choose…"
                options: Host.apps.filter(a => !Host.startup.some(s => s.id === a.id)).map(a => ({ "value": a.id, "label": a.name }))
                onActivated: v => Host.addStartup(v)
            }
        }
    }

    // ---- window rules ----
    readonly property var rules: (rev, Niri.ownNodes(n => n.name === "window-rule" && (n.children || []).some(c => c.name === "match" && c.props["app-id"])))
    function ruleApp(r) {
        const m = r.children.find(c => c.name === "match");
        return String(m.props["app-id"]).replace(/^\^/, "").replace(/\$$/, "").replace(/\\\./g, ".");
    }
    function ruleValue(r, name, def) {
        const c = r.children.find(c => c.name === name);
        return c ? c.args[0] : def;
    }
    function saveRule(appId, values) {
        const kids = [Kdl.node("match", [], { "app-id": "^" + appId.replace(/\./g, "\\.") + "$" })];
        if (values.open === "maximized") kids.push(Kdl.node("open-maximized", [true]));
        if (values.open === "fullscreen") kids.push(Kdl.node("open-fullscreen", [true]));
        if (values.open === "floating") kids.push(Kdl.node("open-floating", [true]));
        if (values.opacity < 1) kids.push(Kdl.node("opacity", [values.opacity]));
        if (values.hide) kids.push(Kdl.node("block-out-from", ["screencast"]));
        Niri.replaceNodes(n => n.name === "window-rule" && (n.children || []).some(c => c.name === "match" && c.props["app-id"] && page.ruleApp(n) === appId), values.remove ? [] : [Kdl.node("window-rule", [], {}, kids)]);
    }
    function ruleValues(r) {
        return {
            "open": ruleValue(r, "open-maximized", false) ? "maximized" : ruleValue(r, "open-fullscreen", false) ? "fullscreen" : ruleValue(r, "open-floating", false) ? "floating" : "normal",
            "opacity": ruleValue(r, "opacity", 1),
            "hide": ruleValue(r, "block-out-from", "") === "screencast"
        };
    }
    function appByRule(id) {
        return Host.apps.find(a => a.id.replace(/\.desktop$/, "").toLowerCase() === id.toLowerCase()) || null;
    }
    SettingsGroup {
        width: parent.width
        title: "App rules"
        description: "Choose how a particular app's windows open, for example always full screen or slightly see-through."
        // keyed by app, updated in place: every change rewrites the rules, and rebuilding the rows each
        // time destroyed the opacity slider while it was being dragged
        Repeater {
            model: KeyedModel {
                values: page.rules.map(r => ({ "appId": page.ruleApp(r) }))
                key: "appId"
            }
            Item {
                id: rule
                required property var model
                readonly property string appId: model.appId
                readonly property var modelData: page.rules.find(r => page.ruleApp(r) === appId) || null
                readonly property var app: page.appByRule(appId)
                readonly property var v: modelData ? page.ruleValues(modelData) : ({ "open": "normal", "opacity": 1, "hide": false })
                width: parent.width
                height: col.height
                Column {
                    id: col
                    width: parent.width
                    SettingsRow {
                        title: rule.app ? rule.app.name : rule.appId
                        appIcon: rule.app ? rule.app.icon : rule.appId
                        description: [rule.v.open !== "normal" ? ({ "maximized": "Opens maximised", "fullscreen": "Opens full screen", "floating": "Opens floating" })[rule.v.open] : "", rule.v.opacity < 1 ? Math.round(rule.v.opacity * 100) + " % opaque" : "", rule.v.hide ? "Hidden when sharing" : ""].filter(x => x).join(" · ") || "No changes yet"
                        Button {
                            size: "sm"
                            variant: "ghost"
                            text: "Remove"
                            onClicked: page.saveRule(rule.appId, { "remove": true })
                        }
                    }
                    SettingsRow {
                        title: "Opens"
                        description: "How this app's windows appear when they open."
                        Tabs {
                            options: [{ "value": "normal", "label": "Normal" }, { "value": "maximized", "label": "Maximised" }, { "value": "fullscreen", "label": "Full screen" }, { "value": "floating", "label": "Floating" }]
                            value: rule.v.open
                            onActivated: x => page.saveRule(rule.appId, Object.assign({}, rule.v, { "open": x }))
                        }
                    }
                    SettingsRow {
                        wide: true
                        title: "Opacity"
                        description: "Lower lets you see a little of what's behind its windows."
                        Slider {
                            width: parent.width
                            from: 0.5
                            to: 1
                            stepSize: 0.05
                            value: rule.v.opacity
                            format: x => Math.round(x * 100) + " %"
                            onMoved: page.saveRule(rule.appId, Object.assign({}, rule.v, { "opacity": Math.round(value * 100) / 100 }))
                        }
                    }
                    SettingsRow {
                        title: "Hide when sharing the screen"
                        description: "People watching a screen share or a recording see a black box instead of this app. Useful for password managers and private chats."
                        Switch {
                            checked: rule.v.hide
                            onToggled: page.saveRule(rule.appId, Object.assign({}, rule.v, { "hide": checked }))
                        }
                    }
                }
            }
        }
        SettingsRow {
            title: "Add a rule"
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                placeholder: "Choose an app…"
                options: Host.apps.filter(a => !page.rules.some(r => page.ruleApp(r).toLowerCase() === a.id.replace(/\.desktop$/, "").toLowerCase())).map(a => ({ "value": a.id.replace(/\.desktop$/, ""), "label": a.name }))
                onActivated: v => page.saveRule(v, { "open": "normal", "opacity": 1, "hide": false })
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "Screenshots"
        SettingsRow {
            id: shotsRow
            title: "Save screenshots in"
            description: "The folder where new screenshots go."
            readonly property string spec: (page.rev, Niri.arg("screenshot-path", "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"))
            TextField {
                width: Math.round(300 * Math.max(1, Theme.textScale))
                iconName: "folder-fill"
                text: shotsRow.spec ? shotsRow.spec.substring(0, shotsRow.spec.lastIndexOf("/")) : ""
                onAccepted: {
                    const spec = shotsRow.spec || "";
                    Niri.set("screenshot-path", [text.replace(/\/$/, "") + spec.substring(spec.lastIndexOf("/"))]);
                }
            }
        }
    }
}
