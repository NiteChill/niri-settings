import QtQuick
import "../theme"

// A level icon drawn like the island's: the whole symbol dimmed (every bar or wave, at the island's
// idle.overlayOpacity), with the real level bright on top. `layers`: the island's drawings from the
// lowest level to the full one (they share one drawing, so they line up); `level`: 0 = none lit, 1 to
// layers.length = that many lit. `alone`: a different icon shown by itself instead (a muted speaker).
// Presets: Theme.wifiLayers (level = bars 0-3), Theme.volumeLayers (level = Theme.volumeLevel(volume)).
Item {
    id: icon

    property var layers: []
    property int level: 0
    property string alone: ""
    property color color: Theme.c.foreground
    property real size: 20

    implicitWidth: size
    implicitHeight: size

    Icon {
        anchors.fill: parent
        visible: icon.alone === "" && icon.layers.length > 0
        name: icon.layers.length ? icon.layers[icon.layers.length - 1] : ""
        size: icon.size
        color: icon.color
        opacity: Theme.layerDim
    }
    Icon {
        anchors.fill: parent
        visible: icon.alone !== "" || icon.level > 0
        name: icon.alone !== "" ? icon.alone : icon.layers[Math.min(icon.level, icon.layers.length) - 1] || ""
        size: icon.size
        color: icon.color
    }
}
