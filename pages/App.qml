import QtQuick
import "../theme"
import "../services"
import "../components"

// The window's layout: the sidebar (title, search, the pages in GNOME's groups) and the chosen page
// (header with its title and the close button, then its content, scrolling, at a readable width).
Item {
    id: app

    property var window
    // the open page lives in Nav, so pages can send you elsewhere
    readonly property string page: Nav.page
    property string query: ""

    // the pages, in the sidebar's order; `group` changes where a gap goes; `flip` turns the icon over;
    // `layers` draws a live level icon like the island's (Wi-Fi bars, the speaker's waves); `needs`: what
    // the whole page can't work without (Deps ids): without it the page is MissingPage, which offers it
    readonly property var pages: [
        { "id": "wifi", "label": "Wi-Fi", "icon": "island-wifi3", "layers": "wifi", "group": 0, "needs": ["networkmanager"] },
        { "id": "network", "label": "Network", "icon": "lan-fill", "group": 0, "needs": ["networkmanager"] },
        { "id": "bluetooth", "label": "Bluetooth", "icon": "island-bluetooth", "group": 0, "needs": ["bluez"] },
        { "id": "displays", "label": "Displays", "icon": "desktop_windows-fill", "group": 1 },
        { "id": "sound", "label": "Sound", "icon": "island-volume-up", "layers": "volume", "group": 1 },
        { "id": "power", "label": "Power", "icon": "island-battery", "group": 1 },
        { "id": "windows", "label": "Windows & Workspaces", "icon": "view_column-fill", "group": 2 },
        { "id": "appearance", "label": "Appearance", "icon": "palette-fill", "group": 2 },
        { "id": "island", "label": "Dynamic Island", "icon": "toast-fill", "flip": true, "group": 2 },
        { "id": "apps", "label": "Apps", "icon": "apps", "group": 3 },
        { "id": "notifications", "label": "Notifications", "icon": "island-notifications", "group": 3 },
        { "id": "search", "label": "Search", "icon": "search", "group": 3, "island": true },
        { "id": "mouse", "label": "Mouse & Touchpad", "icon": "mouse-fill", "group": 4 },
        { "id": "keyboard", "label": "Keyboard", "icon": "keyboard-fill", "group": 4 },
        { "id": "printers", "label": "Printers", "icon": "print-fill", "group": 4, "needs": ["cups"] },
        { "id": "accessibility", "label": "Accessibility", "icon": "accessibility_new", "group": 5 },
        { "id": "privacy", "label": "Privacy & Security", "icon": "shield-fill", "group": 5 },
        { "id": "system", "label": "System", "icon": "settings-fill", "group": 5 },
        { "id": "components", "label": "Components", "icon": "widgets-fill", "group": 6, "dev": true }
    ].filter(p => (!p.dev || Env.dev) && (!p.island || Island.installed))
    // each page's file
    readonly property var files: ({ "wifi": "WifiPage", "network": "NetworkPage", "bluetooth": "BluetoothPage", "displays": "DisplaysPage", "sound": "SoundPage", "power": "PowerPage", "windows": "WindowsPage", "appearance": "AppearancePage", "island": "IslandPage", "apps": "AppsPage", "notifications": "NotificationsPage", "search": "SearchPage", "mouse": "MousePage", "keyboard": "KeyboardPage", "printers": "PrintersPage", "accessibility": "AccessibilityPage", "privacy": "PrivacyPage", "system": "SystemPage", "components": "ComponentsPage" })

    // Every setting's title, by page (bin/settings-index.py, which the island's launcher uses too), so
    // the search finds a setting and not only a page: "tap to click" finds Mouse & Touchpad and says
    // which setting matched.
    property var settings: ({})    // page id -> [titles]
    Component.onCompleted: Env.read(["python3", Env.appDir + "/bin/settings-index.py"], (code, out) => {
        try {
            const map = {};
            for (const e of JSON.parse(out))
                // the island's settings only when it's installed
                if (e.title !== e.pageLabel && (!e.island || Island.installed))
                    (map[e.page] = map[e.page] || []).push(e.title);
            app.settings = map;
        } catch (e) {
            console.warn("App: no settings index: " + e.message);
        }
    })
    // ---- going to a setting (Nav.go(page, title)): components/SettingReveal ----
    Connections {
        target: Nav
        function onRequestChanged() {
            // the page is already open: reveal now; otherwise the Loader does once it's loaded
            if (loader.item && loader.status === Loader.Ready && app.files[app.current.id] + ".qml" === String(loader.source).split("/").pop())
                Qt.callLater(() => reveal.go(Nav.setting));
        }
    }

    // the setting on this page that the search matched ("" = the page's name or keywords did)
    function hintFor(p) {
        const q = query.toLowerCase();
        if (q === "" || p.label.toLowerCase().indexOf(q) >= 0)
            return "";
        return (settings[p.id] || []).find(t => t.toLowerCase().indexOf(q) >= 0) || "";
    }
    // words that find a page from the sidebar's search, besides its name
    readonly property var keywords: ({
        "wifi": "wireless internet network password airplane",
        "network": "ethernet cable vpn wireguard openvpn proxy ip dns",
        "bluetooth": "headphones speaker pair devices",
        "displays": "screen monitor resolution refresh scale rotation night light brightness hdr vrr",
        "sound": "volume audio speaker microphone input output balance alert over-amplification overamplification boost louder maximum",
        "power": "battery charge sleep suspend blank idle lock power saver performance",
        "windows": "columns tiling gaps layout overview hot corner alt tab focus mouse workspace",
        "appearance": "dark light theme accent color wallpaper background gaps corners border shadow blur font icons cursor",
        "island": "dynamic island bar top clock corners blur music quick settings",
        "apps": "default browser startup autostart rules window opacity screenshot",
        "notifications": "focus do not disturb alerts banners",
        "search": "launcher web engine google files",
        "mouse": "touchpad pointer speed scroll natural tap click",
        "keyboard": "layout language input shortcut keybinding repeat compose caps",
        "printers": "print cups",
        "accessibility": "text size cursor size contrast animation screen reader orca",
        "privacy": "location recent files trash fingerprint lock",
        "system": "about date time timezone region language format user name computer update"
    })
    readonly property var shown: pages.filter(p => {
        const q = query.toLowerCase();
        return q === "" || p.label.toLowerCase().indexOf(q) >= 0 || (keywords[p.id] || "").indexOf(q) >= 0 || (settings[p.id] || []).some(t => t.toLowerCase().indexOf(q) >= 0);
    })
    readonly property var current: pages.find(p => p.id === page) || pages[0]

    // the live levels for the sidebar's layered icons, as the island's idle bar shows them
    readonly property int wifiBars: {
        if (!Hw.wifiEnabled)
            return 0;
        const n = Hw.wifiNetworks.find(x => x.connected);
        return n ? n.bars : 0;
    }
    readonly property var sinkAudio: Hw.sink && Hw.sink.audio ? Hw.sink.audio : null
    function layersFor(p) {
        return p.layers === "wifi" ? Theme.wifiLayers : p.layers === "volume" ? Theme.volumeLayers : [];
    }
    function levelFor(p) {
        if (p.layers === "wifi")
            return wifiBars;
        if (p.layers === "volume")
            return sinkAudio ? Theme.volumeLevel(Hw.level(sinkAudio)) : 0;
        return 0;
    }

    // narrow windows (niri opens them half the screen wide): the sidebar keeps only its icons
    readonly property bool compact: width < Theme.grow(900, 120)
    // the sidebar, header and reading width grow with the text size (Theme.textScale), so names fit
    // and lines keep about as many words
    readonly property real sidebarWidth: compact ? 68 : Theme.grow(272, 120)
    readonly property real headerHeight: Theme.grow(60, 18)
    readonly property real contentWidth: Math.round(720 * Math.max(1, Theme.textScale))
    readonly property real gutter: Theme.spacing * 6

    Rectangle {
        anchors.fill: parent
        color: Theme.c.background
    }

    // ---- sidebar ----
    Item {
        id: sidebar
        width: app.sidebarWidth
        height: parent.height

        DragHandler {
            target: null
            onActiveChanged: if (active && app.window) app.window.startSystemMove()
        }

        Label {
            visible: !app.compact
            x: app.gutter
            height: app.headerHeight
            text: "Settings"
            size: "lg"
            weight: Theme.weightSemibold
        }
        SearchField {
            id: search
            visible: !app.compact
            x: Theme.spacing * 4
            y: app.headerHeight
            width: parent.width - 2 * x
            variant: "primary"
            placeholder: "Search settings"
            onEdited: app.query = text
            onAccepted: if (app.shown.length) Nav.go(app.shown[0].id, app.hintFor(app.shown[0]))
            // Down: into the list of pages
            Keys.onDownPressed: navKeys.forceActiveFocus(Qt.TabFocusReason)
        }
        // Ctrl+F: back to the search, from anywhere
        Shortcut {
            sequence: "Ctrl+F"
            onActivated: search.input.forceActiveFocus(Qt.ShortcutFocusReason)
        }
        // the list of pages from the keyboard: Tab reaches it (after the search), Up / Down / Home / End
        // open the previous / next / first / last page; its focus shows as a ring on the highlight
        Item {
            id: navKeys
            activeFocusOnTab: true
            function go(i) {
                const list = app.shown;
                if (!list.length)
                    return;
                Nav.go(list[Math.max(0, Math.min(list.length - 1, i))].id);
            }
            readonly property int at: app.shown.findIndex(p => p.id === app.page)
            Keys.onUpPressed: event => {
                if (at <= 0)
                    search.input.forceActiveFocus(Qt.BacktabFocusReason);
                else
                    go(at - 1);
            }
            Keys.onDownPressed: go(at < 0 ? 0 : at + 1)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Home)
                    go(0);
                else if (event.key === Qt.Key_End)
                    go(app.shown.length - 1);
                else
                    return;
                event.accepted = true;
            }
        }

        Flickable {
            id: nav
            y: app.compact ? app.headerHeight : search.y + search.height + Theme.spacing * 4
            width: parent.width
            height: parent.height - y
            contentHeight: navColumn.height + Theme.spacing * 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll {
                flickable: nav
            }

            // the chosen page's highlight, sliding between items
            Rectangle {
                id: highlight
                readonly property Item target: {
                    for (let i = 0; i < navRepeater.count; i++) {
                        const it = navRepeater.itemAt(i);
                        if (it && it.pageId === app.page)
                            return it;
                    }
                    return null;
                }
                visible: !!target
                x: navColumn.x
                y: target ? navColumn.y + target.y + (target.gapAbove ? Theme.spacing * 4 : 0) : 0
                width: navColumn.width
                height: target ? target.height - (target.gapAbove ? Theme.spacing * 4 : 0) : Theme.list.itemHeight
                radius: Theme.field.radius
                color: Theme.c.default
                Behavior on y {
                    Spring {}
                }
                FocusRing {
                    shown: navKeys.activeFocus
                    offset: 0
                    baseRadius: parent.radius
                }
            }
            Column {
                id: navColumn
                x: app.compact ? Theme.spacing * 2.5 : Theme.spacing * 4
                width: parent.width - 2 * x
                Repeater {
                    id: navRepeater
                    model: app.shown
                    Item {
                        required property var modelData
                        required property int index
                        readonly property string pageId: modelData.id
                        // a gap before a new group
                        readonly property bool gapAbove: index > 0 && app.shown[index - 1].group !== modelData.group && app.query === ""
                        width: navColumn.width
                        height: navItem.height + (gapAbove ? Theme.spacing * 4 : 0)
                        NavItem {
                            id: navItem
                            y: parent.gapAbove ? Theme.spacing * 4 : 0
                            width: parent.width
                            label: parent.modelData.label
                            iconName: parent.modelData.icon
                            compact: app.compact
                            // toast upside down: a screen with the island's bar at the top
                            iconRotation: parent.modelData.flip ? 180 : 0
                            selected: parent.modelData.id === app.page
                            hint: app.hintFor(parent.modelData)
                            layers: app.layersFor(parent.modelData)
                            level: app.levelFor(parent.modelData)
                            alone: parent.modelData.layers === "volume" && app.sinkAudio && app.sinkAudio.muted ? Theme.volumeMuted : ""
                            onClicked: Nav.go(parent.modelData.id, app.hintFor(parent.modelData))
                        }
                    }
                }
            }
        }
        Label {
            visible: app.shown.length === 0
            anchors.centerIn: nav
            text: "No settings found"
            color: Theme.c.muted
        }
    }

    // ---- page ----
    Item {
        id: main
        x: sidebar.width
        width: parent.width - x
        height: parent.height

        Item {
            id: header
            width: parent.width
            height: app.headerHeight
            DragHandler {
                target: null
                onActiveChanged: if (active && app.window) app.window.startSystemMove()
            }
            Label {
                id: pageTitle
                x: Math.max(app.gutter, (parent.width - app.contentWidth) / 2)
                height: parent.height
                text: app.current.label
                size: "lg"
                weight: Theme.weightSemibold
            }
            Button {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                size: "sm"
                iconName: "close"
                onClicked: Qt.quit()
            }
        }

        // before anything is written in niri's folder: may the app add its one line to the desktop's
        // configuration? (Niri.askInclude; changes made before the answer wait, Niri.heldChange)
        Banner {
            id: includeNotice
            visible: Niri.askInclude
            x: Math.max(app.gutter, (parent.width - app.contentWidth) / 2)
            y: header.height
            width: Math.min(app.contentWidth, parent.width - 2 * app.gutter)
            tone: "accent"
            title: Niri.heldChange ? "Your change is waiting for your permission" : "Let Settings change your desktop?"
            description: "Settings keeps the choices you make here (windows, mouse, keyboard, displays, appearance) in a file of its own. To use it, it adds one line to your desktop's configuration. Nothing you have set yourself is changed, and you can remove that line at any time." + (Niri.heldChange ? " Not now undoes your change." : "")
            actionText: "Allow"
            actionVariant: "primary"
            secondaryText: "Not now"
            onAction: Niri.allowInclude()
            onSecondary: Niri.declineInclude()
            z: 2
        }
        Banner {
            id: niriError
            visible: Niri.lastError !== "" && app.page !== "displays"
            x: Math.max(app.gutter, (parent.width - app.contentWidth) / 2)
            y: header.height + (includeNotice.visible ? includeNotice.height + Theme.spacing * 2 : 0)
            width: Math.min(app.contentWidth, parent.width - 2 * app.gutter)
            tone: "danger"
            title: "That change couldn't be saved"
            description: "Nothing was changed, so everything keeps working as before."
            actionText: "Dismiss"
            onAction: Niri.lastError = ""
            z: 2
        }
        Flickable {
            id: scroller
            y: header.height + (includeNotice.visible ? includeNotice.height + Theme.spacing * 2 : 0) + (niriError.visible ? niriError.height + Theme.spacing * 2 : 0)
            width: parent.width
            height: parent.height - y
            contentHeight: loader.height + app.gutter * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll {
                flickable: scroller
            }
            Loader {
                id: loader
                x: Math.max(app.gutter, (scroller.width - width) / 2)
                y: Theme.spacing * 2
                width: Math.min(app.contentWidth, scroller.width - 2 * app.gutter)
                // without the island, its page is a showcase of it; without what a page needs, a page
                // offering it (MissingPage)
                source: (app.current.id === "island" && !Island.installed ? "IslandShowcase" : Deps.lacks(app.current.needs).length > 0 ? "MissingPage" : app.files[app.current.id]) + ".qml"
                onLoaded: {
                    item.width = Qt.binding(() => loader.width);
                    if (item.hasOwnProperty("window"))
                        item.window = app.window;
                    if (item.hasOwnProperty("page"))
                        item.page = Qt.binding(() => app.current);
                    scroller.contentY = 0;
                    if (Nav.setting !== "")
                        Qt.callLater(() => reveal.go(Nav.setting));
                }
            }
            SettingReveal {
                id: reveal
                flickable: scroller
                page: loader.item
            }
            // faint scrollbar while it moves
            Rectangle {
                parent: scroller
                visible: scroller.contentHeight > scroller.height
                x: scroller.width - width - Theme.spacing
                y: scroller.visibleArea.yPosition * scroller.height
                width: Theme.spacing * 1.5
                height: scroller.visibleArea.heightRatio * scroller.height
                radius: width / 2
                color: Theme.c.scrollbar
                opacity: scroller.moving ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.slow }
                }
            }
        }
    }
}
