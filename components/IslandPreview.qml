import QtQuick
import QtQuick.Effects
import "../services"

// The island as it really looks (pictures rendered from the island itself, in assets/previews) at the
// top of your own wallpaper, zoomed in. `shape`: square / soft / round / full; `attached`: glued to the
// top edge; `blur`: the translucent island over a blurred patch of the wallpaper, like niri draws it.
Item {
    id: preview

    property string shape: "full"
    property bool attached: false
    property bool blur: false
    // how much of the island's width the tile shows around it (1 = edge to edge)
    property real islandShare: 0.86

    readonly property string file: Qt.resolvedUrl("../assets/previews/island-" + shape + (attached ? "-attached" : "") + (blur ? "-blur" : "") + ".png")
    // the pictures are 500 x 92 (2x); the wallpaper is scaled by the same amount as the island
    readonly property real k: width * islandShare / 500
    clip: true

    Image {
        id: wall
        source: Niri.wallpaper ? "file://" + Niri.wallpaper : ""
        // the screen, at the island's zoom: a 1536 px wide screen is 3072 px in the 2x pictures
        width: 3072 * preview.k
        height: width * 10 / 16
        x: (preview.width - width) / 2
        fillMode: Image.PreserveAspectCrop
        verticalAlignment: Image.AlignTop
        sourceSize.width: 1200
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: !Niri.wallpaper
        gradient: Gradient {
            GradientStop { position: 0; color: "#46608c" }
            GradientStop { position: 1; color: "#1b2333" }
        }
    }
    Item {
        id: box
        width: 500 * preview.k
        height: 92 * preview.k
        x: (preview.width - width) / 2
        // the island's own gap above it is in the picture
        y: 0

        Item {
            id: under
            anchors.fill: parent
            visible: false
            layer.enabled: preview.blur
            Image {
                source: wall.source
                width: wall.width
                height: wall.height
                x: wall.x - box.x
                y: wall.y - box.y
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Image.AlignTop
                sourceSize.width: 1200
            }
        }
        Image {
            id: mask
            anchors.fill: parent
            source: preview.file
            visible: false
            layer.enabled: preview.blur
        }
        MultiEffect {
            anchors.fill: parent
            visible: preview.blur
            source: under
            blurEnabled: true
            blur: 1
            blurMax: 40
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.01
            maskSpreadAtMin: 1
        }
        Image {
            anchors.fill: parent
            source: preview.file
            smooth: true
            mipmap: true
        }
    }
}
