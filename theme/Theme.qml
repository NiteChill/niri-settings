pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// The look of every component: colors, sizes, corners, text, motion. Sizes, greys and timings come from
// HeroUI v3's default theme (packages/styles/themes/default/variables.css, oklch converted to hex);
// the text colors, status colors, accents, font axes and springs are the Dynamic Island's own (its
// config/schema.json: colors.*, font.*, colors.systemAccents, panel.list.highlight), so the app and the
// island read as one thing. The app follows its own settings, live: dark or light, the accent, the
// interface font, the text size (text sizes, and the height of controls holding text), high contrast
// (stronger text, outlines and fills), reduce animation (no motion) and the animation speed (niri's
// slowdown). Scrolling follows the mouse / touchpad scroll speed through components/WheelScroll.
Singleton {
    id: theme

    // ---- desktop settings ----
    readonly property string colorScheme: Desktop.get("interface", "color-scheme", "prefer-dark")
    readonly property string accentName: Desktop.get("interface", "accent-color", "blue")
    readonly property bool dark: colorScheme === "prefer-dark"
    // Accessibility > Text size: every text size, and controls grow by what their text grows
    readonly property real textScale: Math.max(0.5, Number(Desktop.get("interface", "text-scaling-factor", 1)) || 1)
    // Accessibility > High contrast
    readonly property bool highContrast: Desktop.get("a11y", "high-contrast", false) === true
    // Accessibility > Reduce animation (niri's animations off, or the desktop's enable-animations off)
    // and Animation speed (niri's slowdown: 2 = twice as slow)
    readonly property bool reduceMotion: (Niri.revision, !Niri.onOff("animations", true)) || Desktop.get("interface", "enable-animations", true) === false
    readonly property real slowdown: Math.max(0.1, Number((Niri.revision, Niri.arg("animations.slowdown", 1))) || 1)
    // a duration (ms) as the app plays it: 0 with reduced animation, longer or shorter with the speed
    function dur(ms) {
        return reduceMotion ? 0 : Math.round(ms * slowdown);
    }
    // a control's height for text of `px` (unscaled): grows by what its text grows, keeps its padding
    function grow(base, px) {
        return Math.round(base + px * (textScale - 1));
    }
    // a text size given in px (unscaled), at the chosen text size
    function px(n) {
        return Math.round(n * textScale * 10) / 10;
    }

    // ---- colors ----
    readonly property var dk: ({
        "background": "#060607",
        "foreground": "#f2f2f2",
        "surface": "#18181b",
        "surfaceHover": "#27272a",
        "surfaceSecondary": "#232325",
        "surfaceTertiary": "#262728",
        "overlay": "#18181b",
        "muted": "#98989f",
        "default": "#27272a",
        "defaultHover": "#2e2e31",
        "defaultForeground": "#f2f2f2",
        "defaultSoft": "#8027272a",
        "field": "#18181b",
        "fieldHover": "#eb1c1c1f",
        "segment": "#46464c",
        "border": "#28282c",
        "separator": "#212124",
        "separatorSecondary": "#343437",
        "scrollbar": "#26fcfcfc",
        // the island's charging green, power-saver yellow, danger red
        "success": "#95fd83",
        "successForeground": "#18181b",
        "warning": "#fac634",
        "warningForeground": "#18181b",
        "danger": "#f97678",
        "dangerHover": "#fa8b8d",
        "dangerForeground": "#18181b",
        "dangerSoft": "#26f97678",
        "dangerSoftHover": "#33f97678",
        "dangerSoftForeground": "#fa9a9b",
        "successSoft": "#1f95fd83",
        "successSoftForeground": "#b0fda2",
        "warningSoft": "#1ffac634",
        "warningSoftForeground": "#fbd677",
        "backdrop": "#99000000",
        // popovers, menus, tooltips: HeroUI's dark overlay shadow is a 1 px light inner edge
        "overlayBorder": "#29ffffff",
        "overlayShadow": "#00000000",
        // soft tints of the accent: alpha over the surface, and how much of the text color its text takes
        "accentSoftAlpha": 0.12,
        "accentSoftHoverAlpha": 0.16,
        "accentSoftText": 0.27
    })
    readonly property var lt: ({
        "background": "#f5f5f5",
        "foreground": "#18181b",
        "surface": "#ffffff",
        "surfaceHover": "#eaeaea",
        "surfaceSecondary": "#efeff0",
        "surfaceTertiary": "#eaeaeb",
        "overlay": "#ffffff",
        "muted": "#71717a",
        "default": "#ebebec",
        "defaultHover": "#e1e1e2",
        "defaultForeground": "#18181b",
        "defaultSoft": "#80ebebec",
        "field": "#ffffff",
        "fieldHover": "#ebf9f9f9",
        "segment": "#ffffff",
        "border": "#dedee0",
        "separator": "#e4e4e7",
        "separatorSecondary": "#d8d8d8",
        "scrollbar": "#2618181b",
        "success": "#17c964",
        "successForeground": "#18181b",
        "warning": "#f5a524",
        "warningForeground": "#18181b",
        "danger": "#ff383c",
        "dangerHover": "#ff5551",
        "dangerForeground": "#fcfcfc",
        "dangerSoft": "#26ff383c",
        "dangerSoftHover": "#33ff383c",
        "dangerSoftForeground": "#a43433",
        "successSoft": "#2617c964",
        "successSoftForeground": "#2b7745",
        "warningSoft": "#26f5a524",
        "warningSoftForeground": "#855f2e",
        "backdrop": "#80000000",
        "overlayBorder": "#0f000000",
        "overlayShadow": "#26000000",
        "accentSoftAlpha": 0.15,
        "accentSoftHoverAlpha": 0.2,
        "accentSoftText": 0.3
    })
    // high contrast (Accessibility): text as strong as can be, grey text close to it, outlines and
    // separators that show, fills further from the background, soft tints stronger
    readonly property var hcDk: ({
        "background": "#000000",
        "surface": "#141416",
        "foreground": "#ffffff",
        "muted": "#d4d4d8",
        "default": "#3a3a3f",
        "defaultHover": "#47474d",
        "defaultForeground": "#ffffff",
        "defaultSoft": "#cc3a3a3f",
        "segment": "#5c5c63",
        "border": "#8a8a92",
        "separator": "#5a5a60",
        "separatorSecondary": "#77777e",
        "scrollbar": "#99fcfcfc",
        "overlayBorder": "#99ffffff",
        "accentSoftAlpha": 0.24,
        "accentSoftHoverAlpha": 0.3,
        "accentSoftText": 0.55
    })
    readonly property var hcLt: ({
        "foreground": "#000000",
        "muted": "#3f3f46",
        "default": "#dcdcde",
        "defaultHover": "#cfcfd2",
        "defaultForeground": "#000000",
        "defaultSoft": "#ccdcdcde",
        "border": "#6b6b72",
        "separator": "#9a9aa0",
        "separatorSecondary": "#7d7d84",
        "scrollbar": "#9918181b",
        "overlayBorder": "#99000000",
        "dangerSoftForeground": "#7a1f1f",
        "successSoftForeground": "#1d5232",
        "warningSoftForeground": "#5c3f17",
        "accentSoftAlpha": 0.25,
        "accentSoftHoverAlpha": 0.32,
        "accentSoftText": 0.6
    })
    // the desktop's accent names (GNOME's list) -> colors: the island's colors.systemAccents, so a choice
    // here looks the same in the island
    readonly property var accents: ({
        "blue": "#0a84ff",
        "teal": "#40c8e0",
        "green": "#30d158",
        "yellow": "#ffd60a",
        "orange": "#ff9f0a",
        "red": "#ff453a",
        "pink": "#ff375f",
        "purple": "#bf5af2",
        "slate": "#8e9aaf"
    })
    readonly property color accent: accents[accentName] || accents.blue
    // text on the accent: dark on light accents (HeroUI: success and warning take dark text)
    readonly property color accentForeground: luminance(accent) > 0.45 ? "#18181b" : "#fcfcfc"

    // every color a component uses: Theme.c.<name>
    readonly property var c: {
        const b = Object.assign({}, dark ? dk : lt, highContrast ? (dark ? hcDk : hcLt) : {});
        const o = Object.assign({}, b);
        o.accent = accent;
        o.accentForeground = accentForeground;
        o.accentHover = mix(accent, accentForeground, 0.1);
        o.accentSoft = alpha(accent, b.accentSoftAlpha);
        o.accentSoftHover = alpha(accent, b.accentSoftHoverAlpha);
        o.accentSoftForeground = mix(accent, b.foreground, b.accentSoftText);
        o.focus = accent;
        return o;
    }

    // ---- text ----
    // Appearance > Interface font: the family of the desktop's font-name ("Adwaita Sans 11"); the size
    // in it is left out (the app's sizes, times the text size above)
    readonly property string fontName: Desktop.get("interface", "font-name", "")
    readonly property var font: ({
        "family": fontName.replace(/\s+\d+(\.\d+)?\s*$/, "").trim() || "Google Sans Flex",
        // Google Sans Flex's ROND axis (0 = square letter ends, 100 = round): the island's font.roundness
        "roundness": 100
    })
    // Tailwind's scale, in px: text-xs ... text-3xl
    // (at the chosen text size: Theme.textScale)
    readonly property var text: ({
        "xs": px(12),
        "sm": px(14),
        "base": px(16),
        "lg": px(18),
        "xl": px(20),
        "2xl": px(24),
        "3xl": px(30)
    })
    // the island writes everything semibold; the app keeps body text lighter, titles at the island's weight
    readonly property int weightNormal: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemibold: Font.DemiBold

    // ---- sizes (HeroUI's desktop sizes: Tailwind spacing 1 = 4 px) ----
    readonly property int spacing: 4
    readonly property real disabledOpacity: highContrast ? 0.65 : 0.5
    // cards (settings groups) get an outline in high contrast: a fill alone can be too close to the
    // background to see where a card ends
    readonly property int cardBorder: highContrast ? 1 : 0
    readonly property var button: ({
        "height": { "sm": grow(32, 14), "md": grow(36, 14), "lg": grow(40, 16) },
        "padding": { "sm": 12, "md": 16, "lg": 16 },
        "iconSize": { "sm": 16, "md": 16, "lg": 20 },
        "pressedScale": { "sm": 0.98, "md": 0.97, "lg": 0.96 },
        "gap": 8
    })
    readonly property var field: ({
        "height": grow(36, 14),
        "radius": 12,
        "paddingX": 12,
        "iconSize": 16,
        "stepperWidth": 40,
        "gap": 4             // label / field / description
    })
    readonly property var toggle: ({
        "trackWidth": 40,
        "trackHeight": 20,
        "thumbWidth": 22,
        "thumbHeight": 16,
        "thumbInset": 2,
        "box": 16,           // checkbox and radio
        "boxRadius": 6,
        "checkSize": 10,
        "labelGap": 12,
        "radioDot": 6,
        "radioDotPressed": 8
    })
    readonly property var slider: ({
        "trackHeight": 20,
        "thumbWidth": 28,
        "knobWidth": 24,
        "knobHeight": 16,
        "edge": 14,          // the track's ends: room for half the thumb, painted like the fill
        "stepDot": 3,
        "draggingScale": 0.9
    })
    readonly property var radius: ({
        "sm": 4,
        "md": 6,
        "lg": 8,
        "xl": 12,
        "2xl": 16,
        "3xl": 24
    })
    readonly property var card: ({
        "radius": 24,
        "padding": 16,
        "gap": 12
    })
    readonly property var tabs: ({
        "listRadius": 20,
        "listPadding": 4,
        "tabHeight": grow(32, 14),
        "tabPadding": 16,
        "gap": 4
    })
    readonly property var list: ({
        "itemHeight": grow(36, 14),
        "itemRadius": 16,
        "itemPaddingX": 8,
        "gap": 12,
        "popoverPadding": 4,
        "popoverRadius": 24,
        "popoverGap": 6,     // trigger -> popover
        "maxRows": 8
    })
    readonly property var chip: ({
        "height": grow(24, 12),
        "paddingX": 10,
        "heightSm": grow(20, 12),
        "paddingXSm": 6,
        "heightLg": grow(28, 14),
        "paddingXLg": 14
    })
    readonly property var kbd: ({
        "height": grow(24, 12),
        "radius": 8,
        "paddingX": 8,
        "gap": 2
    })
    readonly property var tooltip: ({
        "padding": 8,
        "radius": 12,
        "delay": 700,
        "maxWidth": 320
    })
    readonly property int focusRing: highContrast ? 3 : 2
    readonly property int focusOffset: 2

    // ---- motion (HeroUI's durations and curves) ----
    // (as played, through dur(): 0 with reduced animation, stretched by the animation speed)
    readonly property var motion: ({
        "fast": dur(100),
        "normal": dur(150),
        "slow": dur(250),
        "thumb": dur(300),
        "spin": Math.round(750 * slowdown)   // a spinner keeps turning: it says something is happening
    })
    // the island's springs, Apple-style { response (s), dampingFraction }: things that travel (highlights,
    // segments, thumbs) spring like the island's lists; colors and fades keep HeroUI's curves
    readonly property var springMove: ({ "response": 0.35, "dampingFraction": 0.75 })
    readonly property var springSoft: ({ "response": 0.36, "dampingFraction": 0.85 })
    // -> SpringAnimation's spring / damping (same maths as the island's Config.spring)
    // reduced animation: spring 0 (+ components/Spring's unlimited velocity) = it jumps there
    function spring(s) {
        if (reduceMotion)
            return { "spring": 0, "damping": 0 };
        const h = 0.016;
        const w = 2 * Math.PI / (s.response * slowdown);
        return { "spring": w * w * h, "damping": 2 * s.dampingFraction * w * h };
    }
    // CSS curves as QML bezier lists (Easing.BezierSpline)
    readonly property var easeSmooth: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property var easeOut: [0, 0, 0.2, 1, 1, 1]
    readonly property var easeOutFluid: [0.32, 0.72, 0, 1, 1, 1]
    readonly property var easeOutQuart: [0.165, 0.84, 0.44, 1, 1, 1]

    // ---- scrolling (components/WheelScroll) ----
    // px per wheel notch (angle 120; niri has already multiplied it by the mouse's scroll speed) and
    // how long the page glides there
    readonly property var scroll: ({
        "notch": 64,
        "glide": dur(220)
    })

    // ---- helpers ----
    function alpha(col, a) {
        const q = Qt.color(col);
        return Qt.rgba(q.r, q.g, q.b, q.a * a);
    }
    // a + (b - a) * t, per channel
    function mix(a, b, t) {
        const p = Qt.color(a), q = Qt.color(b);
        return Qt.rgba(p.r + (q.r - p.r) * t, p.g + (q.g - p.g) * t, p.b + (q.b - p.b) * t, p.a + (q.a - p.a) * t);
    }
    // text / glyph color on a fill: dark on light fills (yellow, green, white), white on the rest
    function onColor(fill) {
        return luminance(fill) > 0.45 ? "#18181b" : "#ffffff";
    }
    function luminance(col) {
        const q = Qt.color(col);
        const f = x => x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
        return 0.2126 * f(q.r) + 0.7152 * f(q.g) + 0.0722 * f(q.b);
    }

    // icon file name (assets/icons) -> { path, x, y, w, h, evenOdd } for components/Icon.qml; read once
    property var _glyphs: ({})
    // ---- level icons, drawn like the island's (components/LayeredIcon): its own drawings, the whole
    // symbol at idle.overlayOpacity under the real level ----
    readonly property real layerDim: 0.45
    readonly property var wifiLayers: ["island-wifi1", "island-wifi2", "island-wifi3"]
    readonly property var volumeLayers: ["island-volume-level0", "island-volume-level1", "island-volume-up"]
    readonly property string volumeMuted: "island-volume-off"
    // the island's speaker: silent, below half (volume.lowLevel), or loud
    function volumeLevel(v) {
        return v <= 0 ? 1 : v < 0.5 ? 2 : 3;
    }

    // keyboard: move focus to the previous (-1) / next (1) choice beside `item` (tiles, swatches: items
    // with `isChoice` under the same parent, a Row of a Repeater's tiles)
    function stepFocus(item, dir) {
        if (!item.parent)
            return;
        const all = item.parent.children.filter(c => c.isChoice && c.visible && c.enabled);
        const next = all[all.indexOf(item) + dir];
        if (next)
            next.forceActiveFocus(Qt.TabFocusReason);
    }
    function glyph(name) {
        if (!name)
            return null;
        if (name in _glyphs)
            return _glyphs[name];
        const file = svgFile.createObject(theme, {
            "path": Qt.resolvedUrl("../assets/icons/" + name + ".svg")
        });
        const svg = file.text() || "";
        file.destroy();
        const head = (svg.match(/<svg\b[^>]*>/) || [""])[0];
        const box = ((head.match(/\sviewBox="([^"]*)"/) || [])[1] || "").trim().split(/[\s,]+/).map(Number);
        const paths = [];
        const re = /<path\b[^>]*?\sd="([^"]*)"/g;
        let m;
        while ((m = re.exec(svg)))
            paths.push(_absoluteStart(m[1].trim()));
        let g = null;
        if (box.length === 4 && paths.length)
            g = {
                "path": paths.join(" "),
                "x": box[0],
                "y": box[1],
                "w": box[2],
                "h": box[3],
                "evenOdd": /evenodd/.test(svg)
            };
        else
            console.warn("Theme: icon " + name + " not found or not drawable");
        _glyphs[name] = g;
        return g;
    }
    // a path's first "m" is absolute (SVG), but joined after another path it would be relative to where
    // that one ended: write it "M". The number pairs right after it are relative line-tos ("m 1 2 3 4" =
    // move, then line by 3 4): spell that "l", or "M 1 2 3 4" would make them absolute.
    function _absoluteStart(d) {
        const num = "(-?(?:\\d+\\.?\\d*|\\.\\d+)(?:e[-+]?\\d+)?)";
        const mm = d.match(new RegExp("^m\\s*" + num + "[\\s,]*" + num, "i"));
        if (!mm || d[0] === "M")
            return d;
        const rest = d.slice(mm[0].length).trim();
        return "M" + mm[1] + " " + mm[2] + (/^[-.\d]/.test(rest) ? " l" : " ") + rest;
    }
    Component {
        id: svgFile
        FileView {
            blockLoading: true
        }
    }

}
