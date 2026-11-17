import QtQuick
import Quickshell
import "../theme"
import "../services"

// Shown in place of settings that can't work on this computer because something they need isn't installed
// (Deps: `settings --doctor`). `needs`: the doctor's ids ("wlsunset"); `what`: the feature, in the
// person's words ("Night light"). Offers to install it (a terminal opens; the page fills in once it's
// there), or, when that isn't possible here, to copy what's needed for whoever can.
// The controls it replaces read `Deps.has(...)` for their own `visible` / `enabled`.
Banner {
    id: missing

    property var needs: []
    property string what
    // a short line on what's lost, when the title alone doesn't say it
    property string explain: ""

    readonly property var gone: Deps.lacks(needs)
    readonly property bool installing: Deps.isInstalling(needs)
    readonly property bool installable: Deps.canInstall(needs)
    property bool copied: false

    visible: gone.length > 0
    tone: "default"
    iconName: "download-fill"
    title: what + " isn't available yet"
    description: installing ? "Finish installing in the window that opened. This page updates by itself once it's done." : (explain ? explain + " " : "") + (installable ? "It needs a small extra program that isn't on this computer yet." : copied ? "Copied. Send it to whoever looks after this computer, or look it up for your system." : "It needs a small extra program that isn't on this computer, and Settings can't add it here.")
    actionText: installing ? "" : installable ? "Install…" : "Copy what's needed"
    onAction: {
        if (installable) {
            Deps.install(needs);
        } else {
            Quickshell.clipboardText = Deps.describe(needs);
            copied = true;
        }
    }
}
