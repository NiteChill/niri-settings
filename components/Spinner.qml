import QtQuick
import QtQuick.Shapes
import "../theme"

// HeroUI's spinner: a ring fading from clear to `color` all the way round, turning every 0.75 s.
// Sizes: sm 16, md 24, lg 32, xl 40.
Item {
    id: spinner

    property string size: "md"
    property color color: Theme.c.foreground
    property bool running: visible

    readonly property real px: ({ "sm": 16, "md": 24, "lg": 32, "xl": 40 })[size] || 24
    readonly property real thickness: px / 8
    implicitWidth: px
    implicitHeight: px

    Shape {
        id: ring
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: spinner.px / 2
                centerY: spinner.px / 2
                angle: 90
                GradientStop { position: 0; color: spinner.color }
                GradientStop { position: 1; color: Theme.alpha(spinner.color, 0) }
            }
            // a ring: the outer circle, then the inner one the other way round
            PathSvg {
                readonly property real r: spinner.px / 2
                readonly property real ri: r - spinner.thickness
                path: "M " + 2 * r + " " + r + " A " + r + " " + r + " 0 1 1 0 " + r + " A " + r + " " + r + " 0 1 1 " + 2 * r + " " + r
                    + " M " + (r + ri) + " " + r + " A " + ri + " " + ri + " 0 1 0 " + (r - ri) + " " + r + " A " + ri + " " + ri + " 0 1 0 " + (r + ri) + " " + r + " Z"
            }
        }
        // the bright end is rounded, like a stroke's cap
        Rectangle {
            x: spinner.px / 2 - spinner.thickness / 2
            y: 0
            width: spinner.thickness
            height: spinner.thickness
            radius: width / 2
            color: spinner.color
        }
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: Theme.motion.spin
            loops: Animation.Infinite
            running: spinner.running
        }
    }
}
