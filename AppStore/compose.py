#!/usr/bin/env python3
"""Builds the App Store marketing images for Melodissimo from simulator captures and the game art.

Run:  python compose.py <shots_dir> <art_dir> <out_dir>
  shots_dir: <shots>/iphone/*.png (landscape iPhone captures), <shots>/ipad/*.png (landscape iPad captures)
  art_dir:   PNG renders of the Assets.xcassets/Game SVGs (alpanica_*, fals_*, map_*, icon_coin)
Needs Pillow.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SHOTS, ART, OUT = sys.argv[1:4]
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "Melodissimo", "Data", "Font", "BalooDa-Regular.ttf")
if not os.path.exists(FONT):
    FONT = "/Users/macbook/Documents/Coding/Melodissimo/Melodissimo/Data/Font/BalooDa-Regular.ttf"

SKY_TOP, SKY_BOTTOM = (120, 190, 240), (178, 222, 250)
NIGHT_TOP, NIGHT_BOTTOM = (45, 36, 64), (88, 70, 140)
INK = (45, 36, 64)
YELLOW = (255, 213, 74)
WHITE = (255, 255, 255)

# Screens in store order: (capture name, headline, subline, background)
SCREENS = [
    ("stageListen", "Play songs on a real pianika", "Falling notes, perfect timing, big combos", "sky"),
    ("campaignMap", "Tour Nusantara with Alpanica", "8 islands, 100 stages, Sabang to Merauke", "sky"),
    ("battleBoss", "Defeat the off-key Fals", "Read not angka fast to win the battle", "night"),
    ("echo", "Train your ear", "Hear a melody, then play it back", "sky"),
    ("quizGuessSong", "Fun music quizzes", "Guess the song, spot the wrong note", "night"),
    ("shop", "Dress up Alpanica", "Earn coins for outfits and keyboard colors", "sky"),
    ("result3", "Collect stars and badges", "14 achievements to unlock", "night"),
]


def font(px):
    return ImageFont.truetype(FONT, int(px))


def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h), top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        draw.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def art(name, height=None, width=None):
    img = Image.open(os.path.join(ART, name + ".png")).convert("RGBA")
    img = img.crop(img.getbbox())
    if height:
        img = img.resize((int(img.width * height / img.height), int(height)), Image.LANCZOS)
    elif width:
        img = img.resize((int(width), int(img.height * width / img.width)), Image.LANCZOS)
    return img


def paste_shadow(canvas, img, xy, blur, offset, alpha=90):
    shadow = Image.new("RGBA", (img.width + blur * 4, img.height + blur * 4), (0, 0, 0, 0))
    mask = img.split()[3].point(lambda v: v * alpha // 255)
    shadow.paste((20, 15, 40, 255), (blur * 2, blur * 2), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (xy[0] - blur * 2, xy[1] - blur * 2 + offset))
    canvas.alpha_composite(img, xy)


def rounded(img, radius):
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    img.putalpha(mask)
    return img


def device(shot, width, bezel_ratio=0.022, radius_ratio=0.06):
    """The capture inside a dark rounded device frame, `width` px wide."""
    bezel = int(width * bezel_ratio)
    inner_w = width - 2 * bezel
    inner = shot.resize((inner_w, int(shot.height * inner_w / shot.width)), Image.LANCZOS)
    radius = int(width * radius_ratio)
    frame = Image.new("RGBA", (width, inner.height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius, fill=(28, 26, 34, 255))
    frame.alpha_composite(rounded(inner, max(radius - bezel, 4)), (bezel, bezel))
    return frame


def centered_text(draw, cx, y, text, size, fill, stroke=0, stroke_fill=None, max_w=None):
    f = font(size)
    while max_w and draw.textlength(text, font=f) > max_w and size > 10:
        size *= 0.95
        f = font(size)
    w = draw.textlength(text, font=f)
    draw.text((cx - w / 2, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    return size


def background(w, h, kind):
    top, bottom = (SKY_TOP, SKY_BOTTOM) if kind == "sky" else (NIGHT_TOP, NIGHT_BOTTOM)
    bg = gradient(w, h, top, bottom).convert("RGBA")
    draw = ImageDraw.Draw(bg)
    # Soft clouds / sparkles so the flat gradient has some life.
    u = min(w, h)
    if kind == "sky":
        for cx, cy, r in [(0.08, 0.86, 0.16), (0.2, 0.95, 0.14), (0.9, 0.9, 0.18), (0.78, 0.98, 0.12)]:
            x, y, rr = cx * w, cy * h, r * u
            draw.ellipse([x - rr, y - rr * 0.6, x + rr, y + rr * 0.6], fill=(255, 255, 255, 70))
    else:
        import random
        rnd = random.Random(7)
        for _ in range(60):
            x, y, r = rnd.random() * w, rnd.random() * h * 0.5, rnd.uniform(0.002, 0.006) * u
            draw.ellipse([x - r, y - r, x + r, y + r], fill=(255, 240, 200, rnd.randint(80, 200)))
    return bg


def screenshot(shot_path, size, headline, subline, kind, mascot=None):
    """Landscape marketing screenshot: headline on top, framed capture below, optional character peeking in."""
    w, h = size
    canvas = background(w, h, kind)
    draw = ImageDraw.Draw(canvas)
    head_px = h * 0.095
    sub_px = h * 0.05
    color = INK if kind == "sky" else WHITE
    sub_color = (60, 70, 110) if kind == "sky" else (230, 220, 255)
    centered_text(draw, w / 2, h * 0.025, headline, head_px, color, max_w=w * 0.86)
    centered_text(draw, w / 2, h * 0.025 + head_px * 1.15, subline, sub_px, sub_color, max_w=w * 0.8)

    shot = Image.open(shot_path).convert("RGB")
    if "/iphone/" in shot_path:
        # The simulator draws the Dynamic Island into the capture; trim the empty safe-area strips on both sides.
        cut = int(shot.width * 0.075)
        shot = shot.crop((cut, 0, shot.width - cut, shot.height))
    else:
        # Drop the iPad status bar (the simulator shows its own locale's date there).
        shot = shot.crop((0, int(shot.height * 0.026), shot.width, shot.height))
    top = int(h * 0.025 + head_px * 1.15 + sub_px * 1.45)
    avail_h = h - top - int(h * 0.04)
    frame_w = int(w * 0.80)
    frame = device(shot, frame_w)
    if frame.height > avail_h:
        frame = device(shot, int(frame_w * avail_h / frame.height))
    x = (w - frame.width) // 2
    paste_shadow(canvas, frame, (x, top), blur=int(w * 0.012), offset=int(h * 0.015), alpha=110)
    if mascot:
        m = art(mascot, height=h * 0.34)
        canvas.alpha_composite(m, (int(x - m.width * 0.55), h - m.height - int(h * 0.01)))
    return canvas.convert("RGB")


def fit_font(draw, text, size, max_w):
    while draw.textlength(text, font=font(size)) > max_w and size > 10:
        size *= 0.96
    return size


def hero(size):
    """Header / search-result artwork: title on the left, Alpanica facing Fals on a spotlight on the right."""
    w, h = size
    canvas = background(w, h, "sky")
    draw = ImageDraw.Draw(canvas)
    # Text block in the left half
    tx, text_w = w * 0.06, w * 0.44
    title_px = fit_font(draw, "Melodissimo", h * 0.2, text_w)
    sub_px = fit_font(draw, "Konser Nusantara", title_px * 0.55, text_w)
    tag_lines = ["Learn pianika with Alpanica,", "from Sabang to Merauke"]
    tag_px = min(fit_font(draw, line, title_px * 0.3, text_w) for line in tag_lines)
    block_h = title_px * 1.1 + sub_px * 1.25 + tag_px * 1.3 * len(tag_lines)
    y = (h - block_h) / 2 - title_px * 0.15
    draw.text((tx, y), "Melodissimo", font=font(title_px), fill=INK)
    y += title_px * 1.1
    draw.text((tx + title_px * 0.03, y), "Konser Nusantara", font=font(sub_px), fill=(194, 60, 78))
    y += sub_px * 1.25
    for line in tag_lines:
        draw.text((tx + title_px * 0.03, y), line, font=font(tag_px), fill=(60, 70, 110))
        y += tag_px * 1.3
    # Spotlight disc and characters in the right half
    cx, cy = w * 0.75, h * 0.55
    r = min(w * 0.24, h * 0.45)
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 236, 160, 150))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(r * 0.08)))
    floor = cy + r * 0.62
    alp = art("alpanica_sing", height=r * 1.15)
    boss = art("fals_boss_1", height=r * 0.85)
    canvas.alpha_composite(boss, (int(cx + r * 0.05), int(floor - boss.height)))
    paste_shadow(canvas, alp, (int(cx - r * 0.85), int(floor - alp.height)), blur=int(r * 0.04), offset=int(r * 0.03), alpha=90)
    for i, name in enumerate(["fals_minion_2", "fals_minion_3"]):
        m = art(name, height=r * 0.32)
        canvas.alpha_composite(m, (int(cx + r * (0.25 + i * 0.4)), int(floor - m.height * 0.55)))
    coin = art("icon_coin", height=r * 0.16)
    canvas.alpha_composite(coin, (int(cx - r * 0.95), int(cy - r * 0.75)))
    canvas.alpha_composite(coin, (int(cx + r * 0.75), int(cy - r * 0.85)))
    return canvas.convert("RGB")


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(path, img.size)


# Header and search-result artwork
save(hero((5244, 2950)), f"{OUT}/1_header/header_5244x2950.png")
save(hero((3840, 1646)), f"{OUT}/1_header/header_3840x1646.png")
save(hero((3840, 2560)), f"{OUT}/2_search_result/search_3840x2560.png")
save(hero((1920, 1280)), f"{OUT}/2_search_result/search_1920x1280.png")

# Screenshots per device class (landscape: the app runs in landscape only)
mascots = {}
targets = [
    ("iphone", "3_iphone_6.3", [(2622, 1206), (2556, 1179)]),
    ("ipad", "4_iphone_duo", [(2853, 2007), (2034, 1398)]),
    ("ipad", "5_ipad_13", [(2752, 2064), (2732, 2048)]),
]
for source, folder, sizes in targets:
    for i, (name, headline, subline, kind) in enumerate(SCREENS):
        path = os.path.join(SHOTS, source, name + ".png")
        if not os.path.exists(path):
            print("missing", path)
            continue
        for size in sizes:
            img = screenshot(path, size, headline, subline, kind, mascots.get(i))
            save(img, f"{OUT}/{folder}/{size[0]}x{size[1]}/{i + 1:02d}_{name}.png")
