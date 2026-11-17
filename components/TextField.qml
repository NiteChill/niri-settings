import QtQuick
import "../theme"

// HeroUI's TextField (label + input + description / error). Optional leading icon (`iconName`), a clear
// button (`clearable`), a password field with a show / hide eye (`password`), a trailing text such as a
// unit (`suffix`). `invalid` follows errorMessage unless set. Width: set it, or 256 px by default.
FieldText {
    id: field

    property alias text: input.text
    property string placeholder
    property string iconName
    property string suffix
    property bool clearable: false
    property bool password: false
    property bool invalid: errorMessage !== ""
    property bool readOnly: false
    property alias validator: input.validator
    property alias maximumLength: input.maximumLength
    property alias input: input
    property string variant: "secondary"
    property bool _revealed: false
    signal accepted
    signal edited

    width: Math.round(256 * Math.max(1, Theme.textScale))

    FieldFrame {
        id: frame
        width: field.width
        variant: field.variant
        hovered: hover.hovered
        focused: input.activeFocus
        invalid: field.invalid
        opacity: field.enabled ? 1 : Theme.disabledOpacity

        HoverHandler {
            id: hover
            cursorShape: Qt.IBeamCursor
        }
        TapHandler {
            onTapped: input.forceActiveFocus()
        }

        Row {
            id: lead
            x: Theme.field.paddingX
            anchors.verticalCenter: parent.verticalCenter
            visible: field.iconName !== ""
            Icon {
                name: field.iconName
                size: Theme.field.iconSize
                color: Theme.c.muted
            }
        }
        TextInput {
            id: input
            anchors.left: lead.visible ? lead.right : parent.left
            anchors.leftMargin: lead.visible ? Theme.spacing * 2 : Theme.field.paddingX
            anchors.right: trail.left
            anchors.rightMargin: trail.width > 0 ? Theme.spacing * 2 : Theme.field.paddingX
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.c.foreground
            selectionColor: Theme.alpha(Theme.c.accent, 0.4)
            selectedTextColor: Theme.c.foreground
            font.family: Theme.font.family
            font.pixelSize: Theme.text.sm
            font.variableAxes: ({ "ROND": Theme.font.roundness })
            readOnly: field.readOnly
            echoMode: field.password && !field._revealed ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            activeFocusOnTab: true
            onAccepted: field.accepted()
            onTextEdited: field.edited()
            Keys.onEscapePressed: event => {
                if (field.clearable && text !== "") {
                    text = "";
                    field.edited();
                } else {
                    event.accepted = false;
                }
            }
            Label {
                anchors.fill: parent
                visible: input.text === "" && input.preeditText === ""
                text: field.placeholder
                color: Theme.c.muted
                elide: Text.ElideRight
            }
        }
        Row {
            id: trail
            anchors.right: parent.right
            anchors.rightMargin: width > 0 ? Theme.spacing * 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing
            Label {
                visible: field.suffix !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: field.suffix
                color: Theme.c.muted
                rightPadding: Theme.spacing
            }
            CloseButton {
                visible: field.clearable && input.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    input.text = "";
                    input.forceActiveFocus();
                    field.edited();
                }
            }
            CloseButton {
                visible: field.password
                anchors.verticalCenter: parent.verticalCenter
                iconName: field._revealed ? "visibility_off-fill" : "visibility-fill"
                plain: true
                onClicked: field._revealed = !field._revealed
            }
        }
    }
}
