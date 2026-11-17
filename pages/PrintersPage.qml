import QtQuick
import "../theme"
import "../services"
import "../components"

// Printers: the ones CUPS knows, which is the default, and a way to add one (the system's printer tool,
// or CUPS' own page).
Column {
    id: page
    spacing: Theme.spacing * 8

    property var printers: []
    property string defaultPrinter: ""
    property bool hasTool: false
    function read() {
        Env.readFor(page, ["lpstat", "-e"], (code, out) => page.printers = out.trim().split("\n").filter(l => l));
        Env.readFor(page, ["lpstat", "-d"], (code, out) => {
            const m = /destination: (\S+)/.exec(out);
            page.defaultPrinter = m ? m[1] : "";
        });
    }
    Component.onCompleted: {
        read();
        Env.readFor(page, ["sh", "-c", "command -v system-config-printer"], code => page.hasTool = code === 0);
    }

    Item {
        visible: page.printers.length === 0
        width: parent.width
        height: Theme.spacing * 60
        EmptyState {
            anchors.centerIn: parent
            iconName: "print-fill"
            title: "No printers"
            description: "Network printers usually show up by themselves."
        }
    }
    SettingsGroup {
        visible: page.printers.length > 0
        width: parent.width
        Repeater {
            model: page.printers
            SettingsRow {
                required property string modelData
                title: modelData.replace(/_/g, " ")
                iconName: "print-fill"
                Row {
                    spacing: Theme.spacing * 2
                    Chip {
                        visible: page.defaultPrinter === modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Default"
                        tone: "accent"
                        variant: "soft"
                    }
                    Button {
                        visible: page.defaultPrinter !== modelData
                        size: "sm"
                        variant: "ghost"
                        text: "Make default"
                        onClicked: Env.write(["lpoptions", "-d", modelData], () => page.read())
                    }
                }
            }
        }
    }
    Button {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Add a printer…"
        iconName: "add"
        variant: "secondary"
        onClicked: Env.launch(page.hasTool ? ["system-config-printer"] : ["xdg-open", "http://localhost:631/admin"])
    }
}
