#!/usr/bin/env python3
"""Generates Melodissimo game art as SVG in Alpanica's flat kawaii style.

Run:  python3 Design/generate_assets.py
Writes Design/svg/*.svg and installs each one as a vector imageset in
Melodissimo/Assets.xcassets/Game/. Re-run after tweaking; it overwrites only its own files.
"""
import json, math, os, re

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
    # 5 Bali — sunglasses + hibiscus
    "fals_boss_5": ("#f06aa0", "#8a2a55", "#f7a8c8", crown() +
                    '<g><rect x="94" y="146" width="42" height="28" rx="12" fill="#2d2440"/><rect x="152" y="140" width="38" height="28" rx="12" fill="#2d2440"/><path d="M136 158 L152 154" stroke="#2d2440" stroke-width="5"/></g>'
                    '<g transform="translate(66 120)"><circle r="10" fill="#ff4d4d" cx="0" cy="-12"/><circle r="10" fill="#ff4d4d" cx="12" cy="0"/><circle r="10" fill="#ff4d4d" cx="0" cy="12"/><circle r="10" fill="#ff4d4d" cx="-12" cy="0"/><circle r="6" fill="#ffd34d"/></g>'),
    # 6 Nusa Tenggara — komodo spikes and an ikat headband
    "fals_boss_6": ("#9aa84a", "#55602a", "#c9d48a",
                    '<g fill="#55602a"><path d="M62 150 l-22 -12 l16 26Z"/><path d="M66 124 l-20 -22 l6 32Z"/><path d="M82 102 l-12 -28 l22 22Z"/></g>'
                    '<path d="M86 116 Q150 96 214 124 L210 142 Q150 116 90 134Z" fill="#7a2e2e"/>'
                    '<g fill="none" stroke="#ffd34d" stroke-width="3"><path d="M100 126 l8 -8 l8 8 l-8 8Z"/><path d="M132 118 l8 -8 l8 8 l-8 8Z"/>'
                    '<path d="M164 118 l8 -8 l8 8 l-8 8Z"/><path d="M194 126 l8 -8 l8 8 l-8 8Z"/></g>'
                    '<path d="M150 214 q8 14 2 24 M158 214 q14 8 14 20" fill="none" stroke="#ff4d4d" stroke-width="4" stroke-linecap="round"/>'),
    # 7 Maluku — clove crown, nutmeg and a starfish
    "fals_boss_7": ("#3fb8b0", "#1f6a66", "#8ee0da",
                    '<path d="M92 104 L96 64 L112 90 L126 56 L140 88 L154 56 L168 90 L184 64 L186 104 Q140 92 92 104Z" fill="#8a4a2a" stroke="#5a2e18" stroke-width="3" stroke-linejoin="round"/>'
                    '<g fill="#ffd34d"><circle cx="96" cy="62" r="6"/><circle cx="126" cy="54" r="6"/><circle cx="154" cy="54" r="6"/><circle cx="184" cy="62" r="6"/></g>'
                    '<g transform="translate(236 212)"><circle r="20" fill="#b07a3a"/><path d="M-14 -12 Q0 -30 14 -12 M-18 2 Q0 -18 18 2" fill="none" stroke="#e8343a" stroke-width="5" stroke-linecap="round"/></g>'
                    '<path d="M52 212 l6 -16 l6 16 l16 2 l-12 10 l4 16 l-14 -8 l-14 8 l4 -16 l-12 -10Z" fill="#ff8a5b" stroke="#c9563a" stroke-width="2" stroke-linejoin="round"/>'),
    # 8 Papua — bird-of-paradise plume
    "fals_boss_8": ("#7a5ad8", "#3a2a78", "#b597ee", crown(),),
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

def alpanica_variant(extra, *, drop_eyes=False, drop_mouth=False, drop_smile=False):
    src = open(ALPANICA).read()
    if drop_eyes:
        src = re.sub(r'<path [^>]*layerName="Oval 1[45]"[^>]*/>', '', src)
    if drop_mouth:
        src = re.sub(r'<path [^>]*fill="#6b665d"[^>]*/>', '', src)
    if drop_smile:  # just the line mouth; the nose stays
        src = re.sub(r'<path [^>]*stroke="#6b665d"[^>]*/>', '', src)
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

# More accessories. All sit on Alpanica's 443x612 canvas: eyes at (71,108) and (134,109),
# nose at (101,136), ears at x 41-72 and 157-187 (tips at y 9), neck below y 215.
EYE_INK = "#494949"
HEADPHONES = '''<g id="headphones">
 <path d="M22 118 Q8 14 112 12 Q216 14 202 118" fill="none" stroke="#2d2440" stroke-width="13" stroke-linecap="round"/>
 <path d="M22 118 Q8 14 112 12 Q216 14 202 118" fill="none" stroke="#5a4a80" stroke-width="5" stroke-linecap="round"/>
 <rect x="-2" y="96" width="34" height="62" rx="15" fill="#ff6b8b" stroke="#2d2440" stroke-width="5"/>
 <rect x="192" y="96" width="34" height="62" rx="15" fill="#ff6b8b" stroke="#2d2440" stroke-width="5"/>
 <rect x="6" y="106" width="10" height="40" rx="5" fill="#ffb3d1"/><rect x="208" y="106" width="10" height="40" rx="5" fill="#ffb3d1"/>
 <path d="M212 112 v14 l8 -2" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/><circle cx="210" cy="128" r="3.5" fill="#fff"/>
</g>'''
BOW = '''<g id="bow" stroke="#c23b6e" stroke-width="3" stroke-linejoin="round">
 <path d="M176 74 L142 52 Q128 74 142 98Z" fill="#ff6b9d"/><path d="M176 74 L210 52 Q224 74 210 98Z" fill="#ff6b9d"/>
 <g fill="#fff" stroke="none"><circle cx="144" cy="66" r="4"/><circle cx="148" cy="84" r="3.5"/><circle cx="208" cy="66" r="4"/><circle cx="204" cy="84" r="3.5"/></g>
 <path d="M170 80 L162 108 L172 102 L178 110 L182 80Z" fill="#ff6b9d"/>
 <rect x="166" y="64" width="20" height="20" rx="8" fill="#ff8fb4"/>
</g>'''
SUNGLASSES = '''<g id="sunglasses">
 <path d="M42 88 H98 Q100 122 82 130 H58 Q40 126 42 88Z" fill="#2d2440"/>
 <path d="M107 88 H163 Q165 122 147 130 H123 Q105 126 107 88Z" fill="#2d2440"/>
 <path d="M98 94 Q102 88 107 94" fill="none" stroke="#2d2440" stroke-width="6"/>
 <path d="M42 90 L28 84 M163 90 L182 84" stroke="#2d2440" stroke-width="5" stroke-linecap="round"/>
 <g stroke="#fff" stroke-opacity=".7" stroke-width="5" stroke-linecap="round"><path d="M54 98 L66 110"/><path d="M119 98 L131 110"/></g>
 <g fill="#ffd34d"><path d="M84 96 l2 5 l5 2 l-5 2 l-2 5 l-2 -5 l-5 -2 l5 -2Z"/></g>
</g>'''


def flower(x, y, petal, r=11):
    petals = ''.join(f'<ellipse cx="{x}" cy="{y - r * .7:.1f}" rx="{r * .55:.1f}" ry="{r * .8:.1f}" fill="{petal}" transform="rotate({a} {x} {y})"/>'
                     for a in range(0, 360, 72))
    return petals + f'<circle cx="{x}" cy="{y}" r="{r * .38:.1f}" fill="#ffd34d"/>'


FLOWERS = ('<g id="flower-crown"><path d="M30 92 Q40 50 110 40 Q180 50 192 92" fill="none" stroke="#3a9a5b" stroke-width="7" stroke-linecap="round"/>'
           '<g fill="#5fbf6a"><path d="M48 66 q-14 -4 -16 -18 q14 2 16 18Z"/><path d="M172 64 q14 -6 18 -18 q-16 2 -18 18Z"/><path d="M110 40 q-4 -14 6 -22 q4 14 -6 22Z"/></g>'
           + flower(34, 88, "#fff") + flower(56, 60, "#ffb3d1", 12) + flower(84, 44, "#fff", 12) + flower(114, 38, "#ff8fb4", 14)
           + flower(144, 44, "#fff", 12) + flower(170, 58, "#ffb3d1", 12) + flower(190, 86, "#fff") + '</g>')
BLANGKON = '''<g id="blangkon">
 <path d="M26 96 Q18 8 112 4 Q206 8 198 96 Q112 78 26 96Z" fill="#6b3e1f" stroke="#3e2210" stroke-width="4" stroke-linejoin="round"/>
 <g fill="none" stroke="#d9a441" stroke-width="5" stroke-linecap="round" opacity=".9">
  <path d="M40 70 L70 26"/><path d="M66 78 L104 14"/><path d="M100 76 L140 12"/><path d="M136 78 L170 24"/><path d="M168 82 L190 50"/></g>
 <g fill="#f2d48a"><circle cx="58" cy="52" r="4"/><circle cx="88" cy="42" r="4"/><circle cx="122" cy="40" r="4"/><circle cx="154" cy="50" r="4"/><circle cx="104" cy="66" r="3"/><circle cx="140" cy="66" r="3"/></g>
 <path d="M24 96 Q112 74 200 96 L200 106 Q112 86 24 106Z" fill="#3e2210"/>
 <path d="M14 74 Q2 92 16 104 Q28 94 26 78Z" fill="#6b3e1f" stroke="#3e2210" stroke-width="3"/>
</g>'''
SCARF = '''<g id="scarf">
 <path d="M18 214 Q100 244 186 210 L190 246 Q100 282 16 250Z" fill="#c23b4e" stroke="#7a1f2c" stroke-width="4" stroke-linejoin="round"/>
 <path d="M140 236 L176 330 L150 336 L124 246Z" fill="#c23b4e" stroke="#7a1f2c" stroke-width="4" stroke-linejoin="round"/>
 <path d="M150 336 l2 12 M158 334 l4 12 M166 332 l5 11 M174 330 l6 10" stroke="#ffd34d" stroke-width="3" stroke-linecap="round"/>
 <path d="M24 232 l14 6 l-6 10 l14 4 l-4 10 M60 242 l14 4 l-4 10 l14 2 M98 248 l14 2 l-2 10 l14 0 M138 244 l12 -2 l0 10 l12 -4" fill="none" stroke="#ffd34d" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
 <g fill="#fff6d6"><circle cx="146" cy="270" r="4"/><circle cx="156" cy="296" r="4"/><circle cx="164" cy="318" r="3.5"/></g>
</g>'''
CONDUCTOR = '''<g id="conductor">
 <g transform="rotate(-8 116 34)">
  <ellipse cx="116" cy="34" rx="54" ry="10" fill="#2d2440"/>
  <path d="M88 34 L92 4 H140 L144 34Z" fill="#2d2440"/><rect x="90" y="20" width="52" height="9" fill="#c23b4e"/>
  <path d="M98 10 H112" stroke="#5a4a80" stroke-width="4" stroke-linecap="round"/></g>
 <g transform="translate(104 232)" stroke="#1b1528" stroke-width="3" stroke-linejoin="round">
  <path d="M0 0 L-30 -16 Q-36 0 -30 16Z" fill="#2d2440"/><path d="M0 0 L30 -16 Q36 0 30 16Z" fill="#2d2440"/>
  <rect x="-8" y="-8" width="16" height="16" rx="5" fill="#c23b4e"/></g>
</g>'''

# Every outfit, as the layers laid over whatever pose Alpanica is in.
OUTFITS = {
    "glasses": GLASSES, "crown": CROWN, "royal": GLASSES + CROWN,
    "bow": BOW, "headphones": HEADPHONES, "sunglasses": SUNGLASSES, "scarf": SCARF,
    "flowers": FLOWERS, "blangkon": BLANGKON, "conductor": CONDUCTOR,
}


def overlay(extra):
    """An outfit alone on Alpanica's clear canvas, so the app can lay it over any pose."""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 443.592 612.558" width="443.592" height="612.558">\n{extra}\n</svg>\n')


# ---------------------------------------------------------------- Alpanica poses
# Each pose swaps her face (drop_eyes / drop_smile remove the original features). Moving extras
# (rising notes, hearts, Zzz) are drawn by the app (CharacterMotion.swift), not baked in here.

def closed_eye(cx, cy, down=True, w=13.5):
    bend = 9 if down else -18
    return f'<path d="M{cx - w} {cy} Q{cx} {cy + bend} {cx + w} {cy}" fill="none" stroke="{EYE_INK}" stroke-width="6" stroke-linecap="round"/>'


def heart(cx, cy, s, fill):
    return (f'<path d="M{cx} {cy + s * .9:.1f} C{cx - s * 1.6:.1f} {cy - s * .1:.1f} {cx - s * .9:.1f} {cy - s * 1.2:.1f} {cx} {cy - s * .45:.1f} '
            f'C{cx + s * .9:.1f} {cy - s * 1.2:.1f} {cx + s * 1.6:.1f} {cy - s * .1:.1f} {cx} {cy + s * .9:.1f}Z" fill="{fill}"/>')


def spiral(cx, cy, turns=2.2, r=14):
    pts = []
    for i in range(90):
        t = i / 89 * turns * 2 * math.pi
        rr = r * i / 89
        pts.append(f"{cx + rr * math.cos(t):.1f} {cy + rr * math.sin(t):.1f}")
    return f'<path d="M{" L".join(pts)}" fill="none" stroke="{EYE_INK}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>'


def star(cx, cy, r, fill="#ffd34d"):
    pts = [f"{cx + (r if i % 2 == 0 else r * .45) * math.sin(i * math.pi / 5):.1f} {cy - (r if i % 2 == 0 else r * .45) * math.cos(i * math.pi / 5):.1f}"
           for i in range(10)]
    return f'<path d="M{" L".join(pts)}Z" fill="{fill}" stroke="#e0a800" stroke-width="2" stroke-linejoin="round"/>'


BLINK = f'<g id="blink">{closed_eye(71.5, 108)}{closed_eye(134, 109)}</g>'
SURPRISED = f'''<g id="surprised-face">
 <ellipse cx="71.5" cy="106" rx="15" ry="19" fill="{EYE_INK}"/><ellipse cx="134" cy="107" rx="15" ry="19" fill="{EYE_INK}"/>
 <circle cx="77" cy="99" r="5.5" fill="#fff"/><circle cx="66" cy="114" r="2.5" fill="#fff"/>
 <circle cx="139.5" cy="100" r="5.5" fill="#fff"/><circle cx="128.5" cy="115" r="2.5" fill="#fff"/>
 <path d="M56 78 Q70 68 84 76" fill="none" stroke="{EYE_INK}" stroke-width="5" stroke-linecap="round"/>
 <path d="M120 76 Q134 68 148 78" fill="none" stroke="{EYE_INK}" stroke-width="5" stroke-linecap="round"/>
 <ellipse cx="101" cy="151" rx="7.5" ry="9.5" fill="#6b665d"/><ellipse cx="101" cy="155" rx="4.5" ry="4" fill="#ff9fc4"/>
 <g fill="#ff6b8b"><path d="M206 30 L222 30 L216 76 L210 76Z"/><circle cx="213" cy="90" r="7"/>
  <path d="M234 54 L246 56 L236 90 L232 89Z" opacity=".8"/><circle cx="232" cy="100" r="5" opacity=".8"/></g>
</g>'''
SING = f'''<g id="sing-face">
 {closed_eye(71.5, 110, down=False)}{closed_eye(134, 110, down=False)}
 <ellipse cx="101" cy="149" rx="10" ry="12" fill="#6b665d"/><ellipse cx="101" cy="155" rx="6" ry="5" fill="#ff9fc4"/>
</g>'''
SLEEPY = f'''<g id="sleepy-face">
 {closed_eye(71.5, 112, w=12)}{closed_eye(134, 113, w=12)}
 <path d="M58 104 Q71.5 100 85 104 M120.5 105 Q134 101 147.5 105" fill="none" stroke="{EYE_INK}" stroke-width="3" stroke-linecap="round" opacity=".5"/>
 <ellipse cx="101" cy="150" rx="5" ry="4" fill="#6b665d"/>
</g>'''
LOVE = f'''<g id="love-face">
 {heart(71.5, 108, 15, "#ff4d7d")}{heart(134, 109, 15, "#ff4d7d")}
 <circle cx="65" cy="101" r="3.5" fill="#fff"/><circle cx="127.5" cy="102" r="3.5" fill="#fff"/>
 <path d="M91 141 Q101 144 111 141 Q110 155 101 156 Q92 155 91 141Z" fill="#6b665d"/>
 <path d="M95 150 Q101 146 107 150 Q104 155 101 155 Q98 155 95 150Z" fill="#ff9fc4"/>
</g>'''
DIZZY = f'''<g id="dizzy-face">
 {spiral(71.5, 108)}{spiral(134, 109)}
 <path d="M86 150 q5 -6 10 0 t10 0 t10 0" fill="none" stroke="#6b665d" stroke-width="4" stroke-linecap="round"/>
 <ellipse cx="112" cy="30" rx="84" ry="16" fill="none" stroke="#ffd34d" stroke-width="3" stroke-dasharray="8 10" opacity=".8"/>
 {star(40, 34, 12)}{star(150, 16, 10)}{star(186, 40, 8)}
</g>'''
THINK = f'''<g id="think-face">
 <ellipse cx="74" cy="104" rx="13.5" ry="16" fill="{EYE_INK}"/><ellipse cx="136.5" cy="105" rx="13.5" ry="16" fill="{EYE_INK}"/>
 <circle cx="79" cy="96" r="5" fill="#fff"/><circle cx="141.5" cy="97" r="5" fill="#fff"/>
 <path d="M120 80 Q134 70 150 78" fill="none" stroke="{EYE_INK}" stroke-width="5" stroke-linecap="round"/>
 <path d="M92 150 Q98 146 104 150 T114 148" fill="none" stroke="#6b665d" stroke-width="3.5" stroke-linecap="round"/>
 <g stroke="#2d2440" stroke-width="4"><circle cx="188" cy="82" r="6" fill="#fff"/><circle cx="204" cy="62" r="9" fill="#fff"/>
  <ellipse cx="246" cy="30" rx="36" ry="26" fill="#fff"/></g>
 <path d="M236 22 Q236 10 247 10 Q258 10 258 21 Q258 29 249 32 L248 38" fill="none" stroke="#8f6ad8" stroke-width="6" stroke-linecap="round"/>
 <circle cx="248" cy="47" r="4" fill="#8f6ad8"/>
</g>'''


# ---------------------------------------------------------------- Alpanica walking and running
# The legs are part of her one-piece outline, so these frames cut the outline off at the belly and
# draw four separate legs that swing from the hip. The app flips through the frames (CharacterMotion.swift)
# and adds the bob and lean, so outfits still line up.

HIP_Y = 470
LEGS = [  # hoof centre x, near (in front) or far
    (56, True), (157, False), (298, True), (391, False),
]


def leg(cx, near, angle):
    fill = "#ffffff" if near else "#e9e9e9"
    shade = "#f0f0f0" if near else "#dcdcdc"
    bottom = 604 if near else 594
    return (f'<g transform="rotate({angle} {cx} {HIP_Y})">'
            f'<rect x="{cx - 21}" y="440" width="42" height="{bottom - 440 - 10}" rx="21" fill="{fill}"/>'
            f'<circle cx="{cx - 17}" cy="512" r="12" fill="{fill}"/><circle cx="{cx + 17}" cy="540" r="11" fill="{fill}"/>'
            f'<circle cx="{cx - 16}" cy="556" r="10" fill="{shade}"/>'
            f'<rect x="{cx - 21}" y="{bottom - 30}" width="42" height="28" rx="13" fill="#000"/></g>')


def gait_frame(angles, face=""):
    """Alpanica with her legs at `angles` (degrees, + swings a foot forward, which is to her left),
    in the order of LEGS."""
    src = open(ALPANICA).read()
    src = re.sub(r'<path [^>]*layerName="Rectangle [3-6]"[^>]*/>', '', src)  # the standing hooves
    if face:
        src = re.sub(r'<path [^>]*stroke="#6b665d"[^>]*/>', '', src)
    clip = ('<defs><clipPath id="above-legs"><rect x="-60" y="-60" width="600" height="562"/>'
            '<rect x="400" y="500" width="60" height="60"/></clipPath></defs>')
    far = ''.join(leg(x, n, a) for (x, n), a in zip(LEGS, angles) if not n)
    near = ''.join(leg(x, n, a) for (x, n), a in zip(LEGS, angles) if n)
    src = src.replace('<defs/>', clip, 1)
    src = src.replace('<g id="Layer-1"', f'<g id="legs-far">{far}</g>\n<g id="legs-near">{near}</g>\n<g clip-path="url(#above-legs)" id="Layer-1"', 1)
    return src.replace('</svg>', face + '\n</svg>')


RUN_FACE = '<g id="run-face"><ellipse cx="101" cy="149" rx="8" ry="7" fill="#6b665d"/><ellipse cx="101" cy="152" rx="4.5" ry="3" fill="#ff9fc4"/></g>'
# A walk swings diagonal pairs; the app plays frames 1-2-3-2.
WALK = {1: (16, -16, -16, 16), 2: (2, -2, -2, 2), 3: (-16, 16, 16, -16)}
# A gallop: stretched out, passing, gathered under; the app plays frames 1-2-3-2.
RUN = {1: (22, 22, -34, -26), 2: (8, -4, -6, 6), 3: (-20, -12, 24, 16)}


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
    5: "M150 250 Q300 170 520 190 Q760 200 860 300 Q800 420 600 440 Q400 460 280 400 Q200 360 210 320 Q140 300 150 250Z "
       "M760 470 Q820 450 860 480 Q820 510 760 470Z",                                                        # Bali (and Nusa Penida)
    6: "M70 250 Q130 220 180 260 Q130 300 70 250Z M220 250 Q330 210 420 260 Q330 300 220 250Z "
       "M470 270 Q640 230 800 270 Q640 320 470 270Z M300 400 Q400 370 480 410 Q400 440 300 400Z "
       "M640 430 Q790 380 920 420 Q800 480 640 430Z",                                                       # Nusa Tenggara chain
    7: "M300 110 Q360 90 380 160 Q350 230 400 290 Q340 280 320 220 Q300 170 260 160 Q260 130 300 110Z "
       "M120 360 Q190 320 250 370 Q190 420 120 360Z M380 400 Q560 350 760 390 Q560 450 380 400Z "
       "M600 230 Q640 215 660 240 Q630 260 600 230Z M820 300 Q860 285 880 310 Q850 330 820 300Z",            # Maluku islands
    8: "M70 240 Q140 150 260 190 Q300 230 260 280 Q330 250 420 270 Q620 230 820 280 Q940 330 920 460 "
       "Q760 520 560 470 Q420 430 330 380 Q240 330 160 330 Q60 310 70 240Z",                                # Papua: the bird
}
ISLAND_TINT = {1: "#7cc47a", 2: "#9ccf6a", 3: "#5fae6a", 4: "#86c98a", 5: "#b8d870", 6: "#c9cf74", 7: "#79c79a", 8: "#6dba84"}


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
    5: '<circle cx="860" cy="110" r="54" fill="#ffd34d"/>'  # sun over rice terraces
       + ''.join(f'<path d="M{430 - 20 * i} {250 + 26 * i} Q{520} {236 + 26 * i} {610 + 20 * i} {250 + 26 * i}" fill="none" stroke="#5fa84a" stroke-width="8" stroke-linecap="round"/>'
                 for i in range(4))
       + palm(250, 330, .6) + palm(760, 330, .6),
    6: '<g transform="translate(560 262) scale(.9)" fill="#7b8a5a">'  # a komodo on Flores
       '<path d="M-90 0 Q-40 -26 30 -18 Q60 -20 80 -8 Q60 4 30 2 Q-20 8 -90 0Z"/>'
       '<path d="M-40 -6 l-12 22 M10 -6 l12 22 M-30 -12 l-16 -14 M20 -14 l14 -16" stroke="#7b8a5a" stroke-width="8" stroke-linecap="round"/>'
       '<circle cx="66" cy="-12" r="3" fill="#fff"/></g>'
       + '<circle cx="860" cy="110" r="44" fill="#ffd34d"/>' + palm(330, 250, .5),
    7: '<g transform="translate(560 380)">'  # nutmeg with its red mace, and a spice-trade sailboat
       '<circle r="30" fill="#b07a3a"/><path d="M-20 -18 Q0 -40 20 -18 M-26 0 Q0 -26 26 0" fill="none" stroke="#e8343a" stroke-width="6" stroke-linecap="round"/></g>'
       '<g transform="translate(720 200)"><path d="M-50 0 Q0 26 50 0 L36 18 Q0 32 -36 18Z" fill="#8a5a2a"/>'
       '<path d="M-4 -2 V-80 L-44 -4Z" fill="#fff6d6"/><path d="M4 -2 V-86 L42 -4Z" fill="#fff6d6"/></g>'
       + palm(170, 360, .5),
    8: '<path d="M600 430 L700 260 L800 430Z" fill="#7a8a9a"/><path d="M676 300 L700 260 L724 300 Q700 288 676 300Z" fill="#fff"/>'  # snowy peak
       '<g transform="translate(380 230) scale(.9)"><path d="M0 0 Q30 -30 60 0 Q30 10 0 0Z" fill="#ff6b8b"/><path d="M60 0 Q110 20 130 70 Q90 40 60 10Z" fill="#ffb347"/></g>',  # bird of paradise
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
        out[name] = fals(b, d, l, size=420, boss=True, accessory=acc, back=PLUME if name == "fals_boss_8" else "")
    out["alpanica_attack"] = alpanica_variant(ATTACK, drop_eyes=False, drop_mouth=True)
    out["alpanica_happy"] = alpanica_variant(HAPPY, drop_eyes=True, drop_mouth=True)
    out["alpanica_blink"] = alpanica_variant(BLINK, drop_eyes=True)
    for name, face in [("surprised", SURPRISED), ("sing", SING), ("sleepy", SLEEPY),
                       ("love", LOVE), ("dizzy", DIZZY), ("think", THINK)]:
        out[f"alpanica_{name}"] = alpanica_variant(face, drop_eyes=True, drop_smile=True)
    for n, angles in WALK.items():
        out[f"alpanica_walk_{n}"] = gait_frame(angles)
    for n, angles in RUN.items():
        out[f"alpanica_run_{n}"] = gait_frame(angles, face=RUN_FACE)
    for name, layers in OUTFITS.items():
        out[f"alpanica_outfit_{name}"] = alpanica_variant(layers)  # the shop and certificate picture
        out[f"alpanica_acc_{name}"] = overlay(layers)              # laid over any pose in the game
    out.update(ICONS)
    for n in range(1, 9):
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
