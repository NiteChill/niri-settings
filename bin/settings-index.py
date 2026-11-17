#!/usr/bin/env python3
"""Every setting the app shows, as JSON, for searching them: `settings --index`.

Read from the app's own files, so it's never out of date: the pages (id, name, icon, file) from
pages/App.qml, then each page's setting titles (`title: "..."`) and, for the keyboard shortcuts, the
names of the actions (`"label": "..."` in pages/ShortcutsTab.qml). Option labels (Left / Right, On /
Off) are left out: they aren't settings. The island's launcher and the app's sidebar search both use it.

`island`: the setting is the Dynamic Island's (shown only when it's installed).
Output: [{"page": "mouse", "pageLabel": "Mouse & Touchpad", "icon": "mouse-fill",
          "iconFile": "/…/assets/icons/mouse-fill.svg", "title": "Tap to click"}, ...]
with one entry per page too (title = the page's name).
"""
import json
import os
import re
import sys

APP = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
PAGES = os.path.join(APP, "pages")


# what holds a setting's name; a notice (Banner), an empty state, a card or a dialog has a title too,
# but it isn't a setting
HOLDERS = {"SettingsRow", "SettingsGroup", "Section", "DeviceCard"}


def _opener(lines, i, indent):
    """The block a line at `indent` belongs to: the nearest line above, less indented, opening one."""
    for j in range(i - 1, -1, -1):
        o = re.match(r'^(\s*)(\w+)\s*\{\s*$', lines[j])
        if o and len(o.group(1)) < indent:
            return j, o.group(2), len(o.group(1))
    return None


def _island_only(lines, j, indent):
    """Whether the block opened at line j says `islandOnly: true` among its own properties."""
    inner = None
    for k in range(j + 1, len(lines)):
        line = lines[k]
        if not line.strip():
            continue
        ind = len(line) - len(line.lstrip())
        if ind <= indent:
            break
        if inner is None:
            inner = ind
        if ind == inner and re.match(r'^\s*islandOnly:\s*true\b', line):
            return True
    return False


def setting_titles(text):
    """[(title, island_only)] of the page's settings."""
    lines = text.split("\n")
    out = []
    for i, line in enumerate(lines):
        m = re.match(r'^(\s*)title:\s*"([^"]{3,})"', line)
        if not m:
            continue
        holder = _opener(lines, i, len(m.group(1)))
        if not holder or holder[1] not in HOLDERS:
            continue
        # island-only itself, or inside an island-only group
        island = False
        j, kind, ind = holder
        while True:
            if kind in HOLDERS and _island_only(lines, j, ind):
                island = True
                break
            up = _opener(lines, j, ind)
            if not up:
                break
            j, kind, ind = up
        out.append((m.group(2), island))
    return out


def main():
    app = open(os.path.join(PAGES, "App.qml"), encoding="utf-8").read()
    pages = []
    for m in re.finditer(r'\{\s*"id":\s*"(\w+)",\s*"label":\s*"([^"]+)",\s*"icon":\s*"([^"]+)"([^}]*)\}', app):
        if '"dev": true' in m.group(4):
            continue
        icon_file = os.path.join(APP, "assets", "icons", m.group(3) + ".svg")
        pages.append({"id": m.group(1), "label": m.group(2), "icon": m.group(3),
                      # a page that's all the Dynamic Island's (Search); the island's own page stays
                      # (a showcase without it), its settings don't
                      "island": '"island": true' in m.group(4),
                      "islandSettings": '"island": true' in m.group(4) or m.group(1) == "island",
                      "iconFile": icon_file if os.path.exists(icon_file) else "",
                      # drawn upside down in the sidebar (the island's page: a screen with a bar on top)
                      "flip": '"flip": true' in m.group(4)})
    files = dict(re.findall(r'"(\w+)":\s*"(\w+(?:Page|Tab))"', app))
    # a page's file, plus the files only it uses (the keyboard page's shortcuts tab)
    extra = {"keyboard": ["ShortcutsTab"]}

    out = []
    for p in pages:
        seen = set()
        out.append({"page": p["id"], "pageLabel": p["label"], "icon": p["icon"], "iconFile": p["iconFile"], "flip": p["flip"], "island": p["island"], "title": p["label"]})
        seen.add(p["label"].lower())
        for name in [files.get(p["id"])] + extra.get(p["id"], []):
            path = os.path.join(PAGES, (name or "") + ".qml")
            if not name or not os.path.exists(path):
                continue
            text = open(path, encoding="utf-8").read()
            found = setting_titles(text)
            if name == "ShortcutsTab":
                # the shortcut actions; the Dynamic Island's own ones are the island's
                for block in re.split(r'\{ "title": ', text)[1:]:
                    island = block.lstrip().startswith('"Dynamic Island"')
                    found += [(t, island) for t in re.findall(r'"label":\s*"([^"]{3,})"', block)]
            for t, island in found:
                if t.lower() in seen:
                    continue
                seen.add(t.lower())
                out.append({"page": p["id"], "pageLabel": p["label"], "icon": p["icon"], "iconFile": p["iconFile"], "flip": p["flip"],
                            "island": p["islandSettings"] or island, "title": t})
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
