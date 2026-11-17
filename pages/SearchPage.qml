import QtQuick
import "../theme"
import "../services"
import "../components"

// Search: the island's launcher. What it shows (apps always; calculations, files, settings and the web
// each always, after a prefix, or never: the island's search.<kind>.mode), the web search engine, files.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Island.revision
    readonly property var engines: [
        { "value": "Google", "label": "Google", "url": "https://www.google.com/search?q={query}" },
        { "value": "DuckDuckGo", "label": "DuckDuckGo", "url": "https://duckduckgo.com/?q={query}" },
        { "value": "Brave", "label": "Brave Search", "url": "https://search.brave.com/search?q={query}" },
        { "value": "Startpage", "label": "Startpage", "url": "https://www.startpage.com/do/search?q={query}" },
        { "value": "Ecosia", "label": "Ecosia", "url": "https://www.ecosia.org/search?q={query}" },
        { "value": "Bing", "label": "Bing", "url": "https://www.bing.com/search?q={query}" }
    ]
    readonly property var searchBind: {
        Niri.revision;
        const b = Niri.binds();
        for (const k in b) {
            const a = b[k].action;
            if (a && a.name === "spawn" && a.args.join(" ").indexOf("toggle search") >= 0)
                return k;
        }
        return "";
    }

    // what the launcher looks like, with the shortcut on its caps
    Rectangle {
        width: parent.width
        height: Math.max(Theme.spacing * 30, launcherColumn.height + Theme.spacing * 12)
        radius: Theme.card.radius
        color: Theme.c.surface
        border.width: Theme.cardBorder
        border.color: Theme.c.border
        Column {
            id: launcherColumn
            anchors.centerIn: parent
            spacing: Theme.spacing * 3
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(360, launcherRow.width + 32)
                height: Theme.grow(44, 14)
                radius: height / 2
                color: "#000000"
                Row {
                    id: launcherRow
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Icon {
                        name: "search"
                        size: 18
                        color: "#98989f"
                    }
                    Label {
                        text: "Apps, files, calculations, the web…"
                        color: "#98989f"
                    }
                }
            }
            Row {
                visible: page.searchBind !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing * 2
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open it with"
                    color: Theme.c.muted
                }
                Kbd {
                    keys: page.searchBind.replace("Mod", "Super").split("+")
                }
            }
        }
    }

    // ---- what it shows ----
    function mode(kind) {
        return (page.rev, Island.value("search." + kind + ".mode", kind === "files" ? "prefix" : "always"));
    }
    function prefix(kind) {
        const p = (page.rev, Island.value("search." + kind + ".prefixes", []));
        return p.length ? p[0] : "";
    }
    readonly property var modes: [{ "value": "always", "label": "Always" }, { "value": "prefix", "label": "With a prefix" }, { "value": "off", "label": "Off" }]
    // the explanation follows the choice, with the real prefix in it
    readonly property var kinds: [
        { "id": "calc", "title": "Calculations",
          "always": p => "Type a calculation, like 12*4, and the answer comes first. Start with " + p + " to see only the answer.",
          "prefix": p => "Start with " + p + " to calculate, like " + p + "12*4.",
          "off": p => "Calculations don't show." },
        { "id": "files", "title": "Files and folders",
          "always": p => "The best matching files show among the other results. Start with " + p + " to see all of them.",
          "prefix": p => "Start with " + p + " to look for files, so the usual results stay short.",
          "off": p => "Files don't show." },
        { "id": "settings", "title": "Settings",
          "always": p => "Settings like “Night light” show among the other results, and open here. Start with " + p + " to see only settings.",
          "prefix": p => "Start with " + p + " to look for a setting, like " + p + "night light.",
          "off": p => "Settings don't show." },
        { "id": "web", "title": "The web",
          "always": p => "The last result is always a web search for what you typed. Start with " + p + " to see only that.",
          "prefix": p => "Start with " + p + " to search the web.",
          "off": p => "The search doesn't go to the web." }
    ]
    SettingsGroup {
        width: parent.width
        title: "What the search shows"
        description: "Apps, the island's panels and commands always show. The rest can be mixed in, shown only after a short prefix, or left out: a quiet launcher, or one that finds everything."
        Repeater {
            model: page.kinds
            SettingsRow {
                required property var modelData
                title: modelData.title
                description: modelData[page.mode(modelData.id)](page.prefix(modelData.id))
                Tabs {
                    options: page.modes
                    value: page.mode(modelData.id)
                    onActivated: v => Island.set("search." + modelData.id + ".mode", v)
                }
            }
        }
    }

    // ---- prefixes: editable, checked as you type ----
    function prefixes(kind) {
        return (page.rev, Island.value("search." + kind + ".prefixes", []));
    }
    function parsePrefixes(text) {
        const out = [];
        for (const p of text.split(/[\s,]+/))
            if (p !== "" && out.indexOf(p) < 0)
                out.push(p);
        return out;
    }
    // what's wrong with what's typed ("" = fine)
    function prefixProblem(kind, text) {
        const list = parsePrefixes(text);
        if (!list.length)
            return "Add at least one, or turn this off above.";
        for (const p of list) {
            if (/^[A-Za-z0-9\u00C0-\u024F]+$/.test(p))
                return "“" + p + "” is only letters: every search starting with it would switch here. Add a sign, like " + p + ":";
            for (const k of page.kinds)
                if (k.id !== kind && page.mode(k.id) !== "off" && page.prefixes(k.id).some(o => o.toLowerCase() === p.toLowerCase()))
                    return "“" + p + "” is already used for " + k.title.toLowerCase() + ".";
        }
        return "";
    }
    function savePrefixes(kind, text) {
        const list = parsePrefixes(text);
        if (prefixProblem(kind, text) === "" && JSON.stringify(list) !== JSON.stringify(prefixes(kind)))
            Island.set("search." + kind + ".prefixes", list);
    }
    SettingsGroup {
        width: parent.width
        title: "Prefixes"
        description: "Type one of these at the start of a search to look in one place only. Several are fine: separate them with spaces."
        Repeater {
            model: page.kinds
            SettingsRow {
                required property var modelData
                visible: page.mode(modelData.id) !== "off"
                title: modelData.title
                TextField {
                    id: prefixField
                    width: Math.round(220 * Math.max(1, Theme.textScale))
                    text: page.prefixes(modelData.id).join(" ")
                    errorMessage: page.prefixProblem(modelData.id, text)
                    onAccepted: page.savePrefixes(modelData.id, text)
                    // leaving the field saves it too
                    Connections {
                        target: prefixField.input
                        function onActiveFocusChanged() {
                            if (!prefixField.input.activeFocus)
                                page.savePrefixes(modelData.id, prefixField.text);
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        visible: page.mode("web") !== "off"
        width: parent.width
        title: "Web"
        SettingsRow {
            title: "Search engine"
            Select {
                width: Math.round(200 * Math.max(1, Theme.textScale))
                options: page.engines
                value: (page.rev, Island.value("search.web.engine", "Google"))
                onActivated: v => {
                    const e = page.engines.find(x => x.value === v);
                    Island.set("search.web.engine", v);
                    Island.set("search.web.url", e.url);
                }
            }
        }
    }

    SettingsGroup {
        visible: page.mode("files") !== "off"
        width: parent.width
        title: "Files"
        SettingsRow {
            title: "Look for files in"
            description: "The folders searched when you look for a file."
            TextField {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                iconName: "folder-fill"
                text: (page.rev, Island.value("search.files.root", "~"))
                onAccepted: Island.set("search.files.root", text)
            }
        }
        SettingsRow {
            title: "Include hidden files"
            description: "Also find files whose names start with a dot. These are usually settings files that apps keep for themselves."
            Switch {
                checked: (page.rev, Island.value("search.files.showHidden", false))
                onToggled: Island.set("search.files.showHidden", checked)
            }
        }
    }
}
