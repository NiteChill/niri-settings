#!/usr/bin/env python3
"""Answers as GNOME Settings, so other apps' "settings" buttons open this app.

GNOME apps don't run a settings command: they ask the session bus for `org.gnome.Settings` and call
`org.gtk.Actions.Activate("launch-panel", [<(panel, [<subpage>...])>], {})` on /org/gnome/Settings
(Files' "Trash Settings" asks for ('privacy', ['usage']), its search settings ('search', ['locations']),
GNOME Shell's menus for 'wifi', 'bluetooth', 'power'...). install.sh points that name at this script
(~/.local/share/dbus-1/services/org.gnome.Settings.service), so the bus starts it on demand: it takes
the name, maps the panel to one of the app's pages (and a setting to scroll to), runs `settings <page>
<setting>`, then exits once nothing has asked for a few seconds (the bus starts it again next time).

Also answers org.freedesktop.Application (Activate / Open / ActivateAction), which some callers use
(`gapplication launch org.gnome.Settings`): the app opens on its current page.

`--open <panel> [sub-page]` opens the app there directly (install.sh's `gnome-control-center` stand-in,
installed only when GNOME Settings itself isn't).
Needs PyGObject (Gio). `settings-gnome-bridge.py --page privacy usage` prints the mapping (to test).
"""
import os
import subprocess
import sys

APP = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SETTINGS = os.path.join(APP, "bin", "settings")
NAME = "org.gnome.Settings"
PATH = "/org/gnome/Settings"
IDLE_EXIT_MS = 5000

# GNOME Settings' panel ids (and sub-pages) -> (our page, a setting's title to scroll to or "").
# A panel listed without a sub-page covers all of its sub-pages that aren't listed.
PANELS = {
    "wifi": ("wifi", ""),
    "network": ("network", ""),
    "wwan": ("network", ""),
    "mobile-broadband": ("network", ""),
    "bluetooth": ("bluetooth", ""),
    "background": ("appearance", "Wallpaper"),
    "appearance": ("appearance", ""),
    "ubuntu": ("appearance", ""),
    "notifications": ("notifications", ""),
    "search": ("search", ""),
    "multitasking": ("windows", ""),
    "applications": ("apps", ""),
    "default-apps": ("apps", "Default apps"),
    "removable-media": ("apps", ""),
    "privacy": ("privacy", ""),
    "privacy/usage": ("privacy", "Trash and temporary files"),
    "privacy/location": ("privacy", "Location"),
    "privacy/screen": ("power", "When you're away"),
    "privacy/screen-lock": ("power", "When you're away"),
    "location": ("privacy", "Location"),
    "usage": ("privacy", "Trash and temporary files"),
    "lock": ("power", "When you're away"),
    "sharing": ("system", ""),
    "sound": ("sound", ""),
    "power": ("power", ""),
    "display": ("displays", ""),
    "color": ("displays", ""),
    "night-light": ("displays", "Night light"),
    "mouse": ("mouse", ""),
    "wacom": ("mouse", ""),
    "keyboard": ("keyboard", ""),
    "printers": ("printers", ""),
    "universal-access": ("accessibility", ""),
    "accessibility": ("accessibility", ""),
    "region": ("system", "Language"),
    "datetime": ("system", "Time zone"),
    "user-accounts": ("system", "Name"),
    "users": ("system", "Name"),
    "info-overview": ("system", ""),
    "about": ("system", ""),
    "system": ("system", ""),
    "system/region": ("system", "Language"),
    "system/datetime": ("system", "Time zone"),
    "system/users": ("system", "Name"),
    "system/about": ("system", ""),
}


def page_for(panel, args):
    """GNOME's panel + its arguments -> (page, setting); ("", "") = just open the app."""
    first = args[0] if args and isinstance(args[0], str) else ""
    return PANELS.get(panel + "/" + first) or PANELS.get(panel) or ("", "")


def open_settings(page="", setting=""):
    env = {k: v for k, v in os.environ.items() if k not in ("QS_CONFIG_PATH", "QS_ICON_THEME", "SETTINGS_PAGE", "SETTINGS_SETTING")}
    args = [SETTINGS] + ([page] if page else []) + ([setting] if page and setting else [])
    subprocess.Popen(args, env=env, start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


XML = """
<node>
  <interface name="org.gtk.Actions">
    <method name="List"><arg type="as" name="list" direction="out"/></method>
    <method name="Describe">
      <arg type="s" name="action_name" direction="in"/>
      <arg type="(bgav)" name="description" direction="out"/>
    </method>
    <method name="DescribeAll"><arg type="a{s(bgav)}" name="descriptions" direction="out"/></method>
    <method name="Activate">
      <arg type="s" name="action_name" direction="in"/>
      <arg type="av" name="parameter" direction="in"/>
      <arg type="a{sv}" name="platform_data" direction="in"/>
    </method>
    <method name="SetState">
      <arg type="s" name="action_name" direction="in"/>
      <arg type="v" name="value" direction="in"/>
      <arg type="a{sv}" name="platform_data" direction="in"/>
    </method>
    <signal name="Changed">
      <arg type="as" name="removals"/>
      <arg type="a{sb}" name="enable_changes"/>
      <arg type="a{sv}" name="state_changes"/>
      <arg type="a{s(bgav)}" name="additions"/>
    </signal>
  </interface>
  <interface name="org.freedesktop.Application">
    <method name="Activate"><arg type="a{sv}" name="platform_data" direction="in"/></method>
    <method name="Open">
      <arg type="as" name="uris" direction="in"/>
      <arg type="a{sv}" name="platform_data" direction="in"/>
    </method>
    <method name="ActivateAction">
      <arg type="s" name="action_name" direction="in"/>
      <arg type="av" name="parameter" direction="in"/>
      <arg type="a{sv}" name="platform_data" direction="in"/>
    </method>
  </interface>
</node>
"""

ACTIONS = ["launch-panel"]


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--page":
        print(page_for(sys.argv[2], sys.argv[3:]))
        return 0
    # `gnome-control-center <panel> [sub-page]` (install.sh's stand-in, for apps that run the command)
    if len(sys.argv) >= 2 and sys.argv[1] == "--open":
        open_settings(*page_for(sys.argv[2], sys.argv[3:])) if len(sys.argv) >= 3 else open_settings()
        return 0

    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    loop = GLib.MainLoop()
    state = {"timer": 0}

    def rearm():
        if state["timer"]:
            GLib.source_remove(state["timer"])
        state["timer"] = GLib.timeout_add(IDLE_EXIT_MS, lambda: (loop.quit(), False)[1])

    def launch_panel(params):
        # params: [(panel, [args...])] (the av of launch-panel, each variant already unpacked)
        panel, args = "", []
        if params:
            p = params[0]
            if isinstance(p, (tuple, list)) and p:
                panel = p[0] if isinstance(p[0], str) else ""
                args = list(p[1]) if len(p) > 1 and isinstance(p[1], (tuple, list)) else []
            elif isinstance(p, str):
                panel = p
        page, setting = page_for(panel, args)
        open_settings(page, setting)

    def on_call(conn, sender, path, iface, method, params, invocation):
        rearm()
        args = params.unpack()
        desc = GLib.Variant("(bgav)", (True, "(sav)", []))
        if iface == "org.gtk.Actions":
            if method == "List":
                return invocation.return_value(GLib.Variant("(as)", (ACTIONS,)))
            if method == "Describe":
                return invocation.return_value(GLib.Variant.new_tuple(desc))
            if method == "DescribeAll":
                return invocation.return_value(GLib.Variant("(a{s(bgav)})", ({a: (True, "(sav)", []) for a in ACTIONS},)))
            if method == "Activate":
                if args[0] == "launch-panel":
                    launch_panel(args[1])
                else:
                    open_settings()
                return invocation.return_value(None)
            if method == "SetState":
                return invocation.return_value(None)
        if iface == "org.freedesktop.Application":
            if method == "ActivateAction" and args[0] == "launch-panel":
                launch_panel(args[1])
            else:
                open_settings()
            return invocation.return_value(None)
        invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)

    info = Gio.DBusNodeInfo.new_for_xml(XML)

    def on_bus(conn, name):
        register = getattr(conn, "register_object_with_closures2", None) or conn.register_object
        for iface in info.interfaces:
            register(PATH, iface, on_call, None, None)

    def on_lost(conn, name):
        # someone else answers as GNOME Settings (the real one is running): leave it to them
        loop.quit()

    Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.NONE, on_bus, None, on_lost)
    rearm()
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
