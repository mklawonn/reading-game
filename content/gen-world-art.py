#!/usr/bin/env python3
"""Generates the per-world horizon art (soft flat silhouettes, transparent top)
bundled at app/assets/images/worlds/<unitId>.png. Pure Pillow — rerun after
palette tweaks; the app falls back to plain gradients if a file is missing.

Usage: python3 content/gen-world-art.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / 'app/assets/images/worlds'
W, H = 1440, 760
SS = 2  # supersample factor for smooth edges


def canvas():
    return Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))


def save(img, unit_id):
    OUT.mkdir(parents=True, exist_ok=True)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT / f'{unit_id}.png')
    print('wrote', OUT / f'{unit_id}.png')


def hill(draw, base_y, amp, wavelength, phase, color, w=W * SS, h=H * SS):
    """A smooth sine-topped hill filled to the bottom edge."""
    pts = [(x, base_y + amp * math.sin((x / wavelength) + phase))
           for x in range(0, w + 20, 20)]
    draw.polygon(pts + [(w, h), (0, h)], fill=color)


def meadow():  # 1 — rolling green hills
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    hill(d, 480 * s, 60 * s, 420 * s, 0.0, (168, 213, 162, 215))
    hill(d, 580 * s, 50 * s, 300 * s, 2.1, (140, 192, 132, 235))
    save(img, 1)


def farm():  # 2 — golden field rows
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    hill(d, 450 * s, 40 * s, 500 * s, 1.0, (232, 201, 122, 205))
    hill(d, 540 * s, 35 * s, 380 * s, 2.6, (217, 178, 95, 225))
    hill(d, 630 * s, 30 * s, 300 * s, 0.4, (200, 155, 69, 240))
    save(img, 2)


def town():  # 3 — pastel rooftop skyline
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    # Back row: tall soft-lavender blocks.
    x = 0
    heights = [300, 380, 330, 420, 350, 390, 320, 400, 340]
    while x < W * s:
        hgt = heights[(x // (170 * s)) % len(heights)] * s
        d.rectangle([x, H * s - hgt, x + 150 * s, H * s],
                    fill=(204, 194, 221, 200))
        x += 170 * s
    # Front row: shorter houses with triangle roofs.
    x = 40 * s
    while x < W * s:
        w_, hgt = 180 * s, 240 * s
        top = H * s - hgt
        d.rectangle([x, top, x + w_, H * s], fill=(181, 168, 201, 235))
        d.polygon([(x - 14 * s, top), (x + w_ + 14 * s, top),
                   (x + w_ // 2, top - 90 * s)], fill=(160, 145, 185, 235))
        x += 250 * s
    save(img, 3)


def cozy():  # 4 — dusk pillow-hills and a big moon
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([1050 * s, 60 * s, 1270 * s, 280 * s], fill=(255, 243, 196, 235))
    hill(d, 500 * s, 70 * s, 520 * s, 0.6, (159, 168, 218, 205))
    hill(d, 600 * s, 55 * s, 360 * s, 2.9, (121, 134, 203, 230))
    save(img, 4)


def garden():  # 5 — flower silhouettes over green
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    hill(d, 560 * s, 45 * s, 400 * s, 1.4, (156, 204, 143, 225))
    for (cx, cy, r, col) in [
        (180, 430, 74, (244, 169, 192, 230)),
        (470, 380, 92, (250, 200, 152, 225)),
        (820, 420, 66, (244, 169, 192, 230)),
        (1150, 370, 96, (233, 150, 180, 225)),
    ]:
        cx, cy, r = cx * s, cy * s, r * s
        d.rectangle([cx - 7 * s, cy, cx + 7 * s, H * s], fill=(127, 176, 105, 230))
        for k in range(6):  # petal ring
            a = k * math.pi / 3
            px, py = cx + r * math.cos(a), cy + r * math.sin(a)
            d.ellipse([px - r * .62, py - r * .62, px + r * .62, py + r * .62],
                      fill=col)
        d.ellipse([cx - r * .5, cy - r * .5, cx + r * .5, cy + r * .5],
                  fill=(255, 236, 170, 245))
    save(img, 5)


def sky():  # 6 — layered cloud banks
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS

    def cloudband(base_y, r, color, step=170):
        for i, x in enumerate(range(-60, W + 60, step)):
            rr = (r + (i % 3) * 18) * s
            d.ellipse([x * s - rr, base_y * s - rr, x * s + rr, base_y * s + rr],
                      fill=color)
        d.rectangle([0, base_y * s, W * s, H * s], fill=color)

    cloudband(560, 95, (227, 242, 253, 215))
    cloudband(660, 80, (187, 222, 251, 235), step=150)
    save(img, 6)


def rainbow():  # 7 — a soft arc rising from cloud puffs
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    cx, cy = W * s // 2, int(H * 1.18) * s
    bands = [(255, 179, 186), (255, 223, 186), (255, 255, 186),
             (186, 255, 201), (186, 225, 255), (218, 198, 255)]
    outer = 640 * s
    for i, col in enumerate(bands):
        r = outer - i * 52 * s
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*col, 210))
    r = outer - len(bands) * 52 * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 0))
    for px, py, r in [(170, 620, 120), (1270, 620, 120)]:
        d.ellipse([(px - r) * s, (py - r) * s, (px + r) * s, (py + r) * s],
                  fill=(255, 255, 255, 235))
    save(img, 7)


if __name__ == '__main__':
    meadow(); farm(); town(); cozy(); garden(); sky(); rainbow()
