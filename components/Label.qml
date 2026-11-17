import QtQuick
import "../theme"

// Every text in the app: the theme's font, a size from Theme.text ("xs" ... "3xl"), the foreground color.
// Override only what differs (size, weight, color).
Text {
    property string size: "sm"
    property int weight: Theme.weightNormal

    color: Theme.c.foreground
    font.family: Theme.font.family
    font.pixelSize: Theme.text[size] || Theme.text.sm
    font.weight: weight
    font.variableAxes: ({ "ROND": Theme.font.roundness })
    verticalAlignment: Text.AlignVCenter
}
