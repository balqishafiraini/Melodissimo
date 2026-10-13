#!/usr/bin/env python3
"""Backsound pipeline for Melodissimo (see BACKSOUND_PLAN.md).

Run through the venv, with -I (R2):
    Scripts/backsound/.venv/bin/python -I Scripts/backsound/backsound.py <cmd> ...

One file on purpose (R3): -I removes the script folder from sys.path.
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BS = ROOT / "Scripts" / "backsound"
WORK = BS / "work"
NOTE_SWIFT = ROOT / "Melodissimo" / "Models" / "Music" / "Note.swift"

# --------------------------------------------------------------------------
# Shared helpers
# --------------------------------------------------------------------------

# (id, label, sound, semitone). MIDI = 53 + semitone. Mirrors Note.swift (selftest checks it).
NOTE_TABLE = [
    (1, "4.", "f1", 0), (2, "5.", "g1", 2), (3, "6.", "a1", 4), (4, "7.", "b1", 6),
    (5, "1", "c2", 7), (6, "2", "d2", 9), (7, "3", "e2", 11), (8, "4", "f2", 12),
    (9, "5", "g2", 14), (10, "6", "a2", 16), (11, "7", "b2", 18), (12, "1˙", "c3", 19),
    (13, "2˙", "d3", 21), (14, "3˙", "e3", 23), (15, "4˙", "f3", 24), (16, "5˙", "g3", 26),
    (17, "6˙", "a3", 28), (18, "7˙", "b3", 30), (19, "1˙˙", "c4", 31),
    (20, "4.#", "f1s", 1), (21, "5.#", "g1s", 3), (22, "6.#", "a1s", 5), (23, "1#", "c2s", 8),
    (24, "2#", "d2s", 10), (25, "4#", "f2s", 13), (26, "5#", "g2s", 15), (27, "6#", "a2s", 17),
    (28, "1˙#", "c3s", 20), (29, "2˙#", "d3s", 22), (30, "4˙#", "f3s", 25),
    (31, "5˙#", "g3s", 27), (32, "6˙#", "a3s", 29),
]
ID_BY_LABEL = {label: i for i, label, _, _ in NOTE_TABLE}
LABEL_BY_ID = {i: label for i, label, _, _ in NOTE_TABLE}
SEMITONE_BY_ID = {i: s for i, _, _, s in NOTE_TABLE}


def midi_of(key_id):
    return 53 + SEMITONE_BY_ID[key_id]


def load_manifest():
    return json.loads((BS / "songs.json").read_text(encoding="utf-8"))


def select(manifest, only):
    out = [s for s in manifest if only is None or s["slug"] == only]
    if not out:
        sys.exit(f"no song with slug {only!r}")
    return out


class RefError(Exception):
    pass


SLOT_COUNTS = (2, 3, 4, 6, 8)


def parse_pitch(tok):
    """Label (or ASCII alias with ') -> key id, else None."""
    return ID_BY_LABEL.get(tok.replace("'", "˙"))


def parse_ref_text(text, name="<text>"):
    """Parse the §3.2 melody format -> (header dict, [(k, b, d)], [(bar, time)], bars_info).

    bars_info is a list of (bar_number, start_beat, beats_in_bar); the pickup bar is number 0.
    """
    header, body, in_body = {}, [], False
    for ln, raw in enumerate(text.splitlines(), 1):
        if not in_body:
            line = raw.strip()
            if line == "---":
                in_body = True
            elif line and not line.startswith("#"):
                if ":" not in line:
                    raise RefError(f"{name}:{ln}: header line without ':' -> {line!r}")
                k, v = line.split(":", 1)
                header[k.strip()] = v.split("#")[0].strip() if k.strip() != "sources" else v.strip()
        else:
            body.append((ln, raw))
    if not in_body:
        raise RefError(f"{name}: missing '---' separator")
    bpb = int(header.get("beats_per_bar", 4))
    pickup = float(header.get("pickup", 0))
    if pickup < 0 or pickup >= bpb:
        raise RefError(f"{name}: pickup {pickup} must be in [0, beats_per_bar)")

    anchors, music_tokens = [], []
    for ln, raw in body:
        line = raw.split("#")[0].strip()
        if not line:
            continue
        if line.startswith("@anchor"):
            m = re.fullmatch(r"@anchor\s+bar=(\d+)\s+time=([0-9.]+)", line)
            if not m:
                raise RefError(f"{name}:{ln}: bad anchor {line!r}")
            anchors.append((int(m.group(1)), float(m.group(2))))
            continue
        line = line.replace("||", "|")
        for t in re.findall(r"\[[^\]]*\]|\||[^\s|\[\]]+", line):
            music_tokens.append((ln, t))

    # split into bars
    bars, cur = [], []
    for ln, t in music_tokens:
        if t == "|":
            if cur:
                bars.append(cur)
            cur = []
        else:
            cur.append((ln, t))
    if cur:
        bars.append(cur)

    notes, bars_info = [], []
    pos = (bpb - pickup) if pickup > 0 else 0.0
    last = None
    for bi, bar in enumerate(bars):
        number = bi if pickup > 0 else bi + 1
        start = pos
        for ln, t in bar:
            if t.startswith("["):
                slots = t[1:-1].split()
                if len(slots) not in SLOT_COUNTS:
                    raise RefError(f"{name}:{ln}: bar {number}: group {t} has {len(slots)} slots (need 2,3,4,6,8)")
                dur = 1.0 / len(slots)
                items = slots
            else:
                items, dur = [t], 1.0
            for s in items:
                if s == "-":
                    if last is not None:
                        last["d"] += dur
                elif s == "0":
                    last = None
                else:
                    k = parse_pitch(s)
                    if k is None:
                        raise RefError(f"{name}:{ln}: bar {number}: unknown token {s!r}")
                    last = {"k": k, "b": pos, "d": dur}
                    notes.append(last)
                pos += dur
        length = pos - start
        expected = pickup if (pickup > 0 and bi == 0) else bpb
        is_last = bi == len(bars) - 1
        if abs(length - expected) > 1e-6 and not (is_last and length < expected):
            raise RefError(f"{name}: bar {number} holds {length:g} beats, expected {expected:g}")
        bars_info.append((number, start, length))
    out = [(n["k"], round(n["b"], 6), round(n["d"], 6)) for n in notes]
    return header, out, anchors, bars_info


def parse_ref(path):
    path = Path(path)
    return parse_ref_text(path.read_text(encoding="utf-8"), path.name)


def chart_to_dsl(notes, beats_per_bar=4, pickup=0, bars_per_line=4):
    """Inverse of parse_ref: [(k, b, d)] -> DSL body text (no header)."""
    tol = 0.01
    notes = sorted(notes, key=lambda n: (n[1], n[0]))
    if not notes:
        return "||"
    end = max(b + d for _, b, d in notes)
    first = (beats_per_bar - pickup) if pickup > 0 else 0
    n_beats = int(math.ceil(end - first - tol))
    bar_lens = []
    if pickup > 0:
        bar_lens.append(int(pickup))
    remaining = n_beats - sum(bar_lens)
    while remaining > 0:
        bar_lens.append(min(beats_per_bar, remaining))
        remaining -= beats_per_bar

    def on_grid(x, n):
        return abs(x * n - round(x * n)) < tol * n

    beat_tokens = []
    for i in range(n_beats):
        b0 = first + i
        inner = [x for _, nb, nd in notes for x in (nb, nb + nd) if b0 + tol < x < b0 + 1 - tol]
        n = 1
        for cand in (1, 2, 3, 4, 6, 8):
            if all(on_grid(x - b0, cand) for x in inner):
                n = cand
                break
        else:
            n = 8
        toks = []
        for s in range(n):
            t = b0 + s / n
            starts = [nn for nn in notes if abs(nn[1] - t) < tol]
            if starts:
                toks.append(LABEL_BY_ID[starts[0][0]])
            elif any(nb < t - tol and t + 1e-9 < nb + nd - tol for _, nb, nd in notes):
                toks.append("-")
            else:
                toks.append("0")
        beat_tokens.append(toks[0] if n == 1 else "[" + " ".join(toks) + "]")

    bars, idx = [], 0
    for ln_ in bar_lens:
        bars.append(" ".join(beat_tokens[idx:idx + ln_]))
        idx += ln_
    lines = []
    for i in range(0, len(bars), bars_per_line):
        chunk = bars[i:i + bars_per_line]
        lines.append("| ".join(chunk) + (" ||" if i + bars_per_line >= len(bars) else " |"))
    return "\n".join(lines)


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

def cmd_selftest(args):
    # 1. NOTE_TABLE vs Note.swift
    src = NOTE_SWIFT.read_text(encoding="utf-8")
    rows = [(int(a), b, c, int(d)) for a, b, c, d in re.findall(
        r'Note\(id:\s*(\d+),\s*label:\s*"([^"]+)",\s*sound:\s*"([^"]+)",\s*semitone:\s*(\d+)\)', src)]
    assert rows == NOTE_TABLE, "NOTE_TABLE differs from Note.swift"
    # 2. alias
    assert parse_pitch("1'") == ID_BY_LABEL["1˙"] and parse_pitch("1''") == ID_BY_LABEL["1˙˙"]
    assert parse_pitch("5.") == 2 and parse_pitch("4#") == 25
    # 3. round trip on an invented melody (3/4 with a pickup, triplet, dotted figure, tie over bar line)
    demo = """title: Demo
slug: demo
beats_per_bar: 4
pickup: 1
---
5. | 1 - 3 [2 1] | 5 - - 0 | [6 5 4] [3 - - 2] 1' 1 | - 7. 6.# 5. | 4.# - - - ||
"""
    header, notes, anchors, bars = parse_ref_text(demo, "demo")
    assert notes[0] == (2, 3.0, 1.0), notes[0]                 # pickup note sits at b = 4 - 1
    assert bars[1][:2] == (1, 4.0)                             # bar 1 starts at beat 4
    text = chart_to_dsl(notes, 4, 1)
    h2 = "beats_per_bar: 4\npickup: 1\n---\n" + text
    _, notes2, _, _ = parse_ref_text(h2, "roundtrip")
    assert notes == notes2, f"round trip mismatch\n{notes}\n{notes2}\n{text}"
    text2 = chart_to_dsl(notes2, 4, 1)
    assert text == text2, f"DSL not stable\n{text}\n{text2}"
    # 4. error reporting
    try:
        parse_ref_text("beats_per_bar: 4\n---\n1 2 3 | 1 2 3 4 ||", "bad")
        raise AssertionError("short bar not rejected")
    except RefError as e:
        assert "bar 1" in str(e)
    print("selftest OK")


def cmd_stub(args):
    sys.exit(f"'{args.cmd}' is not implemented yet (see BACKSOUND_PLAN.md)")


def main(argv=None):
    p = argparse.ArgumentParser(description="Melodissimo backsound pipeline")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selftest").set_defaults(func=cmd_selftest)
    for name in ("fetch", "cut", "analyze", "json2ref", "check-ref", "build", "emit-swift"):
        sp = sub.add_parser(name)
        sp.add_argument("--only")
        sp.set_defaults(func=cmd_stub)
    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
