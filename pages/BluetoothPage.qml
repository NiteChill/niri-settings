import QtQuick
import "../theme"
import "../services"
import "../components"

// Bluetooth: the switch, your devices (connect / disconnect by clicking, battery when reported, forget),
// then devices nearby to pair (looks for them only while this page is open).
Column {
    id: page
    spacing: Theme.spacing * 8

    Component.onCompleted: Hw.bluetoothScan = true
    Component.onDestruction: Hw.bluetoothScan = false

    readonly property var mine: Hw.btDevices.filter(d => d.paired)
    readonly property var nearby: Hw.btDevices.filter(d => !d.paired)
    function kindIcon(k) {
        return ({ "headphones": "headphones-fill", "speaker": "speaker-fill", "mouse": "mouse-fill", "keyboard": "keyboard-fill", "gamepad": "sports_esports-fill", "phone": "mobile", "computer": "computer-fill" })[k] || "devices_other-fill";
    }

    SettingsGroup {
        width: parent.width
        SettingsRow {
            title: "Bluetooth"
            description: !Hw.btAvailable ? "No Bluetooth adapter found." : Hw.btEnabled ? "Visible to devices nearby as “" + (Host.prettyName || Host.hostname) + "” while this page is open." : ""
            iconName: "island-bluetooth"
            enabled: Hw.btAvailable
            Switch {
                checked: Hw.btEnabled
                onToggled: Hw.setBluetoothEnabled(checked)
            }
        }
    }

    SettingsGroup {
        visible: Hw.btEnabled
        width: parent.width
        title: "My devices"
        SettingsRow {
            visible: page.mine.length === 0
            title: "No devices yet"
            description: "Put a device in pairing mode: it shows up below."
        }
        Repeater {
            model: KeyedModel {
                values: page.mine
                key: "address"
            }
            SettingsRow {
                required property var model
                readonly property var modelData: model
                title: modelData.name
                description: modelData.busy || (modelData.connected ? "Connected" : "Not connected")
                iconName: page.kindIcon(modelData.kind)
                clickable: modelData.busy === ""
                onClicked: modelData.connected ? Hw.btDisconnect(modelData.address) : Hw.btConnect(modelData.address)
                Row {
                    spacing: Theme.spacing * 2
                    Chip {
                        visible: modelData.battery >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.battery + " %"
                        tone: modelData.battery <= 20 ? "danger" : "default"
                        variant: "soft"
                        iconName: "battery_5_bar"
                    }
                    Spinner {
                        visible: modelData.busy !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        size: "sm"
                        color: Theme.c.accent
                    }
                    Button {
                        size: "sm"
                        variant: "ghost"
                        text: "Forget"
                        onClicked: Hw.btForget(modelData.address)
                    }
                }
            }
        }
    }

    SettingsGroup {
        visible: Hw.btEnabled
        width: parent.width
        title: "Devices nearby"
        description: page.nearby.length === 0 ? "Searching…" : "Devices that ask for a code to type or confirm can't pair yet."
        Repeater {
            model: KeyedModel {
                values: page.nearby
                key: "address"
            }
            SettingsRow {
                required property var model
                readonly property var modelData: model
                title: modelData.name
                description: modelData.busy
                iconName: page.kindIcon(modelData.kind)
                Button {
                    size: "sm"
                    variant: "secondary"
                    text: "Pair"
                    pending: modelData.busy !== ""
                    onClicked: Hw.btConnect(modelData.address)
                }
            }
        }
    }
}
