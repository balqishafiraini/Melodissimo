#!/usr/bin/env python3
"""Generates Melodissimo game art as SVG in Alpanica's flat kawaii style.

Run:  python3 Design/generate_assets.py
Writes Design/svg/*.svg and installs each one as a vector imageset in
Melodissimo/Assets.xcassets/Game/. Re-run after tweaking; it overwrites only its own files.
"""
import json, os, re

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "svg")
CATALOG = os.path.join(ROOT, "..", "Melodissimo", "Assets.xcassets", "Game")
ALPANICA = os.path.join(ROOT, "..", "Melodissimo", "Assets.xcassets", "Clipart", "alpanica.imageset", "alpanica.svg")

INK = "#2d2440"
BLUSH = "#ffb3d1"


def svg(w, h, body):
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n{body}\n</svg>\n'


# ---------------------------------------------------------------- Fals family

def fals(body, dark, light, *, size=300, boss=False, accessory="", back=""):
    """A Fals monster: a blob with a music-note stem. Bosses get angry-cute brows and a bigger frame."""
    brows = (f'<path d="M98 132 L132 142" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             f'<path d="M188 138 L158 146" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>') if boss else ""
    mouth = (f'<path d="M120 200 Q145 186 170 200" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
             f'<path d="M132 196 l4 8 l4 -9 M150 194 l4 9 l4 -8" fill="#fff" stroke="{INK}" stroke-width="2"/>') if boss else \
            f'<path d="M122 198 Q132 190 142 198 Q152 206 162 196" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
    return svg(size, size, f'''<g transform="scale({size/300})">
 {back}
 <g id="stem"><rect x="196" y="40" width="12" height="130" rx="6" fill="{dark}"/>
  <path d="M208 42 Q250 52 246 92 Q232 70 208 74Z" fill="{dark}"/></g>
 <g id="body"><path d="M60 170 Q52 100 120 92 Q196 84 212 150 Q228 222 150 236 Q70 248 60 170Z" fill="{body}"/>
  <path d="M84 150 Q90 110 128 106 Q100 120 96 152Z" fill="{light}"/></g>
 <ellipse cx="115" cy="160" rx="16" ry="19" fill="#fff"/><circle cx="119" cy="163" r="9" fill="{INK}"/><circle cx="122" cy="159" r="3" fill="#fff"/>
 <ellipse cx="170" cy="155" rx="13" ry="15" fill="#fff"/><circle cx="167" cy="158" r="7" fill="{INK}"/><circle cx="169" cy="155" r="2.5" fill="#fff"/>
 {brows}{mouth}
 <ellipse cx="98" cy="190" rx="11" ry="7" fill="{BLUSH}" opacity=".8"/><ellipse cx="185" cy="184" rx="10" ry="6" fill="{BLUSH}" opacity=".8"/>
 <g id="feet" fill="{dark}"><ellipse cx="110" cy="240" rx="20" ry="10"/><ellipse cx="170" cy="238" rx="20" ry="10"/></g>
 <g id="sour-notes" fill="none" stroke="#ff6b8b" stroke-width="4" stroke-linecap="round">
  <path d="M250 120 l10 -6 l-4 12 l10 -4"/><path d="M30 100 l8 8 l-10 2 l8 8"/></g>
 {accessory}
</g>''')


def crown(color="#ffd34d"):
    return (f'<path d="M92 104 L100 62 L122 88 L140 52 L158 86 L180 60 L184 102 Q140 92 92 104Z" fill="{color}" stroke="#e0a800" stroke-width="3" stroke-linejoin="round"/>'
            '<circle cx="140" cy="80" r="6" fill="#ff6b8b"/>')


BOSSES = {
    # 1 Sumatra — leafy crown
    "fals_boss_1": ("#4fb38a", "#2c6e57", "#86dcb7", crown() +
                    '<g fill="#3a9a5b"><path d="M70 110 Q60 70 96 80 Q90 100 70 110Z"/><path d="M200 106 Q222 70 190 74 Q190 96 200 106Z"/></g>'),
    # 2 Jawa — batik-dotted scarf
    "fals_boss_2": ("#d9925b", "#7a4a2a", "#f2c097", crown() +
                    '<path d="M74 214 Q140 250 214 206 L222 226 Q140 270 66 232Z" fill="#7a2e2e"/>'
                    '<g fill="#ffd34d"><circle cx="96" cy="230" r="4"/><circle cx="122" cy="240" r="4"/><circle cx="150" cy="242" r="4"/><circle cx="178" cy="234" r="4"/><circle cx="204" cy="222" r="4"/></g>'),
    # 3 Kalimantan — leaf umbrella
    "fals_boss_3": ("#e0874a", "#8a4720", "#f5b78a", crown() +
                    '<path d="M30 70 Q70 20 120 60 Q90 56 60 80Z" fill="#3a9a5b"/><rect x="72" y="62" width="5" height="60" rx="2" fill="#6b4a2a" transform="rotate(-20 74 62)"/>'),
    # 4 Sulawesi — boat-sail hat (pinisi)
    "fals_boss_4": ("#5aa0e0", "#2a5a8a", "#9cc8f2", '<path d="M110 100 L140 20 L140 98Z" fill="#fff6d6" stroke="#c9b27a" stroke-width="3"/>'
                    '<path d="M146 98 L146 34 L186 96Z" fill="#fff6d6" stroke="#c9b27a" stroke-width="3"/><path d="M96 100 Q140 116 196 100 L188 112 Q140 124 104 112Z" fill="#8a5a2a"/>'),
    # 5 Bali & Nusa Tenggara — sunglasses + hibiscus
    "fals_boss_5": ("#f06aa0", "#8a2a55", "#f7a8c8", crown() +
                    '<g><rect x="94" y="146" width="42" height="28" rx="12" fill="#2d2440"/><rect x="152" y="140" width="38" height="28" rx="12" fill="#2d2440"/><path d="M136 158 L152 154" stroke="#2d2440" stroke-width="5"/></g>'
                    '<g transform="translate(66 120)"><circle r="10" fill="#ff4d4d" cx="0" cy="-12"/><circle r="10" fill="#ff4d4d" cx="12" cy="0"/><circle r="10" fill="#ff4d4d" cx="0" cy="12"/><circle r="10" fill="#ff4d4d" cx="-12" cy="0"/><circle r="6" fill="#ffd34d"/></g>'),
    # 6 Maluku & Papua — bird-of-paradise plume
    "fals_boss_6": ("#7a5ad8", "#3a2a78", "#b597ee", crown(),),
}
PLUME = ('<g id="plume"><path d="M200 200 Q290 170 286 90 Q262 150 210 180Z" fill="#ffb347"/>'
         '<path d="M206 214 Q296 214 296 140 Q270 190 212 200Z" fill="#ff6b8b"/>'
         '<path d="M196 190 Q270 140 250 70 Q240 130 200 170Z" fill="#ffd34d"/></g>')

MINIONS = {
    "fals_minion_1": ("#8f6ad8", "#4b3a78", "#b597ee", ""),
    "fals_minion_2": ("#5ec2c2", "#2a6e6e", "#9ee2e2", '<path d="M150 90 Q156 60 176 66" fill="none" stroke="#2a6e6e" stroke-width="6" stroke-linecap="round"/><circle cx="178" cy="64" r="8" fill="#ffd34d"/>'),
    "fals_minion_3": ("#f2a33a", "#8a5a1a", "#f8cf8a", '<g fill="#8a5a1a"><path d="M96 104 l10 -26 l12 22Z"/><path d="M150 96 l14 -26 l8 24Z"/></g>'),
}


# ---------------------------------------------------------------- Alpanica

def alpanica_variant(extra, *, drop_eyes=False, drop_mouth=False):
    src = open(ALPANICA).read()
    if drop_eyes:
        src = re.sub(r'<path [^>]*layerName="Oval 1[45]"[^>]*/>', '', src)
    if drop_mouth:
        src = re.sub(r'<path [^>]*fill="#6b665d"[^>]*/>', '', src)
    return src.replace('</svg>', extra + '\n</svg>')


ATTACK = '''<g id="attack">
 <path d="M54 88 L86 96" stroke="#494949" stroke-width="6" stroke-linecap="round"/>
 <path d="M150 90 L120 96" stroke="#494949" stroke-width="6" stroke-linecap="round"/>
 <path d="M92 134 Q101 128 110 134 Q108 146 101 146 Q94 146 92 134Z" fill="#6b665d"/>
 <g fill="#ffd34d" stroke="#e0a800" stroke-width="2">
  <path d="M190 120 v-34 l24 -6 v34"/><ellipse cx="184" cy="122" rx="9" ry="7"/><ellipse cx="208" cy="114" rx="9" ry="7"/>
  <path d="M250 150 v-30"/><ellipse cx="244" cy="152" rx="9" ry="7"/><path d="M250 120 q14 6 10 20" fill="none"/>
 </g>
 <g stroke="#ffd34d" stroke-width="5" stroke-linecap="round"><path d="M160 136 L182 140"/><path d="M162 152 L190 162"/><path d="M158 120 L176 112"/></g>
</g>'''

HAPPY = open(os.path.join(ROOT, "src", "alpanica_happy.svg")).read().split('<g id="happy-face">',1)[1].rsplit('</svg>',1)[0]
HAPPY = '<g id="happy-face">' + HAPPY

GLASSES = '''<g id="glasses" fill="#bfe6ff" fill-opacity=".35" stroke="#2d2440" stroke-width="5">
 <rect x="48" y="86" width="46" height="42" rx="14"/><rect x="111" y="86" width="46" height="42" rx="14"/>
 <path d="M94 104 Q102 96 111 104" fill="none"/></g>'''
CROWN = '''<g id="crown"><path d="M84 46 L90 6 L108 30 L124 0 L140 30 L158 6 L162 46 Q124 38 84 46Z" fill="#ffd34d" stroke="#e0a800" stroke-width="3" stroke-linejoin="round"/>
 <circle cx="124" cy="26" r="6" fill="#ff6b8b"/><circle cx="100" cy="36" r="4" fill="#5aa0e0"/><circle cx="148" cy="36" r="4" fill="#4fb38a"/></g>'''


# ---------------------------------------------------------------- UI icons

def badge(fill, glyph, size=128):
    return svg(size, size, f'''<g transform="scale({size/128})">
 <circle cx="64" cy="68" r="56" fill="#000" opacity=".12"/>
 <circle cx="64" cy="62" r="56" fill="{fill}"/><circle cx="64" cy="62" r="46" fill="#fff" opacity=".18"/>
 {glyph}</g>''')


ICONS = {
    "icon_coin": badge("#ffc83d", '<circle cx="64" cy="62" r="40" fill="none" stroke="#e0a800" stroke-width="5"/>'
                       '<path d="M70 38 v38" stroke="#8a5a00" stroke-width="8" stroke-linecap="round"/><ellipse cx="60" cy="78" rx="13" ry="10" fill="#8a5a00"/>'
                       '<path d="M70 38 q16 4 14 20" fill="none" stroke="#8a5a00" stroke-width="7" stroke-linecap="round"/>'),
    "icon_stage_battle": badge("#ff6b8b", '<path d="M72 22 L42 68 H62 L54 102 L88 52 H66Z" fill="#fff"/>'),
    "icon_stage_echo": badge("#5aa0e0", '<path d="M52 40 Q52 24 70 24 Q90 24 90 46 Q90 60 76 68 Q70 72 70 84 Q70 98 58 98" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/>'
                             '<path d="M64 48 Q64 40 72 40 Q80 40 78 52" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round"/>'),
    "icon_stage_song": badge("#4fb38a", '<path d="M56 86 V34 L90 26 V78" fill="none" stroke="#fff" stroke-width="8" stroke-linejoin="round"/>'
                             '<ellipse cx="48" cy="88" rx="13" ry="10" fill="#fff"/><ellipse cx="82" cy="80" rx="13" ry="10" fill="#fff"/>'),
    "icon_stage_boss": badge("#8f6ad8", '<path d="M30 82 L36 36 L52 58 L64 30 L76 58 L92 36 L98 82Z" fill="#ffd34d" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>'),
    "icon_stage_finale": badge("#d64545", '<rect x="40" y="24" width="6" height="76" rx="3" fill="#fff"/>'
                               '<path d="M46 28 H94 V48 H46Z" fill="#ff3b3b"/><path d="M46 48 H94 V68 H46Z" fill="#fff"/>'),
}


# ---------------------------------------------------------------- Map & backgrounds

ISLAND_SHAPES = {  # stylised silhouettes on a 1000x600 card
    1: "M120 120 Q300 140 520 300 Q760 470 880 520 Q700 540 520 430 Q300 300 140 200 Q90 160 120 120Z",       # Sumatra: long diagonal
    2: "M80 300 Q260 250 520 280 Q760 300 930 330 Q760 380 520 360 Q280 350 80 300Z",                       # Jawa: long horizontal
    3: "M300 110 Q560 70 720 200 Q780 360 620 480 Q420 540 290 420 Q190 300 300 110Z",                       # Kalimantan: big round
    4: "M380 110 Q470 140 440 260 L620 180 Q520 300 470 320 L620 450 Q500 440 440 380 L420 520 Q360 400 390 300 L260 360 Q340 280 380 110Z",  # Sulawesi: K shape
    5: "M120 300 Q200 260 260 300 Q200 340 120 300Z M340 310 Q420 280 500 320 Q420 350 340 310Z M560 330 Q660 300 760 340 Q660 370 560 330Z M800 340 Q860 320 900 350 Q850 370 800 340Z",  # Bali & NT chain
    6: "M90 260 Q180 230 220 280 Q170 320 90 260Z M260 200 Q330 180 360 240 Q300 270 260 200Z M440 260 Q620 170 820 230 Q930 280 900 380 Q760 430 620 380 Q500 340 440 260Z",  # Maluku + Papua
}
ISLAND_TINT = {1: "#7cc47a", 2: "#9ccf6a", 3: "#5fae6a", 4: "#86c98a", 5: "#b8d870", 6: "#6dba84"}


def palm(x, y, s=1.0):
    return (f'<g transform="translate({x} {y}) scale({s})"><path d="M0 0 Q6 -40 0 -80" stroke="#8a5a2a" stroke-width="8" fill="none" stroke-linecap="round"/>'
            '<g fill="#3a9a5b"><path d="M0 -80 Q-40 -96 -60 -70 Q-30 -82 0 -78Z"/><path d="M0 -80 Q40 -100 62 -72 Q30 -84 0 -78Z"/>'
            '<path d="M0 -80 Q-20 -120 -4 -130 Q-6 -104 2 -80Z"/><path d="M0 -80 Q30 -116 48 -110 Q24 -100 2 -80Z"/></g></g>')


LANDMARK = {  # simple, non-sacred motifs
    1: palm(300, 250) + palm(620, 420, .8),
    2: '<path d="M440 300 L480 230 L520 300Z M500 300 L560 200 L620 300Z" fill="#6f8a6a"/><path d="M548 216 L560 200 L572 216Z" fill="#fff"/>' + palm(780, 330, .7),
    3: ''.join(f'<g transform="translate({x} {y})"><rect x="-6" y="-10" width="12" height="40" fill="#6b4a2a"/><circle cy="-30" r="34" fill="#3a8a4a"/></g>'
               for x, y in [(420, 260), (520, 220), (600, 320), (480, 380)]),
    4: '<g transform="translate(520 470)"><path d="M-80 0 Q0 40 80 0 L60 24 Q0 44 -60 24Z" fill="#8a5a2a"/>'
       '<path d="M-10 -4 V-110 L-70 -6Z" fill="#fff6d6"/><path d="M0 -4 V-120 L60 -6Z" fill="#fff6d6"/></g>',
    5: '<circle cx="840" cy="120" r="54" fill="#ffd34d"/>' + palm(220, 300, .6) + palm(660, 330, .6),
    6: '<path d="M600 330 L680 200 L760 330Z" fill="#7a8a9a"/><path d="M660 232 L680 200 L700 232 Q680 222 660 232Z" fill="#fff"/>'
       '<g transform="translate(300 160) scale(.9)"><path d="M0 0 Q30 -30 60 0 Q30 10 0 0Z" fill="#ff6b8b"/><path d="M60 0 Q110 20 130 70 Q90 40 60 10Z" fill="#ffb347"/></g>',
}


def island(n):
    waves = ''.join(f'<path d="M{x} {y} q15 -10 30 0 t30 0" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="4" stroke-linecap="round"/>'
                    for x, y in [(60, 520), (760, 90), (140, 80), (820, 560), (420, 560)])
    shape = ISLAND_SHAPES[n]
    return svg(1000, 600, f'''<defs><linearGradient id="sea" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fd0f0"/><stop offset="1" stop-color="#3fa2d8"/></linearGradient></defs>
<rect width="1000" height="600" rx="48" fill="url(#sea)"/>{waves}
<path d="{shape}" fill="#f6e7b0" transform="translate(0 10)" opacity=".9"/>
<path d="{shape}" fill="{ISLAND_TINT[n]}" stroke="#f6e7b0" stroke-width="10" stroke-linejoin="round"/>
{LANDMARK[n]}''')


def ocean_tile():
    waves = ''.join(f'<path d="M{x} {y} q16 -10 32 0 t32 0" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="4" stroke-linecap="round"/>'
                    for x, y in [(40, 60), (300, 140), (120, 300), (380, 420), (200, 470), (420, 250)])
    return svg(512, 512, f'<rect width="512" height="512" fill="#5ab8e6"/>{waves}')


def bg_concert():
    lights = ''.join(f'<path d="M{x} 0 L{x-160} 1032 L{x+160} 1032Z" fill="#fff6d6" opacity=".10"/>' for x in (300, 688, 1076))
    bulbs = ''.join(f'<circle cx="{x}" cy="40" r="14" fill="#ffd34d"/>' for x in range(80, 1376, 120))
    return svg(1376, 1032, f'''<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d2440"/><stop offset="1" stop-color="#4b3a78"/></linearGradient></defs>
<rect width="1376" height="1032" fill="url(#g)"/>{lights}
<path d="M0 0 H260 Q200 500 240 1032 H0Z" fill="#c23b4e"/><path d="M1376 0 H1116 Q1176 500 1136 1032 H1376Z" fill="#c23b4e"/>
<path d="M0 0 H1376 V90 Q688 150 0 90Z" fill="#a52f40"/>{bulbs}
<g stroke="#fff" stroke-opacity=".12" stroke-width="6">{"".join(f'<path d="M{x} 0 Q{x-20} 500 {x} 1032"/>' for x in (60, 140, 200, 1176, 1236, 1316))}</g>''')


def bg_ceremony():
    return svg(1376, 1032, '''<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#cfe9f7"/><stop offset="1" stop-color="#fdf6e3"/></linearGradient></defs>
<rect width="1376" height="1032" fill="url(#sky)"/>
<g fill="#fff" opacity=".8"><ellipse cx="260" cy="180" rx="120" ry="34"/><ellipse cx="1060" cy="140" rx="150" ry="38"/></g>
<rect x="1080" y="160" width="14" height="760" rx="7" fill="#b9b9b9"/><circle cx="1087" cy="156" r="14" fill="#d9b44a"/>
<path d="M1094 180 H1300 V280 H1094Z" fill="#e8343a"/><path d="M1094 280 H1300 V380 H1094Z" fill="#ffffff" stroke="#e5e5e5" stroke-width="2"/>
<path d="M0 900 Q688 860 1376 900 V1032 H0Z" fill="#cfe3b8"/>''')


# ---------------------------------------------------------------- write

def assets():
    out = {}
    for name, (b, d, l, acc) in MINIONS.items():
        out[name] = fals(b, d, l, accessory=acc)
    for name, spec in BOSSES.items():
        b, d, l, acc = spec
        out[name] = fals(b, d, l, size=420, boss=True, accessory=acc, back=PLUME if name == "fals_boss_6" else "")
    out["alpanica_attack"] = alpanica_variant(ATTACK, drop_eyes=False, drop_mouth=True)
    out["alpanica_happy"] = alpanica_variant(HAPPY, drop_eyes=True, drop_mouth=True)
    out["alpanica_outfit_glasses"] = alpanica_variant(GLASSES)
    out["alpanica_outfit_crown"] = alpanica_variant(CROWN)
    out["alpanica_outfit_royal"] = alpanica_variant(GLASSES + CROWN)
    out.update(ICONS)
    for n in range(1, 7):
        out[f"map_island_{n}"] = island(n)
    out["map_ocean"] = ocean_tile()
    out["stage_bg_concert"] = bg_concert()
    out["stage_bg_ceremony"] = bg_ceremony()
    return out


def install(name, text):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(text)
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, name + ".svg"), "w") as f:
        f.write(text)
    contents = {"images": [{"filename": name + ".svg", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
                "properties": {"preserves-vector-representation": True}}
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


if __name__ == "__main__":
    os.makedirs(CATALOG, exist_ok=True)
    with open(os.path.join(CATALOG, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    all_assets = assets()
    for name, text in all_assets.items():
        install(name, text)
    print(f"Generated {len(all_assets)} assets → {CATALOG}")
