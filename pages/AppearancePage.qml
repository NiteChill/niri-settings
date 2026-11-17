import QtQuick
import Quickshell.Widgets
import QtQuick.Dialogs
import "../theme"
import "../services"
import "../components"

// Appearance: light or dark and the accent (pictures and color dots), the wallpaper (your pictures as
// tiles), then the windows' look with a live picture of your desktop that follows every slider, and
// fonts / icons / cursor.
Column {
    id: page
    spacing: Theme.spacing * 8

    readonly property int rev: Niri.revision
    // the app's global window rule (no `match`): where the corner radius lives
    readonly property var globalRule: (rev, Niri.ownNodes(n => n.name === "window-rule" && !(n.children || []).some(c => c.name === "match")).pop() || Niri.mainNodes(n => n.name === "window-rule" && !(n.children || []).some(c => c.name === "match")).pop() || null)
    readonly property real corner: {
        const c = globalRule && globalRule.children ? globalRule.children.find(c => c.name === "geometry-corner-radius") : null;
        return c ? c.args[0] : 0;
    }
    function setCorner(r) {
        Niri.replaceNodes(n => n.name === "window-rule" && !(n.children || []).some(c => c.name === "match") && (n.children || []).some(c => c.name === "geometry-corner-radius"), [Kdl.node("window-rule", [], {}, [Kdl.node("geometry-corner-radius", [r]), Kdl.node("clip-to-geometry", [true])])]);
    }

    // ---- style ----
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Label {
            leftPadding: Theme.spacing
            text: "Style"
            weight: Theme.weightSemibold
        }
        Row {
            spacing: Theme.spacing * 4
            Repeater {
                model: [["default", "Light", "#f5f5f5", "#ffffff", "#18181b"], ["prefer-dark", "Dark", "#060607", "#18181b", "#f2f2f2"]]
                TileOption {
                    id: style
                    required property var modelData
                    width: 200
                    previewHeight: 120
                    label: modelData[1]
                    selected: Theme.colorScheme === modelData[0] || (modelData[0] === "default" && Theme.colorScheme === "prefer-light")
                    previewColor: modelData[2]
                    onClicked: Desktop.set("interface", "color-scheme", modelData[0])
                    // a tiny settings window in that style
                    Rectangle {
                        x: 18
                        y: 18
                        width: parent.width - 36
                        height: parent.height
                        radius: 10
                        color: style.modelData[3]
                        Column {
                            x: 10
                            y: 12
                            spacing: 7
                            Rectangle { width: 60; height: 7; radius: 4; color: style.modelData[4]; opacity: 0.8 }
                            Rectangle { width: 110; height: 6; radius: 3; color: style.modelData[4]; opacity: 0.25 }
                            Rectangle { width: 90; height: 6; radius: 3; color: style.modelData[4]; opacity: 0.25 }
                            Row {
                                spacing: 6
                                Rectangle { width: 28; height: 14; radius: 7; color: Theme.accent }
                                Rectangle { width: 28; height: 14; radius: 7; color: style.modelData[4]; opacity: 0.15 }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        SettingsRow {
            title: "Accent colour"
            description: "The colour of switches, selections and highlights, in apps and at the top of the screen."
            Row {
                spacing: Theme.spacing
                Repeater {
                    model: Object.keys(Theme.accents)
                    Swatch {
                        required property string modelData
                        color: Theme.accents[modelData]
                        tip: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        selected: Theme.accentName === modelData
                        onClicked: Desktop.set("interface", "accent-color", modelData)
                    }
                }
            }
        }
    }

    // ---- wallpaper ----
    property var pictures: []
    // the island's way (its bin/wallpaper list): the pictures in wallpaper.folders (default
    // ~/Pictures/[Ww]allpaper*: Wallpaper, wallpapers...), folder by folder, sorted by path, at most
    // wallpaper.depth levels down, wallpaper.extensions only; its settings when it's installed, the same
    // defaults otherwise. So the island's wallpaper panel and this list always show the same pictures.
    readonly property string pictureLister: "import glob, os, sys\n" +
        "exts = {'.' + e.lower().lstrip('.') for e in sys.argv[2].split(',') if e}\n" +
        "depth, seen = int(sys.argv[1]), set()\n" +
        "for pattern in sys.argv[3:]:\n" +
        "    for folder in sorted(glob.glob(os.path.expanduser(pattern))):\n" +
        "        found = []\n" +
        "        for root, dirs, files in os.walk(folder, followlinks=True):\n" +
        "            level = os.path.relpath(root, folder).count(os.sep) + (0 if root == folder else 1)\n" +
        "            dirs[:] = [d for d in dirs if not d.startswith('.')] if level + 1 < depth else []\n" +
        "            found += [os.path.join(root, n) for n in files if os.path.splitext(n)[1].lower() in exts]\n" +
        "        for path in sorted(found):\n" +
        "            if path not in seen:\n" +
        "                seen.add(path)\n" +
        "                print(path)\n"
    function findPictures() {
        const folders = Island.value("wallpaper.folders", ["~/Pictures/[Ww]allpaper*"]);
        const exts = Island.value("wallpaper.extensions", ["jpg", "jpeg", "png"]);
        const depth = Island.value("wallpaper.depth", 3);
        Env.readFor(page, ["python3", "-c", pictureLister, String(depth), exts.join(",")].concat(folders), (code, out) => page.pictures = out.trim().split("\n").filter(l => l));
    }
    // the island's settings arrive (or change): list again with its folders
    readonly property int islandRevision: Island.revision
    onIslandRevisionChanged: findPictures()
    Component.onCompleted: {
        findPictures();
        Env.readFor(page, ["sh", "-c", "fc-list : family | cut -d, -f1 | sort -u"], (code, out) => page.fonts = out.trim().split("\n").filter(l => l && !l.startsWith(".")));
        Env.readFor(page, ["sh", "-c", "for d in /usr/share/icons/* \"$HOME\"/.local/share/icons/* \"$HOME\"/.icons/*; do [ -f \"$d/index.theme\" ] || continue; n=$(basename \"$d\"); if [ -d \"$d/cursors\" ]; then echo \"c $n\"; fi; grep -q '^Directories=' \"$d/index.theme\" && echo \"i $n\"; done | sort -u"], (code, out) => {
            const lines = out.trim().split("\n");
            page.iconThemes = lines.filter(l => l.startsWith("i ")).map(l => l.slice(2)).filter(n => n !== "hicolor" && n !== "default");
            page.cursorThemes = lines.filter(l => l.startsWith("c ")).map(l => l.slice(2)).filter(n => n !== "default");
        });
    }
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Item {
            width: parent.width
            height: 32
            Label {
                x: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpaper"
                weight: Theme.weightSemibold
            }
            Button {
                anchors.right: parent.right
                size: "sm"
                variant: "secondary"
                iconName: "add_photo_alternate-fill"
                text: "Choose a picture…"
                visible: Deps.has("swaybg")
                onClicked: picker.open()
            }
        }
        Missing {
            width: parent.width
            needs: ["swaybg"]
            what: "Changing the wallpaper"
        }
        Flow {
            visible: Deps.has("swaybg")
            width: parent.width
            spacing: Theme.spacing * 3
            Repeater {
                model: page.pictures
                TileOption {
                    required property string modelData
                    width: (page.width - 3 * Theme.spacing * 3) / 4
                    previewHeight: width * 0.62
                    selected: Niri.wallpaper === modelData
                    onClicked: Niri.setWallpaper(modelData, Niri.wallpaperMode)
                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData
                        sourceSize.width: 320
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }
        }
        Label {
            visible: page.pictures.length === 0 && Deps.has("swaybg")
            leftPadding: Theme.spacing
            text: "No pictures in your Wallpaper folder yet. Put some in Pictures › Wallpaper and they show up here."
            color: Theme.c.muted
        }
    }
    FileDialog {
        id: picker
        title: "Wallpaper"
        nameFilters: ["Pictures (*.jpg *.jpeg *.png)"]
        onAccepted: Niri.setWallpaper(selectedFile.toString().replace("file://", ""), Niri.wallpaperMode)
    }

    // ---- windows ----
    Column {
        width: parent.width
        spacing: Theme.spacing * 3
        Label {
            leftPadding: Theme.spacing
            text: "Windows"
            weight: Theme.weightSemibold
        }
        ClippingRectangle {
            width: parent.width
            height: live.height
            radius: Theme.card.radius
            color: Theme.c.surface
            border.width: Theme.cardBorder
            border.color: Theme.c.border
            WindowPreview {
                id: live
                width: parent.width
                gaps: (page.rev, Niri.arg("layout.gaps", 16))
                radius: page.corner
                ringOn: (page.rev, Niri.onOff("layout.focus-ring", true))
                ringWidth: (page.rev, Niri.arg("layout.focus-ring.width", 4))
                ringColor: (page.rev, Niri.arg("layout.focus-ring.active-color", "#7fc8ff"))
                borderOn: (page.rev, Niri.onOff("layout.border", false))
                borderWidth: (page.rev, Niri.arg("layout.border.width", 4))
                borderColor: (page.rev, Niri.arg("layout.border.inactive-color", "#505050"))
                shadowOn: (page.rev, Niri.onOff("layout.shadow", false))
                shadowSoftness: (page.rev, Niri.arg("layout.shadow.softness", 30))
                columns: [0.45, 0.45, 0.45]
                center: true
            }
        }
    }
    SettingsGroup {
        width: parent.width
        SettingsRow {
            wide: true
            title: "Gaps between windows"
            description: "The empty space around each window."
            Slider {
                width: parent.width
                from: 0
                to: 48
                stepSize: 1
                value: (page.rev, Niri.arg("layout.gaps", 16))
                suffix: " px"
                showOutput: true
                onMoved: Niri.set("layout.gaps", [value])
            }
        }
        SettingsRow {
            wide: true
            title: "Window corners"
            description: "How rounded the corners of windows are. 0 makes them square."
            Slider {
                width: parent.width
                from: 0
                to: 32
                stepSize: 1
                value: page.corner
                suffix: " px"
                showOutput: true
                onMoved: page.setCorner(value)
            }
        }
        SettingsRow {
            title: "Focus ring"
            description: "A coloured outline around the window you're using, so you can tell it apart from the others."
            Switch {
                checked: (page.rev, Niri.onOff("layout.focus-ring", true))
                onToggled: Niri.setOnOff("layout.focus-ring", checked)
            }
        }
        SettingsRow {
            visible: (page.rev, Niri.onOff("layout.focus-ring", true))
            title: "Focus ring in the accent colour"
            Switch {
                checked: (page.rev, String(Niri.arg("layout.focus-ring.active-color", "")).toLowerCase() === String(Theme.accent).toLowerCase())
                onToggled: checked ? Niri.set("layout.focus-ring.active-color", [String(Theme.accent)]) : Niri.remove("layout.focus-ring.active-color")
            }
        }
        SettingsRow {
            title: "Border"
            description: "A thin outline around every window, including the ones you're not using."
            Switch {
                checked: (page.rev, Niri.onOff("layout.border", false))
                onToggled: Niri.setOnOff("layout.border", checked)
            }
        }
        SettingsRow {
            visible: (page.rev, Niri.onOff("layout.border", false) || Niri.onOff("layout.focus-ring", true))
            wide: true
            title: "Outline width"
            description: "How thick the outlines around windows are."
            Slider {
                width: parent.width
                from: 1
                to: 12
                stepSize: 1
                value: (page.rev, Niri.arg("layout.focus-ring.width", 4))
                suffix: " px"
                showOutput: true
                onMoved: {
                    Niri.set("layout.focus-ring.width", [value]);
                    Niri.set("layout.border.width", [value]);
                }
            }
        }
        SettingsRow {
            title: "Shadows"
            description: "A soft shadow under each window, so it stands out from what's behind it."
            Switch {
                checked: (page.rev, Niri.onOff("layout.shadow", false))
                onToggled: Niri.setOnOff("layout.shadow", checked)
            }
        }
        SettingsRow {
            visible: (page.rev, Niri.onOff("layout.shadow", false))
            wide: true
            title: "Shadow softness"
            description: "How far the shadow spreads. Higher is softer and wider."
            Slider {
                width: parent.width
                from: 0
                to: 80
                stepSize: 1
                format: v => Math.round(v) + " px"
                value: (page.rev, Niri.arg("layout.shadow.softness", 30))
                showOutput: true
                onMoved: Niri.set("layout.shadow.softness", [value])
            }
        }
        SettingsRow {
            wide: true
            title: "Background blur"
            description: "How much see-through surfaces, such as glass panels and menus, blur what's behind them."
            Slider {
                width: parent.width
                from: 1
                to: 6
                stepSize: 1
                format: v => ["", "Very light", "Light", "Medium", "Strong", "Stronger", "Strongest"][Math.round(v)] || ""
                showSteps: true
                value: (page.rev, Niri.arg("blur.passes", 3))
                marks: [{ "value": 1, "label": "Light" }, { "value": 6, "label": "Strong" }]
                onMoved: Niri.set("blur.passes", [value])
            }
        }
        SettingsRow {
            title: "Rounded screen corners"
            islandOnly: true
            description: "Rounds the corners of your screen, like on a phone."
            Switch {
                checked: Island.value("screenCorners.enabled", true)
                onToggled: Island.set("screenCorners.enabled", checked)
            }
        }
        SettingsRow {
            visible: Island.installed && (Island.value("screenCorners.enabled", true))
            wide: true
            title: "Screen corner size"
            islandOnly: true
            description: "How rounded the screen corners are."
            Slider {
                width: parent.width
                from: 4
                to: 60
                stepSize: 1
                value: Island.value("screenCorners.radius", 30)
                suffix: " px"
                showOutput: true
                onMoved: Island.set("screenCorners.radius", value)
            }
        }
    }

    // ---- text and icons ----
    property var fonts: []
    property var iconThemes: []
    property var cursorThemes: []
    function fontFamily(spec) {
        return (spec || "").replace(/\s+\d+(\.\d+)?$/, "");
    }
    function fontSize(spec) {
        const m = /(\d+(\.\d+)?)$/.exec(spec || "");
        return m ? m[1] : "11";
    }
    SettingsGroup {
        width: parent.width
        title: "Text and icons"
        // the fonts are listed by fontconfig: without it the two font lists would be empty
        Missing {
            needs: ["fontconfig"]
            what: "Choosing a font"
        }
        SettingsRow {
            visible: Deps.has("fontconfig")
            title: "Interface font"
            description: "The font of menus, buttons and most apps."
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                options: page.fonts.map(f => ({ "value": f, "label": f }))
                readonly property string spec: Desktop.get("interface", "font-name", "Cantarell 11")
                value: page.fontFamily(spec)
                onActivated: v => Desktop.set("interface", "font-name", v + " " + page.fontSize(spec))
            }
        }
        SettingsRow {
            visible: Deps.has("fontconfig")
            title: "Monospace font"
            description: "A font where every letter takes the same width, used in terminals and code editors."
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                options: page.fonts.map(f => ({ "value": f, "label": f }))
                readonly property string spec: Desktop.get("interface", "monospace-font-name", "Monospace 11")
                value: page.fontFamily(spec)
                onActivated: v => Desktop.set("interface", "monospace-font-name", v + " " + page.fontSize(spec))
            }
        }
        SettingsRow {
            title: "Icons"
            description: "The style of the icons in apps and menus."
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                options: page.iconThemes.map(f => ({ "value": f, "label": f }))
                value: Desktop.get("interface", "icon-theme", "Adwaita")
                onActivated: v => Desktop.set("interface", "icon-theme", v)
            }
        }
        SettingsRow {
            title: "Cursor"
            description: "How the pointer looks."
            Select {
                width: Math.round(240 * Math.max(1, Theme.textScale))
                options: page.cursorThemes.map(f => ({ "value": f, "label": f }))
                value: Desktop.get("interface", "cursor-theme", "Adwaita")
                onActivated: v => {
                    Desktop.set("interface", "cursor-theme", v);
                    Niri.set("cursor.xcursor-theme", [v]);
                }
            }
        }
        SettingsRow {
            title: "Title bars in apps"
            description: "Some apps add their own bar across the top of their windows, with buttons to close or shrink them. Turn this off for a cleaner look; you can still close windows with a keyboard shortcut."
            Switch {
                checked: !(page.rev, Niri.flag("prefer-no-csd", false))
                onToggled: Niri.setFlag("prefer-no-csd", !checked)
            }
        }
    }
}
