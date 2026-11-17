#!/bin/sh
# Adds the app for this user: the desktop entry, the icon, a `settings` command, and the app as the one
# other apps open for their settings (it answers as GNOME Settings on the session bus, plus a
# `gnome-control-center` stand-in when GNOME Settings isn't installed); then says what this computer still
# lacks for it (`settings --doctor`; installing never fails on that).
# Run it again after moving this folder. `./install.sh --uninstall` removes all of it.
set -e
dir=$(dirname "$(readlink -f "$0")")
data=${XDG_DATA_HOME:-$HOME/.local/share}
apps=$data/applications
icons=$data/icons/hicolor/scalable/apps
bin=$HOME/.local/bin
# other apps' "settings" buttons (Files' Trash Settings...) ask the session bus for GNOME Settings: this
# answers as it (bin/settings-gnome-bridge.py), and wins over GNOME Settings if that's installed too
services=$data/dbus-1/services

if [ "$1" = "--uninstall" ]; then
    rm -f "$apps/settings-app.desktop" "$icons/settings-app.svg" "$bin/settings" "$services/org.gnome.Settings.service"
    # the gnome-control-center stand-in, only if it's ours
    grep -qs "settings-gnome-bridge" "$bin/gnome-control-center" && rm -f "$bin/gnome-control-center"
else
    mkdir -p "$apps" "$icons" "$bin"
    sed "s|@BIN@|$dir/bin/settings|g" "$dir/data/settings-app.desktop" > "$apps/settings-app.desktop"
    cp "$dir/data/settings-app.svg" "$icons/settings-app.svg"
    ln -sf "$dir/bin/settings" "$bin/settings"
    mkdir -p "$services"
    printf '[D-BUS Service]\nName=org.gnome.Settings\nExec=%s\n' "$dir/bin/settings-gnome-bridge.py" > "$services/org.gnome.Settings.service"
    # apps that run `gnome-control-center <panel>` instead: a stand-in, unless GNOME Settings is installed
    real=$(PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vx "$bin" | paste -sd:) command -v gnome-control-center || true)
    if [ -z "$real" ]; then
        printf '#!/bin/sh\n# Settings app stand-in for GNOME Settings (install.sh; settings-gnome-bridge.py)\nexec python3 "%s" --open "$@"\n' "$dir/bin/settings-gnome-bridge.py" > "$bin/gnome-control-center"
        chmod +x "$bin/gnome-control-center"
    fi
fi
update-desktop-database -q "$apps" 2>/dev/null || true
# the session bus reads the new (or removed) service file now, not at the next login
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
gtk-update-icon-cache -q -t "$data/icons/hicolor" 2>/dev/null || true
if [ "$1" != "--uninstall" ]; then
    echo
    python3 "$dir/bin/settings-doctor.py" || true
fi
