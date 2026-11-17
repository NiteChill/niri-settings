#!/usr/bin/env python3
"""What this computer has and lacks for the app: `settings --doctor`.

Two kinds of things:
  needed    the app doesn't open (or can't save anything) without them: Quickshell 0.3 with its
            modules, niri, gsettings + dconf and the desktop's setting schemas
  features  one page or one setting uses them; without them that part can't work (the rest does)

Each missing thing comes with the package to install on this distro (from /etc/os-release), and a single
install command for all of them at the end. Things that only make sense on some computers (brightness
without a backlight, fingerprints) are skipped when the hardware isn't there.

  settings --doctor           readable report; exit code 1 when something needed is missing
  settings --doctor --json    the same as JSON, for the app: [{id, name, needed, ok, skipped, detail,
                              pages, package, url, note, install}] (install = the command that adds the
                              package on this distro, "" when there's none to run)
  --quick                     skip what the running app already proves (Quickshell and its modules,
                              niri): what the app itself asks (services/Deps.qml), ~0.1 s
  SETTINGS_PRETEND_MISSING=a,b   report these ids as missing (to see the app without them)

Nothing is installed or changed: it only looks (commands on PATH, D-Bus names, gsettings schemas,
fonts, and Quickshell loading a tiny config that imports the modules the app uses).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

APP = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))

# ---- this distro ----


def distro():
    """'fedora' / 'arch' / 'debian' / 'suse' / '' from /etc/os-release (ID, then ID_LIKE)."""
    info = {}
    try:
        with open("/etc/os-release") as f:
            for line in f:
                k, _, v = line.strip().partition("=")
                info[k] = v.strip('"')
    except OSError:
        return ""
    for name in [info.get("ID", "")] + info.get("ID_LIKE", "").split():
        for family, ids in FAMILIES.items():
            if name in ids:
                return family
    return ""


FAMILIES = {
    "fedora": {"fedora", "rhel", "centos", "nobara", "ultramarine"},
    "arch": {"arch", "endeavouros", "manjaro", "cachyos", "garuda", "artix"},
    "debian": {"debian", "ubuntu", "linuxmint", "pop", "elementary", "neon"},
    "suse": {"opensuse", "opensuse-tumbleweed", "opensuse-leap", "suse", "sles"},
}
INSTALL = {
    "fedora": "sudo dnf install",
    "arch": "sudo pacman -S --needed",
    "debian": "sudo apt install",
    "suse": "sudo zypper install",
}

# ---- what to look for ----
# package: per distro family ("" = no package there: see url); a plain string = the same name everywhere


def pkg(default, **per):
    return {f: per.get(f, default) for f in FAMILIES}


CHECKS = [
    # -- needed --
    {"id": "quickshell", "name": "Quickshell 0.3 or newer", "needed": True, "pages": [],
     "package": pkg("quickshell", debian="", suse=""), "url": "https://quickshell.org",
     "note": {"fedora": "from the COPR: sudo dnf copr enable errornointernet/quickshell",
              "arch": "from the AUR (quickshell)"}},
    {"id": "qsModules", "name": "Quickshell's Wi-Fi, Bluetooth, sound and power modules", "needed": True, "pages": [],
     "package": pkg(""), "url": "https://quickshell.org"},
    {"id": "niri", "name": "niri", "needed": True, "pages": [], "package": pkg("niri", debian="", suse="niri"),
     "url": "https://github.com/YaLTeR/niri"},
    {"id": "gsettings", "name": "gsettings", "needed": True, "pages": [],
     "package": pkg("glib2", debian="libglib2.0-bin", suse="glib2-tools")},
    {"id": "dconf", "name": "dconf", "needed": True, "pages": [], "package": pkg("dconf", debian="dconf-cli")},
    {"id": "schemas", "name": "the desktop's setting schemas", "needed": True, "pages": [],
     "package": pkg("gsettings-desktop-schemas")},
    {"id": "python3", "name": "Python 3", "needed": True, "pages": [], "package": pkg("python3", arch="python")},
    # -- features --
    {"id": "networkmanager", "name": "NetworkManager", "pages": ["Wi-Fi", "Network"],
     "package": pkg("NetworkManager", arch="networkmanager", debian="network-manager")},
    {"id": "bluez", "name": "BlueZ (Bluetooth)", "pages": ["Bluetooth"], "package": pkg("bluez")},
    {"id": "pipewire", "name": "PipeWire", "pages": ["Sound"],
     "package": pkg("pipewire-utils", arch="pipewire", debian="pipewire-bin", suse="pipewire-tools")},
    {"id": "wireplumber", "name": "WirePlumber's wpctl", "pages": ["Keyboard > Shortcuts (volume keys)"],
     "package": pkg("wireplumber")},
    {"id": "upower", "name": "UPower", "pages": ["Power (battery)"], "package": pkg("upower")},
    {"id": "powerprofiles", "name": "power profiles", "pages": ["Power (power mode)"],
     "package": pkg("power-profiles-daemon", fedora="tuned-ppd")},
    {"id": "brightnessctl", "name": "brightnessctl", "pages": ["Displays (brightness)", "Keyboard > Shortcuts (brightness keys)"],
     "package": pkg("brightnessctl")},
    {"id": "swaybg", "name": "swaybg", "pages": ["Appearance (wallpaper)"], "package": pkg("swaybg")},
    {"id": "swayidle", "name": "swayidle", "pages": ["Power (blank screen and sleep)"], "package": pkg("swayidle")},
    {"id": "swaylock", "name": "swaylock", "pages": ["Power (lock when the screen turns off)"], "package": pkg("swaylock")},
    {"id": "wlsunset", "name": "wlsunset", "pages": ["Displays (night light)"], "package": pkg("wlsunset")},
    {"id": "accounts", "name": "AccountsService", "pages": ["System > Users (your name and picture)"], "package": pkg("accountsservice")},
    {"id": "timedate", "name": "systemd's time, region and name services", "pages": ["System (device name, date and time, language, formats)"],
     "package": pkg("systemd")},
    {"id": "udev", "name": "udev", "pages": ["Mouse & Touchpad (device names)"], "package": pkg("systemd-udev", arch="systemd", debian="udev", suse="udev")},
    {"id": "fprintd", "name": "fprintd", "pages": ["Privacy (fingerprints)"], "package": pkg("fprintd")},
    {"id": "cups", "name": "CUPS", "pages": ["Printers"], "package": pkg("cups-client", arch="cups")},
    {"id": "printerTool", "name": "the printer setup tool", "pages": ["Printers (add a printer)"],
     "package": pkg("system-config-printer")},
    {"id": "xdgutils", "name": "xdg-utils", "pages": ["Apps (default apps)", "links that open in the browser"],
     "package": pkg("xdg-utils")},
    {"id": "fontconfig", "name": "fontconfig", "pages": ["Appearance (font)"], "package": pkg("fontconfig")},
    {"id": "playerctl", "name": "playerctl", "pages": ["Keyboard > Shortcuts (music keys)"], "package": pkg("playerctl")},
    {"id": "gi", "name": "PyGObject", "pages": ["other apps' settings buttons (Files' Trash Settings...) opening this app"],
     "package": pkg("python3-gobject", arch="python-gobject", debian="python3-gi")},
    {"id": "font", "name": "the Google Sans Flex font", "pages": ["the app's look (another font is used without it)"],
     "package": pkg(""), "url": "https://fonts.google.com/specimen/Google+Sans+Flex"},
    {"id": "island", "name": "the Dynamic Island", "pages": ["Dynamic Island", "Search", "island settings on other pages"],
     "package": pkg(""), "url": ""},
]

# ---- probes ----


def has(cmd):
    return shutil.which(cmd) is not None


def run(args, timeout=5, env=None):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
        return p.returncode, p.stdout + p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return -1, str(e)


_bus = None


def bus_names():
    """Names on the system bus, running or startable on demand."""
    global _bus
    if _bus is None:
        code, out = run(["busctl", "--system", "--no-pager", "--no-legend", "list"])
        _bus = {line.split()[0] for line in out.splitlines() if line.strip()} if code == 0 else set()
    return _bus


def on_bus(*names):
    return any(n in bus_names() for n in names)


def schemas_missing():
    code, out = run(["gsettings", "list-schemas"])
    have = set(out.split()) if code == 0 else set()
    want = ["org.gnome.desktop.interface", "org.gnome.desktop.notifications", "org.gnome.desktop.privacy",
            "org.gnome.desktop.sound", "org.gnome.desktop.a11y.applications", "org.gnome.desktop.a11y.interface",
            "org.gnome.system.location", "org.gnome.system.proxy"]
    return [s for s in want if s not in have]


def qs_version():
    code, out = run(["qs", "--version"])
    m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", out) if code == 0 else None
    return tuple(int(x or 0) for x in m.groups()) if m else None


QS_MODULES = ["Quickshell.Io", "Quickshell.Widgets", "Quickshell.Wayland", "Quickshell.Networking",
              "Quickshell.Bluetooth", "Quickshell.Services.Pipewire", "Quickshell.Services.UPower"]


def qs_try(folder, env, timeout=10):
    """Start Quickshell on `folder` and read its log until the config has loaded or failed, then stop it
    (it keeps running after loading: Qt.quit() doesn't end it). -> the log so far."""
    import select
    import time
    try:
        p = subprocess.Popen(["qs", "-n", "-p", folder], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             stdin=subprocess.DEVNULL, text=True, env=env)
    except OSError as e:
        return str(e)
    out = ""
    end = time.monotonic() + timeout
    try:
        while time.monotonic() < end:
            ready, _, _ = select.select([p.stdout], [], [], max(0, end - time.monotonic()))
            if not ready:
                break
            line = p.stdout.readline()
            if not line:
                break
            out += line
            if "settings-doctor-loaded" in line or "Configuration Loaded" in line:
                break
            # a failure prints its details after this line: read on a little longer for them
            if "Failed to load configuration" in line:
                end = min(end, time.monotonic() + 1.5)
    finally:
        p.terminate()
        try:
            rest, _ = p.communicate(timeout=3)
            out += rest or ""
        except subprocess.TimeoutExpired:
            p.kill()
    return out


def qs_modules_missing():
    """Load a tiny config importing every module the app uses; drop each import Quickshell can't find and
    try again, so all the missing ones are named (not just the first)."""
    missing = []
    with tempfile.TemporaryDirectory(prefix="settings-doctor-") as d:
        for _ in range(len(QS_MODULES) + 1):
            mods = [m for m in QS_MODULES if m not in missing]
            with open(os.path.join(d, "shell.qml"), "w") as f:
                f.write("import QtQuick\nimport Quickshell\n" + "".join("import %s\n" % m for m in mods)
                        + 'ShellRoot { Component.onCompleted: { console.warn("settings-doctor-loaded"); Qt.quit() } }\n')
            env = dict(os.environ, QS_NO_RELOAD_POPUP="1")
            env.pop("QS_CONFIG_PATH", None)
            out = qs_try(d, env)
            if "settings-doctor-loaded" in out:
                return missing
            found = [m for m in mods if re.search(r'module "?%s"? is not installed' % re.escape(m), out)]
            if not found:
                return missing + ["(Quickshell didn't load a test config: %s)" % out.strip().splitlines()[-1][:120] if out.strip() else "(Quickshell didn't start)"]
            missing += found
    return missing


def has_backlight():
    try:
        return bool(os.listdir("/sys/class/backlight"))
    except OSError:
        return False


def has_battery():
    try:
        return any(n.startswith("BAT") for n in os.listdir("/sys/class/power_supply"))
    except OSError:
        return False


def has_font(family):
    code, out = run(["fc-list", ":", "family"])
    return code == 0 and any(family.lower() in line.lower() for line in out.splitlines())


def island_dir():
    return os.environ.get("ISLAND_DIR") or os.path.expanduser("~/.config/quickshell")


PRETEND = {s.strip() for s in os.environ.get("SETTINGS_PRETEND_MISSING", "").split(",") if s.strip()}


def probe(check, quick=False):
    """-> (ok, skipped, detail)"""
    i = check["id"]
    if i in PRETEND:
        return False, False, "pretending it's missing (SETTINGS_PRETEND_MISSING)"
    if quick and i in ("quickshell", "qsModules", "niri"):
        return True, False, "the app is running"
    if i == "quickshell":
        if not has("qs"):
            return False, False, "not installed"
        v = qs_version()
        if v is None:
            return False, False, "installed, but its version couldn't be read"
        text = ".".join(map(str, v))
        return v >= (0, 3), False, text if v >= (0, 3) else text + " is too old"
    if i == "qsModules":
        if not has("qs"):
            return False, True, "needs Quickshell first"
        missing = qs_modules_missing()
        return not missing, False, ("missing: " + ", ".join(missing)) if missing else ""
    if i == "niri":
        if not has("niri"):
            return False, False, "not installed"
        code, out = run(["niri", "--version"])
        running = bool(os.environ.get("NIRI_SOCKET"))
        return True, False, (out.strip() or "installed") + ("" if running else " (not the running desktop: changes apply once you use niri)")
    if i in ("gsettings", "dconf", "python3"):
        return has(i), False, "" if has(i) else "not installed"
    if i == "schemas":
        if not has("gsettings"):
            return False, True, "needs gsettings first"
        missing = schemas_missing()
        return not missing, False, ("missing: " + ", ".join(missing)) if missing else ""
    if i == "networkmanager":
        ok = has("nmcli") and on_bus("org.freedesktop.NetworkManager")
        return ok, False, "" if ok else ("not running" if has("nmcli") else "not installed")
    if i == "bluez":
        return on_bus("org.bluez"), False, "" if on_bus("org.bluez") else "not installed or not running"
    if i == "pipewire":
        return has("pw-play"), False, "" if has("pw-play") else "pw-play not found"
    if i == "wireplumber":
        return has("wpctl"), False, "" if has("wpctl") else "not installed"
    if i == "upower" and not has_battery():
        return on_bus("org.freedesktop.UPower"), True, "no battery on this computer"
    if i == "upower":
        return on_bus("org.freedesktop.UPower"), False, "" if on_bus("org.freedesktop.UPower") else "not installed or not running"
    if i == "powerprofiles":
        ok = on_bus("net.hadess.PowerProfiles", "org.freedesktop.UPower.PowerProfiles")
        return ok, False, "" if ok else "no power profile service"
    if i == "brightnessctl":
        if not has_backlight():
            return has("brightnessctl"), True, "no built-in screen brightness on this computer"
        return has("brightnessctl"), False, "" if has("brightnessctl") else "not installed"
    if i in ("swaybg", "swayidle", "swaylock", "wlsunset", "playerctl"):
        return has(i), False, "" if has(i) else "not installed"
    if i == "accounts":
        return on_bus("org.freedesktop.Accounts"), False, "" if on_bus("org.freedesktop.Accounts") else "not installed or not running"
    if i == "timedate":
        cmds = [c for c in ("timedatectl", "localectl", "hostnamectl") if not has(c)]
        return not cmds, False, ("missing: " + ", ".join(cmds)) if cmds else ""
    if i == "udev":
        return has("udevadm"), False, "" if has("udevadm") else "not installed"
    if i == "fprintd":
        if not has("fprintd-list"):
            return False, False, "not installed (only needed with a fingerprint reader)"
        return True, False, ""
    if i == "cups":
        return has("lpstat"), False, "" if has("lpstat") else "not installed"
    if i == "printerTool":
        return has("system-config-printer"), False, "" if has("system-config-printer") else "not installed (the printer page opens CUPS in the browser instead)"
    if i == "xdgutils":
        cmds = [c for c in ("xdg-open", "xdg-mime") if not has(c)]
        return not cmds, False, ("missing: " + ", ".join(cmds)) if cmds else ""
    if i == "fontconfig":
        return has("fc-list"), False, "" if has("fc-list") else "not installed"
    if i == "font":
        if not has("fc-list"):
            return False, True, "needs fontconfig first"
        return has_font("Google Sans Flex"), False, "" if has_font("Google Sans Flex") else "not installed"
    if i == "gi":
        code, _ = run(["python3", "-c", "import gi; gi.require_version('Gio', '2.0'); from gi.repository import Gio"])
        return code == 0, False, "" if code == 0 else "not installed"
    if i == "island":
        ok = os.path.isfile(os.path.join(island_dir(), "config", "schema.json"))
        return ok, False, "" if ok else "not installed (its pages show what it is instead)"
    return False, True, "unknown check"


# ---- report ----


def main():
    as_json = "--json" in sys.argv
    quick = "--quick" in sys.argv
    family = distro()
    results = []
    for c in CHECKS:
        ok, skipped, detail = probe(c, quick)
        package = c["package"].get(family, "") if family else ""
        note = c.get("note", {}).get(family, "")
        results.append({"id": c["id"], "name": c["name"], "needed": c.get("needed", False), "ok": ok,
                        "skipped": skipped, "detail": detail, "pages": c["pages"], "package": package,
                        "url": c.get("url", ""), "note": note,
                        "install": (INSTALL[family] + " " + package) if package and family and not note else ""})
    if as_json:
        print(json.dumps(results, indent=2))
        return 1 if any(r["needed"] and not r["ok"] for r in results) else 0

    tty = sys.stdout.isatty()
    paint = (lambda code, s: "\033[%sm%s\033[0m" % (code, s)) if tty else (lambda code, s: s)
    green, red, yellow, grey, bold = (lambda s: paint("32", s)), (lambda s: paint("31", s)), (lambda s: paint("33", s)), (lambda s: paint("90", s)), (lambda s: paint("1", s))

    def line(r):
        if r["ok"]:
            mark = green("✓")
        elif r["skipped"]:
            mark = grey("–")
        else:
            mark = red("✗") if r["needed"] else yellow("!")
        text = "  %s %s" % (mark, r["name"])
        if r["detail"]:
            text += grey("  " + r["detail"])
        print(text)
        if not r["ok"] and not r["skipped"]:
            if r["pages"]:
                print(grey("      used by: " + ", ".join(r["pages"])))
            how = r["note"] or (("package: " + r["package"]) if r["package"] else "") or r["url"]
            if how:
                print(grey("      get it: " + how))

    print(bold("Settings: what this computer has") + grey("  (%s)" % (family or "unknown distro")))
    print()
    print(bold("Needed to open the app"))
    for r in results:
        if r["needed"]:
            line(r)
    print()
    print(bold("Used by some pages"))
    for r in results:
        if not r["needed"]:
            line(r)

    missing = [r for r in results if not r["ok"] and not r["skipped"]]
    packages = []
    for r in missing:
        if r["package"] and not r["note"] and r["package"] not in packages:
            packages.append(r["package"])
    print()
    if not missing:
        print(green("Everything's here."))
    else:
        needed = [r for r in missing if r["needed"]]
        if needed:
            print(red("%d needed thing%s missing: the app won't work until %s installed." % (len(needed), "" if len(needed) == 1 else "s", "it's" if len(needed) == 1 else "they're")))
        others = len(missing) - len(needed)
        if others:
            print(yellow("%d optional thing%s missing: the pages listed above can't do everything." % (others, "" if others == 1 else "s")))
        if packages and family:
            print()
            print("Install the missing packages with:")
            print("  " + INSTALL[family] + " " + " ".join(packages))
        for r in missing:
            if r["note"]:
                print("  " + r["name"] + ": " + r["note"])
            elif not r["package"] and r["url"]:
                print("  " + r["name"] + ": " + r["url"])
    return 1 if any(r["needed"] and not r["ok"] for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
