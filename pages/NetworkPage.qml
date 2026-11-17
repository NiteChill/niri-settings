import QtQuick
import QtQuick.Dialogs
import "../theme"
import "../services"
import "../components"

// Network: wired connections, VPNs (on / off, import a WireGuard .conf or OpenVPN .ovpn), the proxy, and
// the details of whatever you're connected through (advanced).
Column {
    id: page
    Component.onDestruction: Hw.netWatch = false
    spacing: Theme.spacing * 8

    readonly property var wired: Hw.netDevices.filter(d => d.type === "ethernet")
    readonly property var vpns: Hw.connections.filter(c => c.type === "vpn" || c.type === "wireguard")
    readonly property var active: Hw.netDevices.find(d => d.state === "connected" && (d.type === "wifi" || d.type === "ethernet")) || null
    property var details: ({})
    // the answer can come back after the page is gone: check it still exists
    onActiveChanged: if (active) Hw.deviceDetails(active.device, d => { if (page !== null) page.details = d; })
    Component.onCompleted: Hw.netWatch = true

    SettingsGroup {
        width: parent.width
        title: "Wired"
        SettingsRow {
            visible: page.wired.length === 0
            title: "No cable port"
            description: "Plug in an Ethernet adapter to use a wired connection."
            iconName: "cable"
        }
        Repeater {
            model: page.wired
            SettingsRow {
                required property var modelData
                title: modelData.connection || modelData.device
                description: modelData.state === "connected" ? "Connected" : modelData.state === "unavailable" ? "Cable unplugged" : modelData.state
                iconName: "cable"
                Chip {
                    text: modelData.state === "connected" ? "Connected" : "Off"
                    tone: modelData.state === "connected" ? "success" : "default"
                    variant: "soft"
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "VPN"
        SettingsRow {
            visible: page.vpns.length === 0
            title: "No VPN yet"
            description: "Import a WireGuard (.conf) or OpenVPN (.ovpn) file from your provider."
            iconName: "vpn_key-fill"
        }
        Repeater {
            model: page.vpns
            SettingsRow {
                required property var modelData
                title: modelData.name
                description: modelData.type === "wireguard" ? "WireGuard" : "VPN"
                iconName: "vpn_key-fill"
                Row {
                    spacing: Theme.spacing * 2
                    Button {
                        size: "sm"
                        variant: "ghost"
                        iconName: "delete-fill"
                        onClicked: Hw.deleteConnection(modelData.uuid)
                    }
                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: modelData.active
                        onToggled: Hw.connectionUp(modelData.uuid, checked)
                    }
                }
            }
        }
        SettingsRow {
            title: "Add a VPN"
            Button {
                text: "Import file…"
                iconName: "add"
                variant: "secondary"
                size: "sm"
                onClicked: picker.open()
            }
        }
    }
    FileDialog {
        id: picker
        title: "VPN configuration"
        nameFilters: ["VPN files (*.conf *.ovpn)"]
        onAccepted: Hw.importVpn(selectedFile.toString().replace("file://", ""))
    }

    SettingsGroup {
        width: parent.width
        title: "Proxy"
        SettingsRow {
            title: "Proxy"
            description: "Most people don't need this. A proxy sends your internet traffic through another computer, which some workplaces and schools require."
            Select {
                width: Math.round(180 * Math.max(1, Theme.textScale))
                options: [{ "value": "none", "label": "Off" }, { "value": "auto", "label": "Automatic" }, { "value": "manual", "label": "Manual" }]
                value: Desktop.get("proxy", "mode", "none")
                onActivated: v => Desktop.set("proxy", "mode", v)
            }
        }
    }

    SettingsGroup {
        visible: page.active !== null
        width: parent.width
        title: "Details"
        description: page.active ? "Through " + page.active.device + " (" + page.active.connection + ")" : ""
        Repeater {
            model: [["IP address", "IP4.ADDRESS[1]"], ["Router", "IP4.GATEWAY"], ["DNS", "IP4.DNS[1]"], ["IPv6", "IP6.ADDRESS[1]"], ["Hardware address", "GENERAL.HWADDR"]]
            SettingsRow {
                required property var modelData
                visible: (page.details[modelData[1]] || "") !== ""
                title: modelData[0]
                Label {
                    text: (page.details[modelData[1]] || "").replace(/\/\d+$/, "")
                    color: Theme.c.muted
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
