#!/usr/bin/env python3
"""Convert raw generated art in ~/art_raw into runtime-sized assets under assets/mg/.

Re-run after regenerating any raw image. Sprites are trimmed to their alpha bounds and
fit into a max box; opaque paintings are resized; the dirt texture is made seamless.
"""
import os
import sys
from PIL import Image, ImageEnhance, ImageFilter

RAW = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/art_raw")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "mg")


def trim(img):
    bbox = img.getchannel("A").point(lambda a: 255 if a > 12 else 0).getbbox()
    return img.crop(bbox) if bbox else img


def sprite(name, dest, box):
    img = Image.open(os.path.join(RAW, name)).convert("RGBA")
    img = trim(img)
    img.thumbnail((box, box), Image.LANCZOS)
    path = os.path.join(OUT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(dest, img.size)


def painting(name, dest, size, sat=1.0, bright=1.0, contrast=1.0):
    img = Image.open(os.path.join(RAW, name)).convert("RGB").resize(size, Image.LANCZOS)
    if sat != 1.0:
        img = ImageEnhance.Color(img).enhance(sat)
    if bright != 1.0:
        img = ImageEnhance.Brightness(img).enhance(bright)
    if contrast != 1.0:
        img = ImageEnhance.Contrast(img).enhance(contrast)
    path = os.path.join(OUT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, quality=88)
    print(dest, img.size)


def seamless(name, dest, size):
    img = Image.open(os.path.join(RAW, name)).convert("RGB").resize((size, size), Image.LANCZOS)
    w, h = img.size
    shifted = Image.new("RGB", (w, h))
    shifted.paste(img.crop((w // 2, 0, w, h)), (0, 0))
    shifted.paste(img.crop((0, 0, w // 2, h)), (w - w // 2, 0))
    shifted2 = Image.new("RGB", (w, h))
    shifted2.paste(shifted.crop((0, h // 2, w, h)), (0, 0))
    shifted2.paste(shifted.crop((0, 0, w, h // 2)), (0, h - h // 2))
    # Blend the original (seams at edges) with the shifted copy (seams at centre)
    # using a mask that favours the shifted copy near the image edges.
    mask = Image.new("L", (w, h))
    px = mask.load()
    for y in range(h):
        for x in range(w):
            dx = abs(x - w / 2) / (w / 2)
            dy = abs(y - h / 2) / (h / 2)
            d = max(dx, dy)
            px[x, y] = int(255 * min(1.0, max(0.0, (d - 0.55) / 0.4)))
    out = Image.composite(shifted2, img, mask)
    out.save(os.path.join(OUT, dest), optimize=True)
    print(dest, out.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    for t in ["puff", "dew", "thorn", "boom"]:
        for lvl in ["1", "2", "a", "b"]:
            sprite(f"tower_{t}_{lvl}.png", f"towers/{t}_{lvl}.png", 256)
    for e, box in [("munchbug", 176), ("dashmite", 176), ("shellback", 192), ("duskmoth", 192),
                   ("gloop", 176), ("thornhorn", 288)]:
        sprite(f"enemy_{e}.png", f"enemies/{e}.png", box)
    sprite("vault_intact.png", "world/vault_intact.png", 320)
    sprite("vault_damaged.png", "world/vault_damaged.png", 320)
    sprite("spawn_burrow.png", "world/burrow.png", 224)
    for p in ["tree", "pine", "rock", "fern", "log", "pond", "shrooms", "bush", "flowers"]:
        sprite(f"prop_{p}.png", f"props/{p}.png", 256)
    for i in ["coin", "seed", "wave"]:
        sprite(f"icon_{i}.png", f"ui/icon_{i}.png", 96)
    sprite("panel.png", "ui/panel.png", 640)
    sprite("logo.png", "ui/logo.png", 1100)
    painting("ground_1.png", "maps/ground_1.jpg", (1600, 900), sat=0.78, bright=0.9, contrast=0.92)
    painting("ground_2.png", "maps/ground_2.jpg", (1600, 900), sat=0.9, bright=1.0)
    painting("ground_3.png", "maps/ground_3.jpg", (1600, 900), sat=0.95, bright=1.05)
    painting("title_art.png", "ui/title_art.jpg", (1920, 1080))
    seamless("dirt.png", "maps/dirt.png", 256)


if __name__ == "__main__":
    main()
