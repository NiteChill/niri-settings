# Settings

A settings app for a niri desktop: niri, the system and the Dynamic Island in one window.
Built with Quickshell (QML).

Install it for your user with `./install.sh`: it shows up as "Settings" in every app launcher (with
Wi-Fi, Bluetooth, Displays, Sound and Dynamic Island as quick actions) and adds a `settings` command
(`settings wifi` opens a page). Opening it again brings the open window forward. Rerun `./install.sh`
after moving the folder; `./install.sh --uninstall` removes it. Without installing: `qs -p .`.

Other apps' settings buttons (Files' "Trash Settings"...) open this app: `./install.sh` makes it answer
as GNOME Settings (bin/settings-gnome-bridge.py), on the matching page.

`settings --doctor` (also shown at the end of `./install.sh`) checks what the computer has: what the app
needs to open (Quickshell 0.3 with its modules, niri, gsettings, dconf, the desktop's setting schemas) and
what each page uses (NetworkManager, BlueZ, PipeWire, swaybg, wlsunset...), with the packages to install
for Fedora, Arch, Debian / Ubuntu or openSUSE. `--json` gives the same for scripts. It only looks.

- `theme/Theme.qml`: every color, size, corner and animation, taken from HeroUI v3's default theme.
  Dark / light and the accent follow the desktop (gsettings), live.
- `components/`: HeroUI v3's components rebuilt on QtQuick.Templates (which handle keyboard, focus,
  hover, press, the way React Aria does for HeroUI).
- `services/`: niri's config (KDL, written to its own included settings.kdl), gsettings, the island's
  config, hardware (Wi-Fi, Bluetooth, sound, power) and the machine (time, region, user, apps).
- `pages/`: the window layout (`App.qml`) and the pages.
- `assets/icons/`: Material Symbols Rounded (`name.svg` outlined, `name-fill.svg` filled).
- `bin/settings`, `data/` (desktop entry, icon), `install.sh`: the app as an installed app.
  `bin/settings-doctor.py`: the dependency check.
- `inventory.md`: every setting the app will cover, and where it's stored.

## Licence

GNU General Public License v3.0 or later: see `LICENSE`. The icons (Material Symbols) and the design
values taken from HeroUI v3 are Apache-2.0: see `THIRD-PARTY.md`.
