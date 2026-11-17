import QtQuick
import QtQuick.Shapes
import "../theme"

// A Material Symbols Rounded icon from assets/icons, drawn as a vector path: sharp at any size, tinted by
// `color` (animatable). `name` is the file name without .svg ("wifi", "notifications-fill"). Fits its box
// (default 20 px), centred.
Item {
    id: icon

    property string name
    property color color: Theme.c.foreground
    property real size: 20

    implicitWidth: size
    implicitHeight: size

    readonly property var glyph: Theme.glyph(name)
    readonly property real gw: glyph ? glyph.w : 1
    readonly property real gh: glyph ? glyph.h : 1
    readonly property real k: Math.min(width / gw, height / gh)

    Shape {
        visible: !!icon.glyph
        x: (icon.width - icon.gw * icon.k) / 2 - (icon.glyph ? icon.glyph.x : 0) * icon.k
        y: (icon.height - icon.gh * icon.k) / 2 - (icon.glyph ? icon.glyph.y : 0) * icon.k
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: icon.color
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule: icon.glyph && icon.glyph.evenOdd ? ShapePath.OddEvenFill : ShapePath.WindingFill
            scale: Qt.size(icon.k, icon.k)
            PathSvg {
                path: icon.glyph ? icon.glyph.path : ""
            }
        }
    }
}
