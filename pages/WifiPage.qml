import QtQuick
import "../theme"
import "../services"
import "../components"

// Wi-Fi: the switch, the network you're on (a hero like the island's Wi-Fi panel), then every network
// nearby: click to join (a password field opens in the row when needed), a connected one offers
// Disconnect / Forget. Scans only while this page is open.
Column {
    id: page
    spacing: Theme.spacing * 8

    property string asking: ""      // the network whose password row is open
    Component.onCompleted: Hw.wifiScan = true
    Component.onDestruction: Hw.wifiScan = false

    // the connected network's bars, for the big symbol (all of it dimmed when there's none)
    readonly property int bars: {
        const n = Hw.wifiNetworks.find(x => x.connected);
        return n ? n.bars : 0;
    }

    // hero: the island's Wi-Fi symbol, its signal bars lit when connected
    Item {
        width: parent.width
        height: Theme.spacing * 44
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing * 3
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.spacing * 22
                height: width
                radius: width / 2
                color: Hw.wifiEnabled ? Theme.c.accentSoft : Theme.c.default
                Behavior on color {
                    ColorAnimation { duration: Theme.motion.slow }
                }
                LayeredIcon {
                    anchors.centerIn: parent
                    layers: Theme.wifiLayers
                    level: Hw.wifiEnabled ? page.bars : 0
                    size: Theme.spacing * 11
                    color: Hw.wifiConnected !== "" ? Theme.c.accent : Theme.c.muted
                    Behavior on color {
                        ColorAnimation { duration: Theme.motion.slow }
                    }
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !Hw.wifiAvailable ? "No Wi-Fi adapter" : !Hw.wifiEnabled ? "Wi-Fi is off" : Hw.wifiConnected !== "" ? Hw.wifiConnected : "Not connected"
                size: "xl"
                weight: Theme.weightSemibold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Hw.wifiConnected !== "" ? "Connected" : Hw.wifiEnabled ? "Pick a network below" : "Turn it on to see networks nearby"
                color: Theme.c.muted
            }
        }
    }

    SettingsGroup {
        width: parent.width
        SettingsRow {
            title: "Wi-Fi"
            iconName: "island-wifi3"
            enabled: Hw.wifiAvailable
            Switch {
                checked: Hw.wifiEnabled
                onToggled: Hw.setWifiEnabled(checked)
            }
        }
        SettingsRow {
            title: "Airplane mode"
            description: "Turns off Wi-Fi and Bluetooth together."
            iconName: "flight"
            Switch {
                checked: !Hw.wifiEnabled && !Hw.btEnabled
                onToggled: {
                    Hw.setWifiEnabled(!checked);
                    Hw.setBluetoothEnabled(!checked);
                }
            }
        }
    }

    SettingsGroup {
        visible: Hw.wifiEnabled
        width: parent.width
        title: "Networks"
        description: Hw.wifiNetworks.length === 0 ? "Searching…" : ""
        Repeater {
            model: KeyedModel {
                values: Hw.wifiNetworks
                key: "name"
            }
            Item {
                id: net
                required property var model
                readonly property var modelData: model
                readonly property bool open: page.asking === modelData.name
                width: parent.width
                height: row.height + (open ? ask.height + Theme.spacing * 4 : 0)
                clip: true
                Behavior on height {
                    Spring {}
                }
                SettingsRow {
                    id: row
                    title: net.modelData.name
                    description: net.modelData.connected ? "Connected" : net.modelData.connecting ? "Connecting…" : net.modelData.failed ? "Couldn't connect" : net.modelData.known ? "Saved" : ""
                    iconLayers: Theme.wifiLayers
                    iconLevel: net.modelData.bars
                    clickable: !net.modelData.connected
                    onClicked: {
                        if (net.modelData.known || !net.modelData.secure)
                            Hw.connectWifi(net.modelData.name, "");
                        else
                            page.asking = net.open ? "" : net.modelData.name;
                    }
                    // the controls a row needs right now, made only then (most rows show only the lock)
                    Row {
                        spacing: Theme.spacing * 2
                        Icon {
                            visible: net.modelData.secure
                            anchors.verticalCenter: parent.verticalCenter
                            name: "lock-fill"
                            size: 16
                            color: Theme.c.muted
                        }
                        Loader {
                            active: net.modelData.connecting
                            visible: active
                            anchors.verticalCenter: parent.verticalCenter
                            sourceComponent: Spinner {
                                size: "sm"
                                color: Theme.c.accent
                            }
                        }
                        Loader {
                            active: net.modelData.connected
                            visible: active
                            sourceComponent: Button {
                                size: "sm"
                                variant: "tertiary"
                                text: "Disconnect"
                                onClicked: Hw.disconnectWifi(net.modelData.name)
                            }
                        }
                        Loader {
                            active: net.modelData.known
                            visible: active
                            sourceComponent: Button {
                                size: "sm"
                                variant: "ghost"
                                text: "Forget"
                                onClicked: Hw.forgetWifi(net.modelData.name)
                            }
                        }
                    }
                }
                // the password, under the row, while joining a secured network
                Loader {
                    id: ask
                    x: Theme.card.padding + 32
                    y: row.height
                    // stays while the row closes, so the field doesn't vanish before the spring
                    active: net.open || net.height > row.height + 1
                    visible: active
                    sourceComponent: Row {
                        spacing: Theme.spacing * 2
                        TextField {
                            id: psk
                            width: Math.min(280, net.width - 200)
                            password: true
                            placeholder: "Password"
                            onAccepted: join.clicked()
                            Component.onCompleted: input.forceActiveFocus()
                        }
                        Button {
                            id: join
                            text: "Join"
                            enabled: psk.text.length >= 8
                            onClicked: {
                                Hw.connectWifi(net.modelData.name, psk.text);
                                page.asking = "";
                            }
                        }
                        Button {
                            text: "Cancel"
                            variant: "ghost"
                            onClicked: page.asking = ""
                        }
                    }
                }
            }
        }
    }
}
