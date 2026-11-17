import QtQuick
import "../theme"

// Mouse wheel scrolling for a Flickable / ListView, at the mouse's scroll speed: put `WheelScroll {
// flickable: view }` inside it. Each notch moves Theme.scroll.notch px times what niri sends (niri
// has already multiplied the wheel by Mouse > Scroll speed), and notches add up: the page glides to
// where all of them lead. Qt's own wheel scrolling restarted its glide on each notch and dropped the
// rest of the previous one, so a fast spin went about as far whatever the scroll speed was.
// Touchpads (a pixel delta, or inside a scroll gesture) pass through to the Flickable: it moves by the
// finger's distance (already multiplied by Touchpad > Scroll speed) and keeps its momentum.
// A control under the pointer that takes the wheel itself (a focused slider or number field:
// `takesWheel: true`) gets it first.
MouseArea {
    id: area

    required property Flickable flickable

    parent: flickable
    anchors.fill: parent
    z: 1000
    acceptedButtons: Qt.NoButton
    // set by a test: wheel events handled
    property int handled: 0

    // the contentY the notches so far lead to
    property real target: 0
    readonly property real minY: flickable.originY - flickable.topMargin
    readonly property real maxY: Math.max(minY, flickable.originY + flickable.contentHeight + flickable.bottomMargin - flickable.height)

    // the deepest item at (x, y) of this area that asks for the wheel
    function wheelTaker(x, y) {
        let item = flickable.contentItem;
        let p = area.mapToItem(item, x, y);
        while (item) {
            if (item.takesWheel === true && item.visible && item.enabled)
                return item;
            const child = item.childAt(p.x, p.y);
            if (!child)
                return null;
            p = item.mapToItem(child, p.x, p.y);
            item = child;
        }
        return null;
    }

    // move by `notches` (1 = one notch down)
    function scrollBy(notches) {
        const from = glide.running ? target : flickable.contentY;
        target = Math.max(minY, Math.min(maxY, from + notches * Theme.scroll.notch));
        glide.stop();
        if (Theme.scroll.glide <= 0) {
            flickable.contentY = target;
            return;
        }
        glide.from = flickable.contentY;
        glide.to = target;
        glide.start();
    }

    onWheel: wheel => {
        const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
        const dy = wheel.angleDelta.y;
        if (touchpad || dy === 0 || !flickable.interactive || wheelTaker(wheel.x, wheel.y)) {
            wheel.accepted = false;
            return;
        }
        // at an end already: let it go on to whatever is behind
        if ((dy > 0 && flickable.contentY <= minY && !glide.running) || (dy < 0 && flickable.contentY >= maxY && !glide.running)) {
            wheel.accepted = false;
            return;
        }
        handled++;
        scrollBy(-dy / 120);
    }

    NumberAnimation {
        id: glide
        target: area.flickable
        property: "contentY"
        duration: Theme.scroll.glide
        easing.type: Easing.OutCubic
    }
    // a drag or a touchpad scroll takes over: forget the glide
    Connections {
        target: area.flickable
        function onMovementStarted() {
            glide.stop();
        }
    }
}
