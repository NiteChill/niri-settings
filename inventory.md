# Settings app: inventory and structure (draft 1, 2026-11-16)

A single settings app for a niri desktop: niri's config, the system (network, sound, power, users...) and the
Dynamic Island shell. Public release, modelled on GNOME Settings: about 20 pages in a sidebar, each with a few
grouped settings. Niche ones go in an **Advanced** group at the bottom of their page. Anything rarer than that
stays in the config files.

Where each setting is stored:
`niri` = niri config (KDL) · `island` = the island's config.jsonc · `gs` = gsettings (GTK apps read it) ·
`NM` NetworkManager · `BlueZ` · `PW` PipeWire/Pulse · `UPower` / `PPD` power-profiles-daemon · `logind` ·
`timedate1` / `locale1` / `hostname1` · `Accounts` AccountsService · `fprintd` · `CUPS` · `GeoClue` ·
`xdg` (mime, autostart) · **NEW** = nothing provides it on niri yet, the project has to supply it.

`(adv)` = in the page's Advanced group.

---

## How the app writes niri's config

Checked on niri 26.04: `include` exists (since 25.11) and passes `niri validate`. The plan:

- The app owns one file, `~/.config/niri/settings.kdl`, and never touches the user's `config.kdl` except for
  one line, at the **end**: `include optional=true "settings.kdl"`.
  Decided: **every time the app opens**, it checks config.kdl for that line (not commented out) and appends it
  if it's missing, without asking. It creates settings.kdl if that's missing too.
  It goes at the end because includes are positional: they override whatever comes before them, so the app's
  values win. `optional=true` (26.04) means that deleting the file never breaks niri.
- Most sections merge, so the file only needs to hold what the app changed. Some sections **don't merge** and
  replace the user's version wholesale: `struts`, `preset-column-widths`, each `animations` subsection, and
  each input device block (`touchpad { }`, `mouse { }`...). For those, the app writes the whole block,
  starting from what niri currently uses.
- `output "<name>" { }` and `window-rule { }` blocks are added, not merged. The app writes one block per
  output, and its own window rules at the end, where they win.
- `binds` override by key: a shortcut the app sets replaces the same key from config.kdl.
- Border quirk: in an included file, `border { }` doesn't turn the border on. Always write `on` / `off`.
- After each write: `niri validate`. If it fails, roll back and show the error.
- The app should also read config.kdl, so it can show the user's real current values and say when a value
  is "set in your config.kdl" but overridden by the app.

---

## Sidebar

```
Wi-Fi                       Notifications
Network                     Search
Bluetooth                   Mouse & Touchpad
Displays                    Keyboard
Sound                       Printers
Power                       Accessibility
Windows & Workspaces        Privacy & Security
Appearance                  System  > Region & Language / Date & Time / Users / About / Updates
Dynamic Island
Apps
```

Same order and names as GNOME where a GNOME page exists ("Multitasking" becomes **Windows & Workspaces**:
niri's scrolling layout has more to set than GNOME's). **Dynamic Island** is the one page GNOME doesn't have,
like macOS's "Control Center" page.

---

## Wi-Fi
- Wi-Fi on / off · `NM`
- Airplane mode · `NM` + rfkill
- Visible networks (bars, lock, connect, password) · `NM`
- Saved networks: forget, connect automatically, show password · `NM`
- Connect to a hidden network · `NM`
- Hotspot (name, password) · `NM`
- (adv) Network details: IP, DNS, MAC randomisation, metered · `NM`

## Network
- Wired: on / off, details · `NM`
- VPN: list, add (WireGuard, OpenVPN import), connect · `NM` (+ NM plugins)
- (adv) Proxy: off / manual / automatic · `gs` org.gnome.system.proxy
- (adv) Manual IP / DNS per connection · `NM`

## Bluetooth
- Bluetooth on / off · `BlueZ`
- Devices: pair, connect, disconnect, forget, battery level · `BlueZ`
- Visible as "<computer name>" (= hostname) · `hostname1`
- **NEW: a pairing agent.** Without one, devices that ask for a PIN or a code to confirm can't pair (the island
  can't either, today). The app, or better the shell, has to register a BlueZ agent and show the code.

## Displays
Per screen, with an arrangement view you can drag:
- On / off · `niri` output `off`
- Resolution + refresh rate (from the modes the screen reports) · `niri` `mode`
- Scale (100 % / 125 % / ... + custom) · `niri` `scale`
- Rotation · `niri` `transform`
- Position (the drag view) · `niri` `position`
- Variable refresh rate: off / on / only when apps ask · `niri` `variable-refresh-rate` (`on-demand`)
- Main screen (where the session starts) · `niri` `focus-at-startup`
- Night light: on / scheduled (sunset to sunrise, or custom hours), warmth · **NEW**: niri supports
  gamma control, but nothing on the machine drives it (no wlsunset / gammastep). Either the app depends on
  wlsunset, or the shell does it.
- (adv) Hot corner on this screen · `niri` output `hot-corners`
- (adv) Per-screen gaps / column widths · `niri` output `layout { }`

## Sound
- Output device, volume, balance · `PW`
- Over-amplification (volume up to 150 %) · `island` volume.max
- Input device, input volume, mute · `PW`
- Per-app volume · `PW` streams
- Alert sounds: on / off, volume, which alerts make a sound · `island` sounds.*
- (adv) Device profiles (HDMI vs analog, headset vs A2DP) · `PW` card profiles

## Power
- Power mode: power saver / balanced / performance · `PPD`
- Automatic power saver on low battery · **NEW** (GNOME does it in its daemon; the shell could)
- Show battery percentage · `island`
- Blank screen after · **NEW** idle daemon (see Privacy > Screen lock)
- Automatic suspend: on battery / plugged in, after · **NEW** idle daemon
- Power button: suspend / power off / nothing · `logind` HandlePowerKey (root, through polkit) +
  `niri` `disable-power-key-handling`
- (adv) When the lid closes: suspend / nothing / turn off the laptop screen · `logind` HandleLidSwitch +
  `niri` switch-events
- (adv) Battery charge limit (80 %) · `UPower` charge thresholds (where the hardware supports it)

## Windows & Workspaces (niri's layout; GNOME's "Multitasking")
Windows
- Width of new windows (½, ⅔, full...) · `niri` `default-column-width`
- Widths to cycle through (Mod+R) · `niri` `preset-column-widths`
- Keep the focused window centred: never / always / when it doesn't fit · `niri` `center-focused-column`
- Centre a window that's alone · `niri` `always-center-single-column`
- New columns show windows stacked / as tabs · `niri` `default-column-display`
- Focus follows the mouse · `niri` `focus-follows-mouse`
- Move the mouse to the focused window · `niri` `warp-mouse-to-focus`
- Alt+Tab switcher: on / off, show previews · `niri` `recent-windows`

Workspaces & overview
- Hot corner opens the overview · `niri` `gestures.hot-corners`
- Overview zoom · `niri` `overview.zoom`
- (adv) Empty workspace above the first · `niri` `empty-workspace-above-first`
- (adv) Switching to the current workspace goes back · `niri` `workspace-auto-back-and-forth`
- (adv) Named workspaces (add, rename, pin to a screen) · `niri` `workspace`
- (adv) Reserved space at the screen edges · `niri` `struts`

## Appearance
Style
- Dark / light · `gs` color-scheme (GTK + portals; the island stays dark)
- Accent color · `gs` accent-color + `island` colors.accent (one choice drives both)
- Wallpaper · **NEW**: today it's a `swaybg` line in `spawn-at-startup`. The app needs a wallpaper it can change
  live (the shell drawing it, or a daemon like swww).

Windows
- Gaps between windows · `niri` `gaps`
- Window corner radius · `niri` window-rule `geometry-corner-radius` + `clip-to-geometry`
- Border: on / off, width, active / inactive color · `niri` `border`
- Focus ring: on / off, width, color · `niri` `focus-ring`
- Shadows: on / off, softness, color · `niri` `shadow`
- Background blur strength · `niri` `blur` (passes)
- Rounded screen corners: on / off, size · `island` screenCorners

Text & icons
- Interface font, monospace font · `gs` font-name / monospace-font-name
- Icon theme, cursor theme · `gs` icon-theme / cursor-theme + `niri` `cursor.xcursor-theme`
  (both have to be set, or GTK and niri disagree)
- (adv) Window title bars from apps (on / off) · `niri` `prefer-no-csd`
- (adv) Font hinting / antialiasing · `gs`

## Dynamic Island
The curated set the island already exposes, plus a few behaviours:
- Corner style: square / soft / round / full · `island` island.shape
- Corner smoothness · `island` island.cornerSmoothing
- Attach to the top of the screen · `island` island.attachToTop
- Blur behind the island, background opacity · `island` island.blur / blurOpacity
- Show the date next to the clock · `island` idle.clock.dateFormat (a few preset formats, not a free field)
- Music bars: on the left / right · `island` idle.media.left
- Show the Bluetooth icon · `island` idle.bluetooth.show
- Clicking the middle opens quick settings · `island` idle.middleOpensQuickSettings
- Close panels when clicking outside · `island` island.clickOutsideCloses
- Say goodbye on power off · `island` goodbye.enabled
- Calm mode (later) · `island`
- (adv) Close delay · `island` island.collapseDelay
- (adv) "Edit the full config file" button: opens config.jsonc (the other ~650 design settings stay there)

## Apps
- Default apps: web, mail, calendar, music, video, photos, files, terminal · `xdg` mimeapps.list
  (+ `xdg-terminal-exec` for the terminal)
- Startup apps: list, add, remove · `xdg` ~/.config/autostart (run by niri's systemd session).
  `niri` `spawn-at-startup` lines are shown read-only ("from your config")
- Per-app rules, picked from the open / installed apps · `niri` window-rule matched on app-id:
  - opens: normal / maximised / fullscreen / floating
  - width when it opens
  - opacity
  - hide from screen sharing (password managers) · `block-out-from "screencast"`
  - (adv) open on screen / workspace
- Screenshots folder · `niri` `screenshot-path`
- (adv) App permissions (Flatpak: files, camera, mic...) · flatpak overrides / portals: maybe later

## Notifications
- Do not disturb (= Focus) · `island` Activity.doNotDisturb (today it doesn't survive a restart: it has to be
  saved somewhere)
- Notification sounds · `island` sounds.notification
- Hide notifications while sharing the screen · `niri` layer-rule `block-out-from "screencast"` on the island
- Per app: allow, sound, (later) priority · **NEW**: the island's notification server has to filter by app
- Alerts, each on / off: volume, brightness, microphone, low battery (+ warn at %), charging, Wi-Fi
  connected, headphones, now playing · `island` <alert>.enabled

## Search (the island launcher)
- What it searches: apps, settings & panels, files, calculations, web · `island` search.*
- Web search engine (Google, DuckDuckGo, Bing, custom URL) · `island` search.web
- Folders searched for files · `island` search.files
- Launcher shortcut · `niri` binds
- (adv) Number of results · `island`

## Mouse & Touchpad
General
- Primary button: left / right · `niri` `left-handed` (mouse + touchpad)
- (adv) Middle click by pressing both buttons · `niri` `middle-emulation`
- (adv) Middle-click paste · `niri` `clipboard.disable-primary`

Mouse
- Speed · `niri` `accel-speed`
- Acceleration on / off · `niri` `accel-profile` adaptive / flat
- Natural scrolling · `niri` `natural-scroll`
- Scroll speed · `niri` `scroll-factor`

Touchpad (only when one is present)
- On / off / off while a mouse is plugged in · `niri` `off`, `disabled-on-external-mouse`
- Speed, natural scrolling, scroll speed · `niri`
- Tap to click · `niri` `tap`
- Scrolling: two fingers / edge · `niri` `scroll-method`
- Secondary click: two fingers / bottom-right corner · `niri` `click-method`
- Disable while typing · `niri` `dwt`
- (adv) Tap and drag, drag lock · `niri` `drag`, `drag-lock`

Trackpoint / Tablet / Touchscreen (only when one is present)
- Trackpoint speed, acceleration · `niri`
- Tablet / touchscreen: which screen it maps to (or "the focused one") · `niri` `map-to-output` /
  `map-to-focused-output`

Cursor
- Hide while typing, hide after (seconds) · `niri` `cursor.hide-when-typing` / `hide-after-inactive-ms`

## Keyboard
Layouts
- Input sources: add / remove / reorder layouts + variants · `niri` xkb `layout` + `variant`
- Switch layouts with... (Super+Space, Alt+Shift...) · `niri` binds / xkb `grp:` option
- Compose key · `niri` xkb option `compose:`
- Caps Lock acts as: Caps Lock / Ctrl / Escape / off · `niri` xkb options `ctrl:nocaps`, `caps:escape`...
- (adv) Remember the layout per window · `niri` `track-layout "window"`

Typing
- Repeat keys: on / off, delay, speed · `niri` `repeat-delay` / `repeat-rate`
- (adv) Num Lock on at start · `niri` `numlock`

Keyboard shortcuts
- Searchable list of niri actions grouped like GNOME's (Windows, Workspaces, Screenshots, Launchers, System,
  Sound & media), each with one or more keys, record a new key, reset to default · `niri` binds
- Custom shortcuts: a name + a command · `niri` binds `spawn`
- (adv) Modifier key: Super / Alt · `niri` `mod-key`
- (adv) Show the shortcuts help at login · `niri` `hotkey-overlay.skip-at-startup`

## Printers
- List, add (network / USB), set default, remove, queue · `CUPS` (phase 2: GNOME's own page is a lot of
  work; until then, open system-config-printer)

## Accessibility
- Larger text · `gs` text-scaling-factor + `island` font size
- Cursor size · `gs` cursor-size + `niri` `cursor.xcursor-size`
- Reduce animation · `niri` `animations { off }` + `gs` enable-animations + `island` (needs one island
  switch that cuts its springs to fades)
- High contrast · `gs`
- Screen reader (Orca) on / off · `gs` screen-reader-enabled (works only as far as niri's accessibility
  support goes)
- (adv) Animation speed · `niri` `animations.slowdown`

## Privacy & Security
- Screen lock: lock after the screen blanks, delay, lock on suspend · **NEW**: niri doesn't lock or idle
  by itself. Swayidle and swaylock are installed but not running. Options: the shell provides both
  (Quickshell has an idle monitor and a session lock, and the lock screen would match the island), or the app
  writes a swayidle config. The shell is the better product, and it's a project of its own.
- Location services · `GeoClue` (+ used for night light's sunset time)
- Remember recent files, clear history · `gs` org.gnome.desktop.privacy
- Empty trash / delete temp files automatically, after · `gs` org.gnome.desktop.privacy
- Fingerprint: enroll, remove · `fprintd`
- (adv) Hide windows marked "private" from screenshots too · `niri` block-out-from "screen-capture"

## System
- **Region & Language**: language, formats (dates, numbers, units) · `locale1` + ~/.config/locale.conf,
  `gs` (the island's clock / date formats follow the formats setting)
- **Date & Time**: automatic time, time zone (automatic / pick on a list), 24-hour clock · `timedate1` +
  `gs` clock-format + `island` clock 24h (one switch drives both)
- **Users**: name, picture, password, add / remove (admin) · `Accounts` (+ polkit)
- **About**: computer name, hardware (CPU, memory, GPU, disk), OS, niri + shell versions · `hostname1`,
  /proc, /etc/os-release
- **Updates**: system, Flatpak, firmware · PackageKit, flatpak, `fwupd` (phase 2; until then, open GNOME
  Software / Discover)

---

## Left out on purpose (stay in the config files)
niri:
- Custom modes, modelines (can damage screens), output background / backdrop colors
- xkb model / rules / keymap file, `mod-key-nested`, scroll button + button lock, tap-button-map, calibration
  matrices, per-device trackball section (folded into Mouse)
- Border / focus ring gradients, urgent colors, tab indicator details, insert hint, shadow offset / spread /
  draw-behind-window, blur offset / noise / saturation, overview workspace shadow and backdrop color
- Per-animation curves and springs (only on / off and speed; the island's window-open / close springs are
  mirrored by hand today, and that link should become automatic rather than a setting)
- Gestures (drag-and-drop edge scrolling), `preset-window-heights`, `background-color`, `environment`,
  `xwayland-satellite`, `config-notification`, debug options, `spawn-sh-at-startup`
- Window-rule matchers other than the app (title regexes, is-floating, at-startup...), layer rules,
  `tiled-state`, `popups`, `baba-is-float`, per-window VRR / scroll factor / shadows / borders
- Recent-windows highlight, padding, preview sizes, the switcher's own key bindings
- Tablet-mode switch events

island:
- About 650 of its 667 settings: every size, padding, gap, text, icon, spring, duration and color besides
  the accent. They stay documented in schema.json and editable in config.jsonc. That's the point of the curated
  set: other people can't make it ugly from the GUI.

system:
- GNOME Online Accounts, Sharing / remote desktop, Color (ICC profiles), removable media autorun, Wacom
  details beyond the screen mapping, sticky / slow keys, zoom (niri has no magnifier yet)

---

## Things the inventory showed are missing (NEW)
In order of how much people will miss them:
1. **Screen lock + idle** (blank, lock, suspend). Nothing does it today. Probably a shell feature.
2. **Wallpaper** that can be changed live.
3. **Bluetooth pairing agent** (PIN / code devices can't pair).
4. **Night light.**
5. Do-not-disturb that survives a restart; per-app notification rules.
6. Automatic power saver on low battery.

## Built (2026-11-16)
Every page in the sidebar is built and wired (see CLAUDE.md). Not done yet: Bluetooth pairing agent (PIN
devices), a real lock screen (swaylock for now), hidden Wi-Fi networks / hotspot, printers beyond the list,
user passwords, per-app notification rules.

## Decisions (2026-11-16)
- **Toolkit: Quickshell (QML).** Same language and look as the island, and Quickshell already has the
  services the app needs (NetworkManager, BlueZ, PipeWire, UPower, power profiles, notifications). The app is
  a normal window (`FloatingWindow`), run as its own Quickshell config.
- **niri include:** checked and re-added on every launch (see the top of this file).
- **Shared values:** the app writes the *system's* settings (gsettings, timedate1, locale1...). The island
  reads them, live, and never needs the app.
  Done in the island already: accent color (gsettings `accent-color`) and 12 / 24-hour clock
  (`clock-format`), through one `gsettings monitor` stream. Each has an island switch, "Follow the system ...",
  on by default. Tested: changes show within a second.
  Still to wire when the app's pages exist: text size (`text-scaling-factor`), reduce animation
  (`enable-animations`), first day of the week (from the region's formats), date formats.
