import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import "../theme"
import "../services"

// The Dynamic Island, shown to people who don't have it yet: stills of the real island (its own pixels,
// captured by tools/capture-island.py into assets/island-shots: the resting island, the search, a
// notification, the music, the battery, quick settings, the time), each at its real size and place
// over your own wallpaper, one after the other with a caption. The dots pick one; hovering holds it.
Item {
    id: gallery

    property bool running: visible && !hover.hovered
    property var shots: []
    property int current: 0
    // the island's top in the gallery, and in the captures
    readonly property real islandTop: 16
    readonly property real capturedTop: shots.length ? Math.min(...shots.map(s => s.y)) : 0

    implicitHeight: 340

    FileView {
        path: Qt.resolvedUrl("../assets/island-shots/shots.json")
        onLoaded: {
            try {
                gallery.shots = JSON.parse(text()).shots;
            } catch (e) {
                console.warn("IslandGallery: no stills: " + e.message);
            }
        }
    }
    Timer {
        running: gallery.running && gallery.shots.length > 1
        interval: 3200
        repeat: true
        onTriggered: gallery.current = (gallery.current + 1) % gallery.shots.length
    }
    HoverHandler {
        id: hover
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.card.radius
        color: "#1b2333"
        Image {
            anchors.fill: parent
            source: Niri.wallpaper ? "file://" + Niri.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1200
            asynchronous: true
        }
        // every still in its place; the current one shown, the others faded out
        Repeater {
            model: gallery.shots
            Image {
                required property var modelData
                required property int index
                source: Qt.resolvedUrl("../assets/island-shots/" + modelData.file)
                x: gallery.width / 2 + modelData.x - modelData.w / 2
                y: gallery.islandTop + modelData.y - gallery.capturedTop
                width: modelData.w
                height: modelData.h
                smooth: true
                mipmap: true
                opacity: index === gallery.current ? 1 : 0
                scale: index === gallery.current ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity {
                    NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // what it is
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: dots.top
        anchors.bottomMargin: 10
        width: caption.implicitWidth + 28
        height: 34
        radius: 17
        color: "#99000000"
        Label {
            id: caption
            anchors.centerIn: parent
            text: gallery.shots.length ? gallery.shots[gallery.current].caption : ""
            color: "#ffffff"
            size: "sm"
        }
    }
    // one dot per still: click to see it
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        spacing: 6
        Repeater {
            model: gallery.shots.length
            Rectangle {
                required property int index
                width: index === gallery.current ? 18 : 7
                height: 7
                radius: 3.5
                color: index === gallery.current ? "#ffffff" : "#77ffffff"
                Behavior on width {
                    Spring {}
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: gallery.current = index
                }
            }
        }
    }
}
