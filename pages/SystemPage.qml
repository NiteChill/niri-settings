import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Widgets
import "../theme"
import "../services"
import "../components"

// System: About (the machine's name, editable, and what's inside), Date & Time (a live clock, automatic
// time, the time zone, 24-hour), Region (language and formats, with a live sample of each), Users (your
// name and picture).
Column {
    id: page
    spacing: Theme.spacing * 8

    property string tab: "about"
    property date now: new Date()
    Timer {
        interval: 1000
        running: page.tab === "time"
        repeat: true
        triggeredOnStart: true
        onTriggered: page.now = new Date()
    }

    Tabs {
        anchors.horizontalCenter: parent.horizontalCenter
        options: [{ "value": "about", "label": "About" }, { "value": "time", "label": "Date & Time" }, { "value": "region", "label": "Region" }, { "value": "users", "label": "Users" }]
        value: page.tab
        onActivated: v => {
            page.tab = v;
            if (v === "time")
                Host.loadTimezones();
            if (v === "region")
                Host.loadLocales();
        }
    }

    // ---- about ----
    Column {
        visible: page.tab === "about"
        width: parent.width
        spacing: Theme.spacing * 8
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing * 3
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                source: Host.about.logo ? Quickshell.iconPath(Host.about.logo, true) : ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectFit
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Host.about.os || ""
                size: "xl"
                weight: Theme.weightSemibold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Host.about.model || ""
                color: Theme.c.muted
            }
        }
        SettingsGroup {
            width: parent.width
            Missing {
                needs: ["timedate"]
                what: "Renaming this computer"
            }
            SettingsRow {
                visible: Deps.has("timedate")
                title: "Device name"
                description: "How this computer appears to others (Bluetooth, the network)."
                TextField {
                    width: Math.round(240 * Math.max(1, Theme.textScale))
                    text: Host.prettyName || Host.hostname
                    onAccepted: Host.setPrettyName(text)
                }
            }
        }
        SettingsGroup {
            width: parent.width
            title: "Inside"
            Repeater {
                model: [["Processor", (Host.about.cpu || "") + (Host.about.cores ? " · " + Host.about.cores + " threads" : "")], ["Memory", Host.about.memory ? Host.about.memory + " GB" : ""], ["Graphics", Host.about.gpu || ""], ["Disk", Host.about.disk ? Host.about.disk + " GB" : ""], ["Kernel", Host.about.kernel || ""], ["Compositor", Host.about.niri || ""], ["Shell", Host.about.quickshell || ""]]
                SettingsRow {
                    required property var modelData
                    visible: modelData[1] !== ""
                    title: modelData[0]
                    Label {
                        width: Math.min(implicitWidth, page.width * 0.55)
                        horizontalAlignment: Text.AlignRight
                        text: modelData[1]
                        color: Theme.c.muted
                        elide: Text.ElideRight
                    }
                }
            }
        }
        SettingsGroup {
            width: parent.width
            SettingsRow {
                title: "Software updates"
                description: "System, apps and firmware."
                iconName: "update"
                Button {
                    size: "sm"
                    variant: "secondary"
                    text: "Open Software"
                    onClicked: Env.launch(["gnome-software", "--mode=updates"])
                }
            }
        }
    }

    // ---- date and time ----
    Column {
        visible: page.tab === "time"
        width: parent.width
        spacing: Theme.spacing * 8
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing
            readonly property bool h24: Desktop.get("interface", "clock-format", "24h") !== "12h"
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(page.now, parent.h24 ? "HH:mm" : "h:mm")
                font.pixelSize: Theme.px(64)
                weight: Theme.weightSemibold
                font.features: { "tnum": 1 }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(page.now, "dddd d MMMM yyyy") + " · " + Host.timezone.replace(/_/g, " ")
                color: Theme.c.muted
            }
        }
        SettingsGroup {
            width: parent.width
            Missing {
                needs: ["timedate"]
                what: "Setting the time and time zone"
            }
            SettingsRow {
                visible: Deps.has("timedate")
                title: "Set the time automatically"
                description: "Keeps the clock right using the internet."
                enabled: Host.ntpAvailable
                Switch {
                    checked: Host.ntp
                    onToggled: Host.setNtp(checked)
                }
            }
            SettingsRow {
                visible: Deps.has("timedate")
                wide: true
                title: "Time zone"
                Column {
                    width: parent.width
                    spacing: Theme.spacing * 2
                    SearchField {
                        id: tzSearch
                        width: parent.width
                        placeholder: "Search a city"
                    }
                    Select {
                        width: parent.width
                        readonly property string q: tzSearch.text.toLowerCase().replace(/ /g, "_")
                        options: Host.timezones.filter(z => q === "" || z.toLowerCase().indexOf(q) >= 0 || z === Host.timezone).slice(0, 300).map(z => ({ "value": z, "label": z.replace(/_/g, " ").replace(/\//g, " / ") }))
                        value: Host.timezone
                        onActivated: v => Host.setTimezone(v)
                    }
                }
            }
            SettingsRow {
                title: "24-hour clock"
                description: "Shows 14:00 instead of 2:00 PM, everywhere on the screen."
                Switch {
                    checked: Desktop.get("interface", "clock-format", "24h") !== "12h"
                    onToggled: Desktop.set("interface", "clock-format", checked ? "24h" : "12h")
                }
            }
        }
    }

    // ---- region ----
    function localeLabel(code) {
        const l = Qt.locale(code.replace(/\..*$/, ""));
        return (l.nativeLanguageName || code) + (l.nativeTerritoryName ? " (" + l.nativeTerritoryName + ")" : "");
    }
    readonly property var localeOptions: Host.locales.map(c => ({ "value": c, "label": localeLabel(c) })).sort((a, b) => a.label.localeCompare(b.label))
    Column {
        visible: page.tab === "region"
        width: parent.width
        spacing: Theme.spacing * 8
        SettingsGroup {
            width: parent.width
            Missing {
                needs: ["timedate"]
                what: "Changing the language and formats"
            }
            SettingsRow {
                visible: Deps.has("timedate")
                title: "Language"
                description: "The language of menus and apps. It changes the next time you log in."
                iconName: "translate"
                Select {
                    width: Math.round(280 * Math.max(1, Theme.textScale))
                    options: page.localeOptions
                    value: Host.locale
                    onActivated: v => Host.setLocale(v)
                }
            }
            SettingsRow {
                visible: Deps.has("timedate")
                title: "Formats"
                description: "How dates, times, numbers and money are written."
                Select {
                    width: Math.round(280 * Math.max(1, Theme.textScale))
                    options: page.localeOptions
                    value: Host.formats || Host.locale
                    onActivated: v => Host.setFormats(v)
                }
            }
        }
        // live sample in the chosen formats
        Card {
            id: sample
            width: parent.width
            title: "Looks like"
            readonly property var loc: Qt.locale((Host.formats || Host.locale || "en_US").replace(/\..*$/, ""))
            Repeater {
                model: [["Date", sample.loc.toString(page.now, sample.loc.dateFormat(Locale.LongFormat))], ["Short date", sample.loc.toString(page.now, sample.loc.dateFormat(Locale.ShortFormat))], ["Time", sample.loc.toString(page.now, sample.loc.timeFormat(Locale.ShortFormat))], ["Number", Number(1234567.89).toLocaleString(sample.loc, "f", 2)], ["Money", Number(1234.5).toLocaleCurrencyString(sample.loc)]]
                Row {
                    required property var modelData
                    width: parent.width
                    Label {
                        width: 120
                        text: modelData[0]
                        color: Theme.c.muted
                    }
                    Label {
                        text: modelData[1]
                    }
                }
            }
        }
    }

    // ---- users ----
    Column {
        visible: page.tab === "users"
        width: parent.width
        spacing: Theme.spacing * 8
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing * 3
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 112
                height: 112
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.c.accentSoft
                    Label {
                        anchors.centerIn: parent
                        text: (Host.realName || Host.user).split(" ").map(w => w.charAt(0)).join("").slice(0, 2).toUpperCase()
                        font.pixelSize: Theme.px(40)
                        weight: Theme.weightSemibold
                        color: Theme.c.accent
                    }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    visible: avatar.status === Image.Ready
                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: Host.iconFile ? "file://" + Host.iconFile : ""
                        sourceSize: Qt.size(224, 224)
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Button {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    size: "sm"
                    variant: "tertiary"
                    iconName: "edit-fill"
                    visible: Deps.has("accounts")
                    onClicked: picture.open()
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Host.realName || Host.user
                size: "xl"
                weight: Theme.weightSemibold
            }
            Chip {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Host.accountType || "Standard"
                tone: Host.accountType === "Administrator" ? "accent" : "default"
                variant: "soft"
            }
        }
        SettingsGroup {
            width: parent.width
            Missing {
                needs: ["accounts"]
                what: "Changing your name and picture"
            }
            SettingsRow {
                visible: Deps.has("accounts")
                title: "Name"
                TextField {
                    width: Math.round(240 * Math.max(1, Theme.textScale))
                    text: Host.realName
                    onAccepted: Host.setRealName(text)
                }
            }
            SettingsRow {
                title: "User name"
                Label {
                    text: Host.user
                    color: Theme.c.muted
                }
            }
        }
    }
    FileDialog {
        id: picture
        title: "Your picture"
        nameFilters: ["Pictures (*.jpg *.jpeg *.png)"]
        onAccepted: Host.setIcon(selectedFile.toString().replace("file://", ""))
    }
}
