#!/usr/bin/env python3
"""Make the README images of both projects: niri-settings' pages and niri-island's looks.

    python3 tools/readme-images.py [island folder, default ~/.config/quickshell]

1. The island: composes the stills of tools/capture-island.py (run it first: assets/island-shots/) over
   demo wallpapers -> <island>/docs/hero.png (at rest, music, quick settings, time) and panels.png
   (a notification, search, battery).
2. The Settings app: a copy of it runs in a sandbox (SETTINGS_SANDBOX: nothing on the system changes; a
   test dconf database) in a real window for ~25 s (shapes and effects only render on the GPU, not
   off-screen), dark, blue accent, hover off (the pointer may rest on the sidebar), and grabs each page
   at 2x -> docs/<page>.png, framed as a window (rounded corners, soft shadow).
   What the pages show is this computer's: pick pages without private details (no Wi-Fi networks
   nearby, no Bluetooth or sound device names, no user name). The Appearance page lists demo
   wallpapers (made here), not yours.
Needs Pillow (python3-pillow).
"""
import json
import math
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

APP = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
ISLAND = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.config/quickshell")
SHOTS = os.path.join(APP, "assets", "island-shots")
PAGES = ["appearance", "island", "displays", "mouse", "keyboard", "accessibility"]
PALETTES = [
    [(28, 32, 74), (120, 64, 160), (240, 140, 120)],
    [(10, 40, 60), (30, 120, 140), (200, 230, 210)],
    [(60, 20, 40), (200, 80, 90), (250, 200, 120)],
    [(20, 24, 30), (70, 90, 130), (180, 190, 220)],
    [(30, 60, 30), (120, 170, 90), (240, 230, 160)],
]


def wallpapers(folder):
    """Soft blurred colour fields, 1920x1200."""
    os.makedirs(folder, exist_ok=True)
    for n, pal in enumerate(PALETTES):
        w, h = 1920 // 8, 1200 // 8
        im = Image.new("RGB", (w, h))
        px = im.load()
        random.seed(n)
        blobs = [(random.random() * w, random.random() * h, pal[random.randint(1, 2)]) for _ in range(4)]
        for y in range(h):
            for x in range(w):
                t = y / h
                c = [pal[0][k] * (1 - t) + pal[1][k] * t * 0.5 for k in range(3)]
                for bx, by, col in blobs:
                    d = math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (2 * (w / 5) ** 2))
                    c = [c[k] * (1 - d) + col[k] * d for k in range(3)]
                px[x, y] = tuple(int(v) for v in c)
        im.resize((1920, 1200), Image.BICUBIC).filter(ImageFilter.GaussianBlur(20)).save(
            os.path.join(folder, f"wallpaper-{n + 1}.jpg"), quality=90)


def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def scaled(im, f):
    return im.resize((int(im.width * f), int(im.height * f)), Image.LANCZOS)


def backdrop(w, h, path):
    bg = Image.open(path).convert("RGBA")
    s = max(w / bg.width, h / bg.height)
    bg = bg.resize((int(bg.width * s) + 1, int(bg.height * s) + 1), Image.LANCZOS)
    x, y = (bg.width - w) // 2, (bg.height - h) // 2
    return bg.crop((x, y, x + w, y + h))


def island_image(top, row, wall, out, top_scale=1.0, row_scale=0.62, width=1800):
    load = lambda n: Image.open(os.path.join(SHOTS, n + ".png")).convert("RGBA")
    t = scaled(load(top), top_scale)
    r = [scaled(load(n), row_scale) for n in row]
    gap, y0 = 40, 28
    rh = max(i.height for i in r)
    ry = y0 + t.height + 60
    bg = backdrop(width, ry + rh + 60, wall)
    bg.alpha_composite(t, ((width - t.width) // 2, y0))
    x = (width - sum(i.width for i in r) - gap * (len(r) - 1)) // 2
    for i in r:
        bg.alpha_composite(i, (x, ry + (rh - i.height) // 2))
        x += i.width + gap
    rounded(bg, 36).save(out, optimize=True)


def window_frame(src, out, scale=0.6, pad=48, radius=28):
    win = rounded(scaled(Image.open(src).convert("RGBA"), scale), radius)
    canvas = Image.new("RGBA", (win.width + 2 * pad, win.height + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + 10, pad + win.width, pad + win.height + 10), radius, fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    canvas.alpha_composite(win, (pad, pad))
    canvas.save(out, optimize=True)


def patch(path, old, new):
    s = open(path, encoding="utf-8").read()
    if old not in s:
        raise SystemExit(f"readme-images: can't stage {os.path.basename(path)}: {old[:60]!r} not found")
    open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))


def capture_pages(work, walls, raw):
    """The Settings app in a sandbox, each page grabbed at 2x into raw/<page>.png."""
    app = os.path.join(work, "app")
    shutil.copytree(APP, app, ignore=shutil.ignore_patterns(".git", "docs"))
    sb = os.path.join(work, "sandbox")
    os.makedirs(os.path.join(sb, "niri"))
    for f in ("config.kdl", "settings.kdl"):
        src = os.path.expanduser(f"~/.config/niri/{f}")
        if os.path.exists(src):
            s = open(src, encoding="utf-8").read()
            # the wallpaper in use: a demo one
            s = re.sub(r'"[^"]*\.(jpe?g|png)"', '"' + os.path.join(walls, "wallpaper-1.jpg") + '"', s)
            open(os.path.join(sb, "niri", f), "w", encoding="utf-8").write(s)
    if os.path.isdir(ISLAND):
        for name in ("config", "tools"):
            shutil.copytree(os.path.join(ISLAND, name), os.path.join(sb, "island", name))
        schema = os.path.join(sb, "island", "config", "schema.json")
        data = json.load(open(schema))
        for sec in data["sections"]:
            for g in sec["groups"]:
                for x in g["settings"]:
                    if x["key"] == "wallpaper.folders":
                        x["default"] = [walls]
        json.dump(data, open(schema, "w"), indent=2)
    profile = os.path.join(work, "dconf-profile")
    open(profile, "w").write("user-db:readme-images\n")
    # hover off: the pointer may rest on the sidebar where the window opens
    patch(os.path.join(app, "components", "NavItem.qml"), "hoverEnabled: true", "hoverEnabled: false")
    patch(os.path.join(app, "shell.qml"), """            window: window
        }""", """            window: window
        }
        Timer {
            property int step: 0
            property var pages: %s
            interval: 1600
            repeat: true
            running: true
            onTriggered: {
                if (step === 0) {
                    Desktop.set("interface", "color-scheme", "prefer-dark");
                    Desktop.set("interface", "accent-color", "blue");
                }
                const k = Math.floor(step / 2) - 1;
                if (k >= pages.length) {
                    Qt.quit();
                    return;
                }
                if (k >= 0) {
                    if (step %% 2 === 0)
                        Nav.go(pages[k]);
                    else
                        app.grabToImage(r => r.saveToFile("%s/" + pages[k] + ".png"), Qt.size(app.width * 2, app.height * 2));
                }
                step++;
            }
        }""" % (json.dumps(PAGES), raw))
    env = dict(os.environ, SETTINGS_SANDBOX=sb, DCONF_PROFILE=profile)
    env.pop("QS_CONFIG_PATH", None)
    try:
        subprocess.run(["qs", "-n", "-p", app], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=4 * len(PAGES) + 15)
    except subprocess.TimeoutExpired:
        pass
    # the test database lives in the user's dconf folder: remove it
    db = os.path.expanduser("~/.config/dconf/readme-images")
    if os.path.exists(db):
        os.remove(db)


def main():
    if not os.path.isdir(SHOTS):
        raise SystemExit("readme-images: run tools/capture-island.py first")
    work = tempfile.mkdtemp(prefix="readme-images-")
    try:
        walls = os.path.join(work, "walls")
        wallpapers(walls)
        # the island
        out = os.path.join(ISLAND, "docs")
        os.makedirs(out, exist_ok=True)
        island_image("rest", ["media", "quickSettings", "time"], os.path.join(walls, "wallpaper-1.jpg"), os.path.join(out, "hero.png"))
        island_image("notification", ["search", "battery"], os.path.join(walls, "wallpaper-2.jpg"), os.path.join(out, "panels.png"), top_scale=0.8)
        # the Settings app
        raw = os.path.join(work, "raw")
        os.makedirs(raw)
        capture_pages(work, walls, raw)
        docs = os.path.join(APP, "docs")
        os.makedirs(docs, exist_ok=True)
        made = 0
        for page in PAGES:
            src = os.path.join(raw, page + ".png")
            if os.path.exists(src):
                window_frame(src, os.path.join(docs, page + ".png"))
                made += 1
        print(f"readme-images: 2 island images in {out}, {made} pages in {docs}")
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
