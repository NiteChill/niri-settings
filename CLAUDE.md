# Settings: a settings app for niri + the system + the Dynamic Island

Quickshell (QML) app, one window. Run: `qs -p ~/Programming/Personal/settings-app`. Public release, GNOME
Settings' balance (important settings shown, niche ones in an "Advanced" group, the rest left to config
files). The island lives in ~/.config/quickshell (its own CLAUDE.md); `inventory.md` lists every setting.

## Structure
```
shell.qml          the window (no title bar: QT_WAYLAND_DISABLE_WINDOWDECORATION pragma; own header, close, drag),
                   app id settings-app, the `settings` IPC target (open <page> <setting>)
theme/Theme.qml    every look value: HeroUI v3 sizes/greys/timings + the island's colors, font axes, springs,
                   level-icon presets (wifiLayers, volumeLayers), stepFocus (arrow keys between choices)
components/        HeroUI v3 look on QtQuick.Templates (Button, TextField, NumberField, Slider, Switch, Checkbox,
                   Radio(Group), Select + Popover + ListBoxItem, Tabs, Card, Chip, Kbd, Tooltip, Spinner, Banner...)
                   + settings pieces: SettingsGroup, SettingsRow, NavItem, TileOption, Swatch, AppIcon, LayeredIcon
                   (the island's level icons), Missing (what can't work here + Install), KeyedModel (lists updated in place), SettingReveal (go to a
                   setting: settle, scroll, blink), ShortcutField (record a shortcut), CornerPicker, MicTest,
                   WindowPreview (live mini desktop), IslandPreview (island renders over the wallpaper),
                   IslandGallery (stills of the real island, for the showcase)
services/          Env (paths, sandbox, read / readFor / write / launch), Kdl (KDL parse/write), Niri (config
                   model, binds, outputs), Desktop (gsettings: one dconf watch), Island (island config,
                   installed), Hw (Wi-Fi, connections, Bluetooth, sound, battery, mice / touchpads), Host (name,
                   time, region, user, about, apps, default apps, startup), Nav (open page + setting)
pages/             App.qml (sidebar + page; compact icon sidebar under 900 px) + one page per sidebar entry;
                   ShortcutsTab (Keyboard > Shortcuts), IslandShowcase (the island page without the island)
bin/               settings (launcher: one instance, `settings <page> [setting]`, `--index`),
                   settings-index.py (every setting as JSON, for the sidebar search and the island launcher),
                   settings-doctor.py (`settings --doctor [--json]`: what the computer has / lacks, see below)
tools/             capture-island.py (stills of the real island for the showcase)
data/              settings-app.desktop + icon (install.sh puts them in place)
assets/icons/      Material Symbols Rounded (@material-symbols/svg-400 0.48.0), only the ones in use;
                   island-*.svg copied from the island (its own drawings)
assets/previews/   the island rendered in each style (2x PNG, transparent; -attached, -blur variants)
assets/island-shots/  the showcase's stills (capture-island.py)
```

## Performance and niri writes (2026-11-16)
- Lists that come from a live source (Wi-Fi networks, Bluetooth devices, apps playing sound) go through
  `components/KeyedModel.qml` (rows updated in place by key; delegates: `required property var model`),
  never `model: <array>`: a scan replaced the array once per network and rebuilt every row each time
  (Wi-Fi page 1.7-3 s to open, 2 s to leave; now ~65 / ~20 ms). Hw publishes those arrays once per batch
  (Qt.callLater). Controls a row rarely shows (buttons, spinner, password field) are Loaders.
- Measure page switches with a Timer calling Nav.go in an off-screen sandbox copy (log Date.now() deltas,
  plus a Qt.callLater for work that lands right after). All pages: 20-125 ms.
- Niri.save writes, validates and deletes the candidate in one `sh -c` under a unique name, one save at
  a time (a FileView write raced `niri validate`: "No such file or directory").
- KDL numbers: `proportion` and `opacity` must be written as decimals (`1.0`), blur passes, cursor size,
  key repeat, output position and `fixed` as whole numbers; the rest take either (Kdl.decimalNodes,
  checked with `niri validate`). A new number setting: check both forms first.

- Quickshell's DesktopEntry has no mimeTypes (nor any MimeType field): Host.readMimeTypes greps the
  desktop files in XDG_DATA_HOME + XDG_DATA_DIRS order (first id wins, subfolders joined with "-").
  Singletons start on first use: a test reading Host right after the first access sees empty data.

## Writing for users (2026-11-16, the user's rules)
- Write for the people using the computer, not for us: describe what a setting does to their computer,
  never how the system underneath works. Never name niri, KDL, config files, packages or commands in the
  interface (Windows never says "Windows" in its settings). Errors say what happened for the user
  ("Nothing was changed"); the technical detail goes to the log.
- Every setting whose effect isn't obvious from its title gets a plain explanation, with an example when
  it helps. British spelling (colour, centre), like the rest of the app.
- Sliders show their value: in a SettingsRow, the row writes `format(value)` at its top right (HeroUI's
  layout), so every slider needs a `format` a person can read ("+20 %", "1.5×", "3 seconds", "Centre"),
  never a raw 0-1 number. Sliders with few steps (multipliers) dot each step inside the track
  (Slider.showSteps is automatic: <= 16 steps with room for them).
- A switch that turns something on also lets you set that thing, in rows under it shown while it's on
  (over-amplification -> maximum volume, hot corners -> which corners, low battery -> at what level, hiding
  the pointer -> after how long). Remember the last value so switching off and on keeps it.
- Mouse & Touchpad says which device each tab is for (Hw.mice / Hw.touchpads from udev's database).

## Shortcuts (2026-11-16)
- pages/ShortcutsTab.qml: a catalog of the computer's common actions by section (Dynamic Island, Windows,
  Moving between windows, Workspaces, Screens, Screenshots, Sound / brightness / music, System), each
  with its keys or "Set shortcut"; anything else bound is under Custom (where new commands are added).
  A bind is matched to an action by its signature ("name args"), or the item's `also` regex for the usual
  other ways (wpctl, playerctl, brightnessctl). New binds get hotkey-overlay-title = the action's name.
  Island actions call the island's IPC: `island toggle <panel>`, `island focus`, `island media <action>`
  (focus / media added to the island's shell.qml for this), `osd volume|mic|brightness ...`.
- components/ShortcutField.qml records a shortcut by pressing it: a ShortcutInhibitor (Quickshell.Wayland,
  window = the app's FloatingWindow, passed down from App) makes niri hand us every key while listening
  (checked: active = true). Qt key -> niri name: a table, plus the number row and punctuation by X
  keycode (so Shift+1 stays "1"). A taken key asks first; giving it here removes it from the other action.
- Niri.removeBind(key): drops it from the app's file and comments out its lines in config.kdl (brace-aware,
  marked "removed in Settings"); an include can't take a key back from config.kdl. Tested in the sandbox:
  all 79 catalog actions pass niri validate; assign / move / take over / remove give a valid config.

## Review rules (2026-11-16)
- Nothing runs for a page that isn't open: watchers are switched on by the page that needs them
  (Hw.wifiScan / bluetoothScan / netWatch / soundWatch / pointerWatch, Niri.watchOutputs) and off on
  its destruction. Desktop follows dconf with one `dconf watch /`; its writes are debounced per key.
- A page's own commands use Env.readFor(page, ...): they die with the page (a read answered after
  the page was left threw "Value is null").
- A list whose rows hold a control that saves (a slider, a switch) is a KeyedModel: rebuilding the rows
  on each save destroyed the control mid-drag (app volumes, app rules).
- Rounded containers with content that reaches the edge are ClippingRectangle: `clip: true` cuts square.
- The sidebar search reads the pages' `title:` / `"label":` strings (App.settings) and shows the
  matched setting under the page. The component gallery shows only with SETTINGS_DEV=1.
- Heavy tabs load the first time they're opened (Keyboard > Shortcuts: 196 -> 36 ms).

## Without the Dynamic Island (2026-11-16)
- The app works without the island. Island.installed = its settings were found (installed, not running:
  a restart mustn't make settings vanish); SETTINGS_NO_ISLAND=1 forces "not installed" to see that.
- Island settings stay where people look for them, hidden without it: `islandOnly: true` on a
  SettingsRow / SettingsGroup (an instance with its own `visible` writes `Island.installed && (...)`).
  The Search page (all the island's launcher) has `"island": true` in App's pages. The settings index
  tags them (`island`), so the sidebar search skips them. Shortcuts: no Dynamic Island section, and
  sound / brightness / music bind plain commands (wpctl, brightnessctl, playerctl) instead of the island.
- The showcase shows stills of the real island, not a drawing of it (components/IslandGallery: one
  after the other with a caption, over the viewer's wallpaper, at the island's real size and place).
  tools/capture-island.py makes them (assets/island-shots/: 2x PNGs with transparency + shots.json):
  it stages a copy of the island (fixed 9:41, Wi-Fi "Home", a made-up song and message with generated
  pictures, Focus only inside the copy, no sounds / alerts / commands, panels kept open), opens each
  state, lets it settle and grabs it (island.grabToImage: no niri screenshot, no clipboard). Re-run it
  whenever the island's look changes; add a state to SHOTS there.
- The Dynamic Island page stays for everyone: without the island it's IslandShowcase (the gallery,
  then features and a "Get the Dynamic Island" button opening Env.islandHomepage, empty until
  the project has a home: the button does nothing then).

## Dividers (2026-11-16)
- A SettingsRow draws a line above itself unless it's the first thing shown in its group: rows hidden
  before it don't count (a hidden first row left a line under the group's title, looking like a glitch),
  and a row inside wrappers (a Wi-Fi network, an app rule) asks the wrappers too, up to the group's list
  (SettingsGroup's Column, objectName "settingsList").

## Going to a setting (2026-11-16)
- Nav.go(page, title) opens the page scrolled to the SettingsRow / SettingsGroup / tile Section with that
  title (switching the page's tab if it's on another one), then a lighter shade blinks over it once,
  calmly (App.reveal; a row: inset like its hover highlight; a group: around its card). It lands only
  once the page has settled (the target's position and the page's height unchanged for 3 checks 50 ms
  apart, 2 s at most): pages keep filling in after they're created (the mixer's streams), and landing
  at once highlighted whatever had moved into the spot. The highlight follows the target while shown.
- Off-screen test renders can draw icons (Shapes) outside a Flickable's clip; the GPU doesn't. Check
  anything that looks unclipped in a real window before "fixing" it. Used by the
  sidebar search (the matched setting) and from outside: `settings <page> "<title>"` / IPC
  `settings open <page> <title>` / SETTINGS_SETTING; the island's launcher passes the result's title
  (its search.settings.openCommand: settings {page} {title}).
- Sound > Test your microphone: pw-record to $XDG_RUNTIME_DIR/settings-mic-test.wav (SIGINT to stop,
  5 s at most), pw-play to hear it; the level sampled every 100 ms is its waveform, lit as it plays;
  the file is deleted when the page closes. Tested with `pw-play --volume 0` (never play out loud).

## App volumes (2026-11-16)
- One row per stream, not per app (a browser has one per tab / player): Hw.streams gives the title from
  media.name (tab "(12) " counts dropped; "Title | Site" split into title + site; a played file's path
  -> its name), the app's desktop id (pipewire.access.portal.app_id for Flatpaks) for its real icon, a
  mute button, and a live level line (PwNodePeakMonitor on the stream, sqrt like the mic dots).
- SettingsRow finds a slider up to 3 levels inside its control to show the value at its top right.

## Search prefixes (2026-11-16)
- The Search page edits each kind's prefixes (island search.<kind>.prefixes): space-separated in one
  field, checked as you type (at least one; not letters only, or every search starting with it would
  switch; not used by another kind that's on), saved on Enter or leaving the field when valid.

## Keyboard layout (2026-11-16)
- While niri's config names no xkb layout, niri uses the system's (localectl's X11 layout; the user's is
  French AZERTY), and as soon as any xkb field is set it stops reading it. The Keyboard page shows the
  system's layout when the config has none, and every change writes layout + variant + options
  together (writeXkb). It used to assume "us" and wrote it, which switched the user's keyboard to US.

## Island icons (2026-11-16)
- What the island also shows (Wi-Fi, Bluetooth, battery, sound, notifications, its alerts) uses the
  island's own drawings, copied as assets/icons/island-*.svg. Levels are drawn like the island's idle
  bar (components/LayeredIcon): the whole symbol at 45 % (idle.overlayOpacity) under the live level:
  Theme.wifiLayers + bars, Theme.volumeLayers + Theme.volumeLevel(v) (muted: Theme.volumeMuted). The
  sidebar (App pages' `layers`), the Wi-Fi page's big symbol and its network rows (SettingsRow
  iconLayers / iconLevel) use it. If the island's icons change, copy them again.
- NumberField measures its widest value (from / to + unit): its − / + buttons and padding give way, and
  below that it grows, so a number is never cut (a "-12" in a 112 px field was).

## Search index and keyboard (2026-11-16)
- bin/settings-index.py (`settings --index`): every setting as JSON, from App.qml's page list and the
  pages' titles of SettingsRow / SettingsGroup / Section / DeviceCard (not banners, dialogs, options),
  plus the shortcut actions. The sidebar search and the island's launcher both use it: a new setting is
  findable as soon as it has a literal `title:` in one of those.
- Keyboard: the sidebar (Tab after the search, or Down from it) moves with Up / Down / Home / End, its
  highlight shows a focus ring; Ctrl+F goes back to the search. Choices (TileOption, Swatch, the corner
  picker's corners: `isChoice`) take Tab, Left / Right (Theme.stepFocus, within their row) and
  Space / Enter, with a FocusRing outside the chosen ring.

## Displays (2026-11-16)
- The controls show niri's live outputs (`niri msg outputs`). niri applies a change a moment after the
  file is written, so reading right after the write showed the old values until the next click. Now:
  Niri.watchOutputs (on while the page is open) runs `niri msg --json event-stream` and re-reads on
  ConfigLoaded / WorkspacesChanged; and the page keeps what you just picked in `pending`, shown on top
  of the live state (`out`) until niri reports it (or 4 s, or an error). Not testable on real screens
  without changing them: tested in the sandbox (pending shown at once, falls back after 4 s).

## Crashes (2026-11-16)
- Qt's own QML file dialog (QtQuick.Dialogs without a platform theme) segfaults in
  QQuickFolderBreadcrumbBar when a sidebar place is clicked (Qt 6.11.2). shell.qml sets
  QT_QPA_PLATFORMTHEME=xdgdesktopportal, so FileDialog is the system's chooser (checked: a Nautilus
  portal window opens). Never use Qt's QML file / folder dialog.
- When a Quickshell process crashes it restarts in place with no arguments: without QS_CONFIG_PATH it
  loaded the default config, a second island (2026-11-16, after the crash above, on quitting). bin/settings
  sets QS_CONFIG_PATH; Env.launch starts apps through `env -u QS_CONFIG_PATH -u SETTINGS_PAGE` so they
  don't inherit it. Crash reports: ~/.cache/quickshell/crashes/<run id>; `coredumpctl list` has the
  stack of the first crash (the report Quickshell shows can be the restart's).

## Installed app
- App id `settings-app` (`//@ pragma AppId` in shell.qml) = the desktop entry's name and StartupWMClass;
  niri window rules and the launchers match it. `install.sh` writes data/settings-app.desktop (with `@BIN@`
  replaced by bin/settings' absolute path) to ~/.local/share/applications, the icon to hicolor, and links
  ~/.local/bin/settings.
- One instance: bin/settings first calls `qs ipc -p <dir> call settings open <page>` (IpcHandler in
  shell.qml: switches page, focuses the window via `niri msg action focus-window`), else starts `qs -n`.
  Not `show`: `qs ipc show` is a built-in subcommand and swallows the call. SETTINGS_PAGE sets the first page.
- In a test, bin/settings passes SETTINGS_SANDBOX / DCONF_PROFILE through, so it's safe to run with them set.
- The default settings app (2026-11-17): GNOME apps open their settings by asking the session bus for
  `org.gnome.Settings` and calling org.gtk.Actions.Activate("launch-panel", [<(panel, [<sub>])>], {})
  (Files 50's Trash Settings: ('privacy', ['usage']); also ('search', ['locations']), ('sharing', [])).
  install.sh writes ~/.local/share/dbus-1/services/org.gnome.Settings.service -> bin/settings-gnome-bridge.py
  (PyGObject): started on demand, takes the name, maps GNOME's panel ids to our pages + a setting to scroll
  to (PANELS: privacy/usage -> Privacy "Trash and temporary files", datetime -> System "Time zone"...),
  runs bin/settings, exits after 5 s idle. Also org.freedesktop.Application. The user's service dir wins
  over /usr/share's, so this beats GNOME Settings when both are installed (on purpose: ours is the
  default); install.sh reloads the bus config so it works without logging out. Apps that run
  `gnome-control-center <panel>` get ~/.local/bin/gnome-control-center (`--open`), written only when GNOME
  Settings itself isn't installed. Test the mapping with `settings-gnome-bridge.py --page privacy usage`;
  tested 2026-11-17 with gdbus sending Files' exact call (activated, opened, exited).

## Reviews (the user's way, 2026-11-17)
When asked to review something (a mode, a change, the day's work): first give it a grade out of 10 with
the reasons in a few lines (what works, what holds it back), then rewrite / fix what holds it back to raise
the grade, and end with the new grade and what changed. Not a list of suggestions left for later: do the
work that augments the grade (checks, tests, CLAUDE.md, notify as usual).

## The app follows its own settings (2026-11-17, the user: "everything that is in settings should reflect on the app itself")
- All in theme/Theme.qml, live: Appearance's style + accent (as before) and Interface font (font-name's
  family; its size is left out); Accessibility's Text size (Theme.textScale: Theme.text.* and Theme.px(n)
  scale, controls holding text grow by what their text grows, Theme.grow(base, textPx): buttons, fields,
  list items, tabs, chips, keycaps; the sidebar, header and reading width too; fixed widths of Select /
  TextField / NumberField are written `Math.round(N * Math.max(1, Theme.textScale))`), High contrast
  (Theme.hcDk / hcLt over the palette, cards outlined: Theme.cardBorder, a 3 px focus ring, disabled less
  faded), Reduce animation and Animation speed (Theme.dur(ms) / Theme.motion.*: 0 when reduced, times
  niri's slowdown; Spring jumps when reduced; the setting-reveal blink becomes a still highlight; a
  spinner keeps turning). New code: never a literal text size, duration or text-holding height: go
  through Theme (px / grow / dur), and a card on Theme.c.surface gets `border.width: Theme.cardBorder;
  border.color: Theme.c.border`.
- The Text size slider shows its sample live and applies on release (the page grew under the pointer).
- Mouse wheel: components/WheelScroll in every Flickable / ListView (App's sidebar and page, Select's
  list). niri multiplies the wheel (value120) by Mouse > Scroll speed before the app gets it, but Qt's
  Flickable restarts its wheel glide on every event and drops the rest of the previous one, so the speed
  barely showed. WheelScroll adds the notches up (Theme.scroll.notch px per notch x what niri sent) and
  glides there; touchpads (pixel deltas) pass through to the Flickable (niri scales them too, momentum
  kept). Sliders and number fields take the wheel only once focused (`takesWheel`), otherwise the wheel
  scrolls the page. Tested on the maths (1 notch 64 px, a doubled notch 128, three fast ones add up to
  192) in the sandbox: a real wheel can't be sent from a test.
- App icons follow Appearance > Icons at launch (bin/settings passes QS_ICON_THEME; Quickshell can't switch
  the theme live). Env.launch / the GNOME bridge drop it for what they start.
- Not the app's to follow: pointer, keyboard repeat, natural scrolling, cursor size / theme (the compositor
  applies them to every window), window title bars (the app draws none).

## README images (2026-11-17)
- The READMEs show the apps first (the user: "this is what people will look for first"):
  docs/<page>.png here (Appearance on top, then Displays, Mouse & Touchpad, Keyboard, Accessibility,
  the Dynamic Island page) and the island's docs/hero.png + panels.png.
- Remake them when the look changes: `python3 tools/capture-island.py` (island stills, staged: 9:41,
  Wi-Fi "Home", Bluetooth "Buds", a made-up song and message), then `python3 tools/readme-images.py`
  (composes the island over demo wallpapers, photographs this app's pages in a sandbox in a real
  window, ~25 s on screen, hover off, framed). Both show briefly on screen.
- Nothing personal in them: pages that show this computer's surroundings are left out (Wi-Fi networks
  nearby, Bluetooth / sound device names, the user's name); hardware models are fine. Check every new
  shot before committing it. The island's connected Bluetooth name was real ("Atom") until the
  capture staged it.

## Rules
- **Writes go through the services**, never a Process in a page: Env.write (logged instead of run in the
  sandbox), Niri.set / setFlag / setOnOff / setBlock / setOutput / setBind / replaceNodes, Desktop.set,
  Island.set, Hw.*, Host.*. Reads may use Env.read.
- **niri**: the app writes only `settings.kdl` (whole file from `Niri.own`, validated with `niri validate`
  first; a rejected change is undone and shown). config.kdl gets `include optional=true "settings.kdl"`
  at its end only once the person allows it (2026-11-17, for the public release; before, the app added
  it on every start without asking): until then the notice at the top of the app (Niri.askInclude,
  Allow / Not now) and nothing written in niri's folder, not even settings.kdl; a change is shown but
  held (Niri.heldChange, its config.kdl edits in Niri._pendingMain) and saved on Allow; Not now undoes
  it, and the next change asks again. Every write to config.kdl goes through Niri._writeMain. Allow never
  creates a missing config.kdl (a file holding only the include would replace niri's whole default
  config: no shortcuts) and drops a held config.kdl edit if the file changed since (_pendingBase: the
  person's own edits win). Tested in sandboxes: no include (held, Not now, Allow; a held config.kdl
  edit), no config.kdl at all, and an edit made in a text editor while a change was held. Non-merging blocks (input devices,
  struts, preset widths, animations subsections) are copied from config.kdl before the first change.
  Wallpaper / idle / night light = the app's own `spawn-at-startup` lines (swaybg, swayidle, wlsunset)
  + a live restart.
- **The island follows the system**: shared values are written to the system (gsettings: accent,
  clock-format, show-banners = Focus), not to the island's config. Island-only settings go through
  Island.set (makes the line active, then the island's `tools/check-config.py --rewrite`).
- **Controlled components**: Tabs, Select, RadioGroup, NumberField never assign their own `value`; they emit
  `activated` / `valueModified` and the page stores it (assigning would cut the page's binding: the
  Displays page showed stale values). Switch / Slider keep their bindings when the user moves them (Qt's
  internal setters don't break bindings; tested).
- Pages read settings through `(rev, Niri.arg(...))` so they re-read when the config changes.
- A page that starts scanning (Wi-Fi, Bluetooth) turns it off in Component.onDestruction.

## Testing (never on the real system)
- Sandbox: `SETTINGS_SANDBOX=<dir>` (copies of niri/config.kdl in <dir>/niri, the island in <dir>/island)
  + `DCONF_PROFILE=<file with "user-db:test">`; writes that would touch the system are logged.
- Off-screen: `QT_QPA_PLATFORM=offscreen qs -p <copy>`, grabToImage on `app` or the page item (not the
  window's contentItem). Off-screen can't draw shader items (ClippingRectangle content, MultiEffect): tiles
  look empty there but render on the GPU (checked in a real sandboxed window). A real window only renders
  (and grabs) while niri shows it.
- Qt here has no webp decoder: pictures are jpg / png only.

## Dependency check (2026-11-17)
- bin/settings-doctor.py (`settings --doctor`, run at the end of install.sh): needed things (Quickshell
  >= 0.3 + the modules the app imports, niri, gsettings, dconf, gsettings-desktop-schemas, python3) and
  features (one CHECKS entry each: what it is, the pages using it, the package per distro family:
  fedora / arch / debian / suse from /etc/os-release). Exit 1 when something needed is missing; `--json`
  for the app. Only looks: PATH, `busctl --system list` (running or activatable), `gsettings
  list-schemas`, fc-list, /sys/class/backlight (no backlight = brightness skipped), the island's
  config/schema.json. The module check loads a tiny config with `qs -n` and reads its log live
  (Qt.quit() doesn't end Quickshell: it's terminated once "Configuration Loaded" or the failure shows),
  dropping each missing import to name them all (~0.3 s in total).
- A page or command that starts using a new tool, service or schema: add it to CHECKS in the same change.
- Pages (2026-11-17): services/Deps.qml runs `--doctor --quick --json` once at start (~0.1 s; --quick
  skips what the running app proves: Quickshell, its modules, niri). Deps.has(id) is true until the answer
  is in (no banner flashing in). components/Missing (a Banner: "<what> isn't available yet", `needs`
  ids) replaces what can't work, and those rows read `visible: Deps.has(...)`. Whole pages: `needs` in
  App's pages list (Wi-Fi / Network: networkmanager, Bluetooth: bluez, Printers: cups) -> MissingPage.
  Sections: Power (upower only with a battery, powerprofiles, swayidle, swaylock), Sound tests
  (pipewire), Displays (brightnessctl only with a backlight, wlsunset), Appearance (swaybg, fontconfig),
  System (timedate: device name, date & time, region; accounts: name + picture), Apps (xdgutils),
  Shortcuts (each catalog item's `needs`: wpctl / playerctl only without the island, brightnessctl,
  swaylock; a note + Install on the row). Fingerprints stay hidden without fprintd (no way to know there's
  a reader).
- Install: Deps.install(ids) opens a terminal (xdg-terminal-exec, $TERMINAL, then common ones; each with
  its own "run this" flag) running the distro's install command for all of them, sudo asking there; Deps
  then re-checks every 3 s until they're present (at most 10 min), so the page fills in by itself. No
  terminal or no package for this distro: "Copy what's needed" (names + packages to the clipboard). The
  interface never names a package or command (the terminal shows the command, that's fine).
- Test: SETTINGS_PRETEND_MISSING=wlsunset,cups,... (read by the doctor) + the sandbox + off-screen.
  Install in the sandbox is logged ("SANDBOX would launch"), never run.

## Wallpaper list (2026-11-17)
- Appearance lists the same pictures as the island's wallpaper panel, the same way (the island's
  bin/wallpaper list): wallpaper.folders (default ~/Pictures/[Ww]allpaper*), wallpaper.extensions (jpg,
  jpeg, png), wallpaper.depth (3), folder by folder, each sorted by path, hidden folders skipped, no cap.
  Read through Island.value (the island's own settings when installed, the same defaults otherwise),
  listed again when the island's config arrives or changes (Island.revision). The code is a copy of the
  island's (AppearancePage.pictureLister, a python3 -c script): change both together. Checked: identical
  output. (Before: also ~/.local/share/backgrounds and /usr/share/backgrounds, files > 100 kB, no
  screenshots, at most 48.)

## Next steps (written 2026-11-17, for the next session)
Goal: make the app easy to install on any niri machine. Done so far: `settings --doctor` (+ install.sh),
pages that say what's missing and offer to install it (Dependency check above).
1. Try a real Install in a real window (night light: wlsunset is missing on the user's laptop): ghostty
   opens, sudo asks, the page fills in by itself. Only ghostty's flag is known to work; check the others'
   ways of running a command (kitty, foot, alacritty, wezterm, ptyxis, kgx, gnome-terminal, konsole,
   xfce4-terminal) before trusting Deps._terminals.
2. Done 2026-11-17: a git repository (branch main, first commit), GPL-3.0-or-later (`LICENSE`, the
   user's choice), `THIRD-PARTY.md` crediting Material Symbols and HeroUI v3 (both Apache-2.0), a
   `.gitignore` (Python bytecode, editor files). Published 2026-11-17 as
   https://github.com/NiteChill/niri-settings (public, release v0.1.0), next to the island's
   https://github.com/NiteChill/niri-island: two repositories (the user's choice), named with "niri"
   (the user agreed: they're niri-only, and "Dynamic Island" is Apple's name). Commits use GitHub's
   noreply address (the user's email would be public in the history). Each README explains how the two
   work together; keep them in step when either changes what the other relies on.
3. Done 2026-11-17: the font. This app follows the desktop's interface font (Theme.font from
   font-name), Google Sans Flex only when none is set; without it fontconfig picks the system's sans
   (Noto Sans on Fedora, checked with a fontconfig that hides ~/.local/share/fonts). The island ships
   Google Sans Flex itself (OFL 1.1, in its assets/fonts).
4. Done 2026-11-17: the notice before config.kdl is touched (see Rules > niri).
5. Packages: an AUR package first (most niri users are on Arch), then a Fedora COPR next to Quickshell's,
   maybe a Nix flake. Needed checks in the doctor = hard dependencies, features = optional ones (the
   doctor's CHECKS is the list). Installed under /usr/share/settings-app with bin/settings on PATH; make
   sure Env.appDir and the desktop file work from there (today install.sh points at this folder). Flatpak
   doesn't fit (host commands, config files).
6. The doctor's package names for Debian / Ubuntu and openSUSE were written from memory: check each one
   (niri and quickshell have none there today; pipewire-bin, libglib2.0-bin, glib2-tools, cups-client...).
7. Fingerprints: without fprintd the section stays hidden, even on a laptop with a reader. Detecting a
   reader without fprintd (USB ids in udev?) would let the page offer it.
8. Done: Env.islandHomepage is https://github.com/NiteChill/niri-island (SETTINGS_ISLAND_URL overrides).
9. Default settings app: only Files' panels were checked (strings in Nautilus 50). Collect what other
   apps send (GNOME Shell isn't used here; gnome-software, GNOME Online Accounts, portals...) with
   `dbus-monitor --session "destination=org.gnome.Settings"` and add their panels to PANELS. Packages must
   install the D-Bus service file too (to /usr/share/dbus-1/services only if GNOME Settings isn't there).
10. One shared place for the wallpaper list rules instead of two copies (app + island), if both ship
   together.
