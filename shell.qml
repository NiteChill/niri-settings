//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma AppId settings-app
//@ pragma Env QT_QPA_PLATFORMTHEME=xdgdesktopportal
import QtQuick
import Quickshell
import Quickshell.Io
import "theme"
import "pages"
import "services"

// The settings app: one normal window, no title bar from Qt or niri (the app draws its own header, with
// a close button; dragging it moves the window). Its Wayland app id is `settings-app`, matching
// data/settings-app.desktop, so launchers and niri window rules know it. Started by bin/settings, which
// asks a running copy to come forward (IPC `settings open <page> <setting>`) instead of opening a second
// window. SETTINGS_PAGE=<page id> opens on that page, SETTINGS_SETTING=<title> scrolled to that setting. File pickers are the system's own (xdg-desktop-portal, the
// platform theme above): Qt's built-in QML file dialog crashed (Qt 6.11, a segfault in its folder
// breadcrumb bar when clicking a sidebar place).
ShellRoot {
    IpcHandler {
        target: "settings"
        // bring the window forward, on `page` if it's one of the app's pages ("" keeps the current one),
        // scrolled to `setting` (a setting's title, "" = the top)
        function open(page: string, setting: string): void {
            if (page !== "" && app.pages.some(p => p.id === page))
                Nav.go(page, setting);
            Env.read(["niri", "msg", "--json", "windows"], (code, out) => {
                if (code !== 0)
                    return;
                const w = JSON.parse(out).find(w => w.app_id === "settings-app");
                if (w)
                    Env.read(["niri", "msg", "action", "focus-window", "--id", String(w.id)]);
            });
        }
    }
    FloatingWindow {
        id: window
        title: "Settings"
        implicitWidth: 1080
        implicitHeight: 760
        color: Theme.c.background
        // closing the window (the × or the compositor) ends the app
        onVisibleChanged: if (!visible) Qt.quit()

        App {
            id: app
            anchors.fill: parent
            window: window
        }
    }
}
