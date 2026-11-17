import QtQuick
import "../theme"

// Going to a setting: go(title) finds the row / group / tile section with that title in `page`
// (switching the page's tab when it's on another one: Touchpad, Shortcuts, Date & Time...), waits for the
// page to settle (it keeps filling in after it's created: landing at once highlighted whatever had moved
// into the spot), scrolls `flickable` to it and blinks a lighter shade over it once. The shade follows the
// setting while it shows. Put it anywhere; it draws in the flickable's content.
Item {
    id: reveal

    property Flickable flickable
    property Item page

    function go(title) {
        if (!page || !flickable || title === "")
            return;
        let target = _find(page, title);
        if ((!target || !target.visible) && page.hasOwnProperty("tab")) {
            const tabs = _tabs(page);
            for (const o of tabs ? tabs.options : []) {
                page.tab = o.value;
                target = _find(page, title);
                if (target && target.visible)
                    break;
            }
        }
        if (!target || !target.visible)
            return;
        _target = target;
        _lastY = -1;
        _lastH = -1;
        _stable = 0;
        settle.tries = 0;
        settle.restart();
    }

    // a SettingsRow (clickable), a SettingsGroup (rows) or a tile section (tiles) with that title
    function _find(item, title) {
        if (!item)
            return null;
        if (item.title === title && (item.hasOwnProperty("clickable") || item.hasOwnProperty("rows") || item.hasOwnProperty("tiles")))
            return item;
        for (const c of item.children) {
            const r = _find(c, title);
            if (r)
                return r;
        }
        return null;
    }
    // the page's own tab bar: its options are the tabs
    function _tabs(item) {
        for (const c of item.children)
            if (c.hasOwnProperty("options") && c.hasOwnProperty("value") && c.value === item.tab)
                return c;
        return null;
    }

    property Item _target: null
    property real _lastY: -1
    property real _lastH: -1
    property int _stable: 0
    function _targetY() {
        return _target ? _target.mapToItem(flickable.contentItem, 0, 0).y : 0;
    }
    Timer {
        id: settle
        property int tries: 0
        interval: 50
        repeat: true
        onTriggered: {
            if (!reveal._target || !reveal._target.visible) {
                stop();
                return;
            }
            const y = reveal._targetY(), h = reveal.flickable.contentHeight;
            reveal._stable = Math.abs(y - reveal._lastY) < 0.5 && Math.abs(h - reveal._lastH) < 0.5 ? reveal._stable + 1 : 0;
            reveal._lastY = y;
            reveal._lastH = h;
            // three still checks in a row (150 ms), or 2 s whatever happens
            if (reveal._stable >= 3 || ++tries >= 40) {
                stop();
                reveal._land();
            }
        }
    }
    function _land() {
        flickable.contentY = Math.max(0, Math.min(_targetY() - Theme.spacing * 6, flickable.contentHeight - flickable.height));
        _place();
        blink.restart();
    }
    // a row: inside it, shaped like its hover highlight; a group or section: around it
    function _place() {
        const t = _target;
        if (!t)
            return;
        const p = t.mapToItem(flickable.contentItem, 0, 0);
        const row = t.hasOwnProperty("clickable");
        const m = row ? Theme.spacing : -Theme.spacing;
        shade.x = p.x + m;
        shade.y = p.y + m;
        shade.width = t.width - 2 * m;
        shade.height = t.height - 2 * m;
        shade.radius = row ? Theme.card.radius - Theme.spacing : Theme.card.radius + Theme.spacing;
    }
    Timer {
        interval: 50
        repeat: true
        running: blink.running
        onTriggered: reveal._place()
    }

    Rectangle {
        id: shade
        parent: reveal.flickable ? reveal.flickable.contentItem : reveal
        z: 10
        color: Theme.dark ? Theme.alpha("#ffffff", 0.12) : Theme.alpha(Theme.c.accent, 0.12)
        opacity: 0
        visible: opacity > 0
        // one calm blink: in, a moment, out
        SequentialAnimation {
            id: blink
            NumberAnimation { target: shade; property: "opacity"; to: 1; duration: Theme.dur(260); easing.type: Easing.OutCubic }
            PauseAnimation { duration: Theme.reduceMotion ? 1200 : Theme.dur(450) }   // no motion: shown still, then gone
            NumberAnimation { target: shade; property: "opacity"; to: 0; duration: Theme.dur(600); easing.type: Easing.InOutQuad }
        }
    }
}
