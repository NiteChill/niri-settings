import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"

// A small live picture of the desktop: your wallpaper with a row of niri columns on it, drawn with the
// gaps, corners, border, focus ring and shadows given here (the pages bind them to the settings, so the
// picture follows every slider as you drag). The middle window is the focused one. `columns`: each
// column's width as a share of the screen; `center` puts the focused column in the middle.
Item {
    id: preview

    property real gaps: 16
    property real radius: 0
    property bool borderOn: false
    property real borderWidth: 4
    property color borderColor: "#ffc87f"
    property bool ringOn: true
    property real ringWidth: 4
    property color ringColor: Theme.c.accent
    property bool shadowOn: false
    property real shadowSoftness: 30
    property color shadowColor: "#70000000"
    property var columns: [0.5, 0.5, 0.5]
    property int focused: 1
    property bool center: false
    property bool tabbed: false
    // screen width in layout pixels, to scale gaps and corners like the real thing
    property real screenWidth: Niri.outputs.length ? Niri.outputs[0].width : 1536

    readonly property real k: width / screenWidth

    implicitHeight: width * 0.42
    clip: true

    Image {
        anchors.fill: parent
        source: Niri.wallpaper ? "file://" + Niri.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 900
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: !Niri.wallpaper
        gradient: Gradient {
            GradientStop { position: 0; color: "#2b3a55" }
            GradientStop { position: 1; color: "#0e1320" }
        }
    }

    // the strip of columns, slid so the focused one sits where niri would put it
    Item {
        id: strip
        readonly property real g: preview.gaps * preview.k
        readonly property var widths: preview.columns.map(p => Math.max(24, p * (preview.width - g) - g))
        readonly property real focusX: {
            let x = g;
            for (let i = 0; i < preview.focused; i++)
                x += widths[i] + g;
            return x;
        }
        x: preview.center ? (preview.width - widths[preview.focused]) / 2 - focusX : 0
        y: 0
        height: preview.height
        Behavior on x {
            Spring {}
        }

        Repeater {
            model: preview.columns.length
            Item {
                id: col
                required property int index
                readonly property bool isFocused: index === preview.focused
                x: {
                    let x = strip.g;
                    for (let i = 0; i < index; i++)
                        x += strip.widths[i] + strip.g;
                    return x;
                }
                y: strip.g
                width: strip.widths[index]
                height: preview.height - 2 * strip.g
                Behavior on x {
                    Spring {}
                }
                Behavior on width {
                    Spring {}
                }

                RectangularShadow {
                    anchors.fill: win
                    visible: preview.shadowOn
                    radius: win.radius
                    blur: preview.shadowSoftness * preview.k * 1.5
                    offset.y: 5 * preview.k
                    color: preview.shadowColor
                }
                // focus ring / border, outside the window like niri's
                Rectangle {
                    readonly property real w: (col.isFocused && preview.ringOn ? preview.ringWidth : preview.borderOn ? preview.borderWidth : 0) * preview.k
                    anchors.fill: win
                    anchors.margins: -w
                    radius: win.radius + w
                    visible: w > 0
                    color: col.isFocused && preview.ringOn ? preview.ringColor : preview.borderColor
                    opacity: col.isFocused || !preview.ringOn ? 1 : 0.6
                }
                Rectangle {
                    id: win
                    anchors.fill: parent
                    radius: preview.radius * preview.k
                    color: Theme.dark ? "#1d1d21" : "#fafafa"
                    clip: true
                    Behavior on radius {
                        Spring {}
                    }
                    // something that reads as an app: a toolbar and a few lines
                    Column {
                        x: 10 * preview.k * 3
                        y: 10 * preview.k * 3
                        width: parent.width - 2 * x
                        spacing: 10 * preview.k * 2
                        Rectangle {
                            width: parent.width
                            height: 18 * preview.k * 2
                            radius: height / 2
                            color: Theme.alpha(Theme.c.foreground, 0.08)
                        }
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: parent.width * [0.9, 0.7, 0.8, 0.5][index]
                                height: 8 * preview.k * 2
                                radius: height / 2
                                color: Theme.alpha(Theme.c.foreground, col.isFocused ? 0.14 : 0.08)
                            }
                        }
                    }
                    // tab indicator for a tabbed column
                    Rectangle {
                        visible: preview.tabbed
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height * 0.4
                        radius: 2
                        color: col.isFocused ? preview.ringColor : Theme.alpha(Theme.c.foreground, 0.3)
                    }
                }
            }
        }
    }
}
