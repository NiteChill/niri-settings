pragma Singleton
import QtQuick
import Quickshell

// Which page is open: the sidebar and the pages both use it, so a page can send you to another one
// (Nav.go("power")). Starts on SETTINGS_PAGE when set (bin/settings <page>, the launcher's actions).
// go(page, setting) also scrolls to that setting (a row or group's title) and highlights it: the
// sidebar's search and the island's launcher send you straight to it (SETTINGS_SETTING at launch).
Singleton {
    id: nav
    property string page: Quickshell.env("SETTINGS_PAGE") || "wifi"
    property string setting: Quickshell.env("SETTINGS_SETTING") || ""
    // bumped on every request, so asking for the same setting again still scrolls to it
    property int request: setting !== "" ? 1 : 0
    function go(p, s) {
        // the setting first: changing the page loads it right away, and it looks for the setting then
        setting = s || "";
        page = p;
        if (setting !== "")
            request++;
    }
}
