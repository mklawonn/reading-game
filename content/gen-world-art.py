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


# ── Hero buildings (the street view: one building per world) ────────────────
# Flat-vector with dimensional cues: lit front face + shaded side strip,
# roof-thickness rims, inset windows, arched doors with steps, ground shadow.

BW, BH = 900, 1200


def bcanvas():
    return Image.new('RGBA', (BW * SS, BH * SS), (0, 0, 0, 0))


def bsave(img, unit_id):
    img = img.resize((BW, BH), Image.LANCZOS)
    img.save(OUT / f'building_{unit_id}.png')
    print('wrote', OUT / f'building_{unit_id}.png')


def shade(c, f):
    return tuple(min(255, int(v * f)) for v in c[:3]) + (255,)


def ground_shadow(d, cx, y, w):
    d.ellipse([cx - w // 2, y - 26 * SS, cx + w // 2, y + 26 * SS],
              fill=(30, 30, 60, 60))


def wall(d, x, y, w, h, c, side=30):
    """Front face with a shaded right strip — the side plane."""
    d.rectangle([x, y, x + w, y + h], fill=c)
    d.rectangle([x + w - side * SS, y, x + w, y + h], fill=shade(c, 0.8))


def window(d, x, y, w, h, glass=(86, 74, 128, 255), arch=False):
    f = (255, 252, 245, 255)
    if arch:
        d.pieslice([x, y, x + w, y + w], 180, 360, fill=f)
        d.rectangle([x, y + w // 2, x + w, y + h], fill=f)
        inset = 7 * SS
        d.pieslice([x + inset, y + inset, x + w - inset, y + w - inset],
                   180, 360, fill=glass)
        d.rectangle([x + inset, y + w // 2, x + w - inset, y + h - inset],
                    fill=glass)
    else:
        d.rectangle([x, y, x + w, y + h], fill=f)
        inset = 7 * SS
        d.rectangle([x + inset, y + inset, x + w - inset, y + h - inset],
                    fill=glass)
    # sill
    d.rectangle([x - 6 * SS, y + h, x + w + 6 * SS, y + h + 10 * SS],
                fill=(216, 172, 110, 255))


def roof_gable(d, x, y, w, rise, c):
    d.polygon([(x - 26 * SS, y), (x + w + 26 * SS, y),
               (x + w // 2, y - rise)], fill=c)
    # thickness rim along the eave
    d.rectangle([x - 30 * SS, y - 6 * SS, x + w + 30 * SS, y + 12 * SS],
                fill=shade(c, 1.18))


def door_arch(d, cx, base, w, h, c=(126, 87, 55, 255)):
    x = cx - w // 2
    d.pieslice([x, base - h, x + w, base - h + w], 180, 360, fill=c)
    d.rectangle([x, base - h + w // 2, x + w, base], fill=c)
    inset = 9 * SS
    inner = shade(c, 0.72)
    d.pieslice([x + inset, base - h + inset, x + w - inset,
                base - h + w - inset], 180, 360, fill=inner)
    d.rectangle([x + inset, base - h + w // 2, x + w - inset, base],
                fill=inner)
    # steps
    d.rectangle([x - 16 * SS, base, x + w + 16 * SS, base + 14 * SS],
                fill=(198, 198, 205, 255))
    d.rectangle([x - 28 * SS, base + 14 * SS, x + w + 28 * SS, base + 28 * SS],
                fill=(178, 178, 188, 255))


def b_meadow():  # 1 — the red cottage from the app icon spirit
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 640 * s)
    wall(d, 210 * s, 560 * s, 480 * s, 520 * s, (226, 106, 106, 255))
    roof_gable(d, 210 * s, 560 * s, 480 * s, 240 * s, (96, 150, 208, 255))
    # chimney
    d.rectangle([560 * s, 380 * s, 620 * s, 560 * s], fill=(176, 122, 96, 255))
    window(d, 264 * s, 640 * s, 110 * s, 140 * s)
    window(d, 520 * s, 640 * s, 110 * s, 140 * s)
    window(d, 396 * s, 430 * s, 100 * s, 120 * s, arch=True)  # attic
    door_arch(d, 448 * s, base, 130 * s, 230 * s)
    # bushes
    for bx in (200, 660):
        d.ellipse([(bx - 60) * s, base - 70 * s, (bx + 60) * s, base + 8 * s],
                  fill=(126, 176, 105, 255))
    bsave(img, 1)


def b_farm():  # 2 — red barn + silo
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 430 * s, base + 10 * s, 700 * s)
    # silo behind
    d.rectangle([640 * s, 470 * s, 780 * s, base], fill=(198, 198, 205, 255))
    d.rectangle([740 * s, 470 * s, 780 * s, base], fill=(168, 168, 178, 255))
    d.pieslice([640 * s, 400 * s, 780 * s, 540 * s], 180, 360,
               fill=(226, 106, 106, 255))
    # barn: gambrel-ish roof via two stacked gables
    wall(d, 150 * s, 620 * s, 470 * s, 460 * s, (204, 82, 82, 255))
    roof_gable(d, 150 * s, 620 * s, 470 * s, 200 * s, (150, 96, 78, 255))
    d.polygon([(240 * s, 460 * s), (530 * s, 460 * s), (385 * s, 360 * s)],
              fill=(150, 96, 78, 255))
    # hay door + cross braces
    window(d, 330 * s, 500 * s, 110 * s, 100 * s, glass=(240, 205, 120, 255),
           arch=True)
    door_arch(d, 385 * s, base, 150 * s, 250 * s, c=(240, 240, 245, 255))
    window(d, 200 * s, 700 * s, 100 * s, 120 * s)
    window(d, 500 * s, 700 * s, 100 * s, 120 * s)
    bsave(img, 2)


def b_town():  # 3 — lavender rowhouse with awning + fire escape feel
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 620 * s)
    wall(d, 230 * s, 300 * s, 440 * s, 780 * s, (181, 168, 201, 255))
    # flat roof with cornice
    d.rectangle([200 * s, 270 * s, 700 * s, 310 * s], fill=(140, 125, 165, 255))
    for row in range(3):
        y = (360 + row * 200) * s
        window(d, 280 * s, y, 100 * s, 130 * s, arch=True)
        window(d, 430 * s, y, 100 * s, 130 * s, arch=True)
    # striped awning over the door
    d.rectangle([320 * s, 900 * s, 580 * s, 918 * s], fill=(150, 96, 78, 255))
    for i in range(6):
        col = (226, 106, 106, 255) if i % 2 == 0 else (255, 252, 245, 255)
        d.rectangle([(320 + i * 43) * s, 860 * s, (320 + (i + 1) * 43) * s,
                     900 * s], fill=col)
    door_arch(d, 450 * s, base, 130 * s, 210 * s)
    bsave(img, 3)


def b_cozy():  # 4 — dusk house, warm windows, moon lamp
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 640 * s)
    wall(d, 220 * s, 520 * s, 460 * s, 560 * s, (99, 110, 176, 255))
    roof_gable(d, 220 * s, 520 * s, 460 * s, 230 * s, (72, 80, 132, 255))
    # glowing windows — bedtime warmth
    window(d, 275 * s, 610 * s, 110 * s, 140 * s, glass=(255, 214, 130, 255))
    window(d, 515 * s, 610 * s, 110 * s, 140 * s, glass=(255, 214, 130, 255))
    window(d, 400 * s, 400 * s, 95 * s, 115 * s, glass=(255, 214, 130, 255),
           arch=True)
    door_arch(d, 450 * s, base, 130 * s, 225 * s, c=(60, 48, 40, 255))
    # moon lamp on a post
    d.rectangle([700 * s, 760 * s, 716 * s, base], fill=(72, 80, 132, 255))
    d.ellipse([664 * s, 690 * s, 754 * s, 780 * s], fill=(255, 243, 196, 255))
    bsave(img, 4)


def b_garden():  # 5 — greenhouse with glass panes
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 680 * s)
    glass = (198, 233, 222, 235)
    wall(d, 210 * s, 600 * s, 480 * s, 480 * s, glass, side=0)
    roof_gable(d, 210 * s, 600 * s, 480 * s, 220 * s, (127, 176, 105, 255))
    # pane grid
    for i in range(1, 4):
        d.rectangle([(210 + i * 120) * s, 600 * s, (218 + i * 120) * s, base],
                    fill=(127, 176, 105, 255))
    d.rectangle([210 * s, 820 * s, 690 * s, 830 * s],
                fill=(127, 176, 105, 255))
    door_arch(d, 450 * s, base, 130 * s, 220 * s, c=(127, 176, 105, 255))
    # flower boxes
    for fx in (250, 590):
        d.rectangle([fx * s, base - 60 * s, (fx + 120) * s, base],
                    fill=(150, 96, 78, 255))
        for k in range(3):
            d.ellipse([(fx + 8 + k * 40) * s, base - 110 * s,
                       (fx + 44 + k * 40) * s, base - 66 * s],
                      fill=(244, 169, 192, 255))
    bsave(img, 5)


def b_sky():  # 6 — pale lookout tower up in the clouds
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 560 * s)
    wall(d, 330 * s, 330 * s, 260 * s, 750 * s, (227, 242, 253, 255))
    roof_gable(d, 330 * s, 330 * s, 260 * s, 190 * s, (96, 150, 208, 255))
    for row in range(3):
        window(d, 400 * s, (420 + row * 200) * s, 110 * s, 130 * s, arch=True,
               glass=(96, 150, 208, 255))
    door_arch(d, 460 * s, base, 125 * s, 210 * s, c=(96, 150, 208, 255))
    # cloud ring hugging the tower
    for cx, cy, r in [(300, 860, 80), (620, 800, 95), (350, 740, 60)]:
        d.ellipse([(cx - r) * s, (cy - r // 2) * s, (cx + r) * s,
                   (cy + r // 2) * s], fill=(255, 255, 255, 225))
    bsave(img, 6)


def b_rainbow():  # 7 — the rainbow library
    img = bcanvas(); d = ImageDraw.Draw(img); s = SS
    base = 1080 * s
    ground_shadow(d, 450 * s, base + 10 * s, 700 * s)
    wall(d, 220 * s, 560 * s, 460 * s, 520 * s, (246, 240, 253, 255))
    # rainbow arch instead of a roof
    bands = [(255, 179, 186), (255, 223, 186), (255, 255, 186),
             (186, 255, 201), (186, 225, 255), (218, 198, 255)]
    cx, cy = 450 * s, 580 * s
    for i, col in enumerate(bands):
        r = (300 - i * 28) * s
        d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360,
                   fill=(*col, 255))
    d.pieslice([cx - (300 - len(bands) * 28) * s,
                cy - (300 - len(bands) * 28) * s,
                cx + (300 - len(bands) * 28) * s,
                cy + (300 - len(bands) * 28) * s], 180, 360,
               fill=(246, 240, 253, 255))
    window(d, 280 * s, 660 * s, 110 * s, 140 * s, arch=True)
    window(d, 510 * s, 660 * s, 110 * s, 140 * s, arch=True)
    # big open-book sign over the door
    d.polygon([(370 * s, 900 * s), (450 * s, 920 * s), (450 * s, 990 * s),
               (370 * s, 970 * s)], fill=(255, 252, 245, 255))
    d.polygon([(530 * s, 900 * s), (450 * s, 920 * s), (450 * s, 990 * s),
               (530 * s, 970 * s)], fill=(240, 235, 228, 255))
    door_arch(d, 450 * s, base, 135 * s, 215 * s, c=(218, 198, 255, 255))
    bsave(img, 7)


if __name__ == '__main__':
    meadow(); farm(); town(); cozy(); garden(); sky(); rainbow()
    b_meadow(); b_farm(); b_town(); b_cozy(); b_garden(); b_sky(); b_rainbow()
