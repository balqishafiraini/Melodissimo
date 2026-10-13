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


VIDEO_URL = "https://www.youtube.com/watch?v=8zULnhUmem4"
FULL_DURATION = 2819.0

# Approximate start (s) of each song and the window (s) where the silence before it is searched (§2.2).
WINDOWS = {2: (85, 125), 3: (155, 195), 4: (335, 375), 5: (505, 545), 6: (715, 755), 7: (925, 965),
           8: (1075, 1115), 9: (1285, 1325), 10: (1475, 1515), 11: (1695, 1735), 12: (1895, 1935),
           13: (2085, 2125), 14: (2325, 2365), 15: (2495, 2535), 16: (2585, 2625)}
APPROX_LEN = {1: 105, 2: 70, 3: 180, 4: 170, 5: 210, 6: 210, 7: 150, 8: 210, 9: 190, 10: 220,
              11: 200, 12: 190, 13: 240, 14: 170, 15: 90, 16: 215}


def run(cmd, **kw):
    import subprocess
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.exit(f"command failed: {' '.join(map(str, cmd))}\n{r.stderr[-2000:]}")
    return r


def probe_duration(path):
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path])
    return float(r.stdout.strip())


def cmd_fetch(args):
    WORK.mkdir(parents=True, exist_ok=True)
    existing = [p for p in WORK.glob("source.*")]
    if not existing:
        run(["yt-dlp", "-f", "bestaudio", "-o", WORK / "source.%(ext)s", VIDEO_URL], timeout=1800)
        existing = list(WORK.glob("source.*"))
    src = existing[0]
    full = WORK / "full.wav"
    run(["ffmpeg", "-y", "-i", src, "-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le", full], timeout=1800)
    dur = probe_duration(full)
    print(f"{src.name} -> full.wav, {dur:.1f} s")
    assert abs(dur - FULL_DURATION) <= 3, f"unexpected duration {dur}"


def frame_db(y, sr, frame=0.02):
    import numpy as np
    n = int(sr * frame)
    m = len(y) // n
    rms = np.sqrt((y[: m * n].reshape(m, n) ** 2).mean(axis=1) + 1e-12)
    return 20 * np.log10(rms + 1e-12)


def longest_silence(db, frame, thresh, min_len=0.3):
    best, run_start = None, None
    for i, v in enumerate(list(db) + [0.0]):
        if v < thresh and run_start is None:
            run_start = i
        elif v >= thresh and run_start is not None:
            if (i - run_start) * frame >= min_len and (best is None or i - run_start > best[1] - best[0]):
                best = (run_start, i)
            run_start = None
    return best


def cmd_cut(args):
    import numpy as np
    import soundfile as sf
    songs_dir, mp3_dir = WORK / "songs", WORK / "mp3"
    songs_dir.mkdir(parents=True, exist_ok=True)
    mp3_dir.mkdir(parents=True, exist_ok=True)
    full = WORK / "full.wav"
    manifest = load_manifest()
    info = sf.info(str(full))
    sr, total = info.samplerate, info.frames
    frame = 0.02
    cuts_path = BS / "cuts.json"

    if args.from_json:
        cuts = json.loads(cuts_path.read_text())
    else:
        # boundaries[i] = (end of song i, start of song i+1)
        bounds = {}
        for n, (lo, hi) in WINDOWS.items():
            seg, _ = sf.read(str(full), start=int(lo * sr), frames=int((hi - lo) * sr), always_2d=True)
            mono = seg.mean(axis=1)
            db = frame_db(mono, sr, frame)
            kind, sil = None, None
            for th in (-45, -40, -35, -30):
                sil = longest_silence(db, frame, th)
                if sil:
                    kind = f"silence {th}dB"
                    break
            if not sil:
                sm = np.convolve(db, np.ones(10) / 10, mode="same")
                i = int(np.argmin(sm))
                sil, kind = (i, i + 1), "no-silence"
            s0, s1 = lo + sil[0] * frame, lo + sil[1] * frame
            bounds[n] = (s0 + 0.25, max(s1 - 0.05, s0 + 0.25), kind)
        head, _ = sf.read(str(full), start=0, frames=int(30 * sr), always_2d=True)
        dbh = frame_db(head.mean(axis=1), sr, frame)
        first = int(np.argmax(dbh > -45)) * frame
        tail_start = int((FULL_DURATION - 60) * sr)
        tail, _ = sf.read(str(full), start=tail_start, always_2d=True)
        dbt = frame_db(tail.mean(axis=1), sr, frame)
        last = tail_start / sr + (len(dbt) - 1 - int(np.argmax(dbt[::-1] > -45))) * frame
        cuts = []
        for song in manifest:
            n = song["n"]
            start = max(first - 0.05, 0.0) if n == 1 else bounds[n][1]
            end = min(last + 0.5, total / sr) if n == 16 else bounds[n + 1][0]
            kind = "start/end of file" if n in (1, 16) else bounds[n][2]
            if n < 16 and n > 1:
                kind = f"{bounds[n][2]} | {bounds[n + 1][2]}" if bounds[n][2] != bounds[n + 1][2] else bounds[n][2]
            cuts.append({"n": n, "slug": song["slug"], "start": round(start, 3), "end": round(end, 3),
                         "duration": round(end - start, 3), "boundary": kind})
        cuts_path.write_text(json.dumps(cuts, indent=2, ensure_ascii=False) + "\n")

    print(f"{'n':>2}  {'title':<28} {'start':>8} {'end':>8} {'dur':>7}  boundary")
    for c, song in zip(cuts, manifest):
        a, b = int(round(c["start"] * sr)), int(round(c["end"] * sr))
        data, _ = sf.read(str(full), start=a, frames=b - a, always_2d=True)
        sf.write(str(songs_dir / f"{c['n']:02d}_{c['slug']}.wav"), data, sr, subtype="PCM_16")
        run(["ffmpeg", "-y", "-i", songs_dir / f"{c['n']:02d}_{c['slug']}.wav", "-c:a", "libmp3lame", "-q:a", "2",
             "-metadata", f"title={song['title']}", mp3_dir / f"{c['n']:02d} - {song['title']}.mp3"])
        flag = ""
        if abs(c["duration"] - APPROX_LEN[c["n"]]) > 20 or not (50 <= c["duration"] <= 300):
            flag = "  <-- CHECK duration"
        mm = lambda t: f"{int(t // 60)}:{t % 60:04.1f}"
        print(f"{c['n']:>2}  {song['title']:<28} {mm(c['start']):>8} {mm(c['end']):>8} {c['duration']:>7.1f}  {c['boundary']}{flag}")


MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
PC_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
MIDI_TO_ID = {midi_of(i): i for i, _, _, _ in NOTE_TABLE}


def wrap_shift(do_pc):
    """Semitone shift (−6…+5) that moves `do` to C."""
    return ((-do_pc + 6) % 12) - 6


def key_scores(chroma):
    import numpy as np
    out = []
    for tonic in range(12):
        for mode, prof in (("major", MAJOR), ("minor", MINOR)):
            r = np.corrcoef(chroma, np.roll(prof, tonic))[0, 1]
            do = tonic if mode == "major" else (tonic + 3) % 12
            out.append((float(r), tonic, mode, do))
    return sorted(out, reverse=True)


def nearest_id(midi):
    midi = min(max(int(round(midi)), 53), 84)
    return MIDI_TO_ID[min(MIDI_TO_ID, key=lambda m: abs(m - midi))]


def pyin_frames(yh, sr, hop=256):
    """(times, midi-float with nan for unvoiced) for the harmonic signal."""
    import librosa
    import numpy as np
    f0, voiced, prob = librosa.pyin(yh, fmin=130.8, fmax=2093, sr=sr, frame_length=2048, hop_length=hop)
    midi = librosa.hz_to_midi(f0)
    midi[~(prob >= 0.6)] = np.nan
    return librosa.times_like(f0, sr=sr, hop_length=hop), midi


def draft_notes(times, midi, onsets, shift, bpm):
    """Segment pyin frames into notes -> [(time, dur_s, midi_int)] with the octave normalised."""
    import numpy as np
    m = np.round(midi + shift)
    for i in range(1, len(m) - 1):
        if m[i] != m[i - 1] and m[i - 1] == m[i + 1]:
            m[i] = m[i - 1]
    hop = float(times[1] - times[0])
    onset_frames = set(int(round(t / hop)) for t in onsets)
    runs, i = [], 0
    while i < len(m):
        if np.isnan(m[i]):
            i += 1
            continue
        j = i + 1
        while j < len(m) and m[j] == m[i] and j not in onset_frames:
            j += 1
        if (j - i) * hop >= 0.07:
            runs.append((float(times[i]), (j - i) * hop, int(m[i])))
        i = j
    if not runs:
        return []
    med = float(np.median([r[2] for r in runs]))
    octs = round((66 - med) / 12)
    return [(t, d, mid + 12 * octs) for t, d, mid in runs]


def lcs_len(a, b):
    prev = [0] * (len(b) + 1)
    for x in a:
        cur = [0]
        for j, y in enumerate(b, 1):
            cur.append(prev[j - 1] + 1 if x == y else max(prev[j], cur[-1]))
        prev = cur
    return prev[-1]


def app_melodies():
    """{songTitle: [key ids]} parsed from LevelFeederModel.swift."""
    src = (ROOT / "Melodissimo" / "Models" / "Level" / "LevelFeederModel.swift").read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r"answer:\s*\[([^\]]*)\].*?songTitle:\s*\"([^\"]+)\"", src, re.S):
        out[m.group(2)] = [int(x) for x in m.group(1).split(",") if x.strip()]
    return out


def cmd_analyze(args):
    import librosa
    import numpy as np
    manifest = select(load_manifest(), args.only)
    (BS / "reports").mkdir(exist_ok=True)
    melodies = app_melodies()
    rows_path = BS / "reports" / "rows.json"
    rows = json.loads(rows_path.read_text()) if rows_path.exists() else {}
    for song in manifest:
        n, slug = song["n"], song["slug"]
        master = WORK / "songs" / f"{n:02d}_{slug}.wav"
        print(f"[{n:02d}] {song['title']} ...", flush=True)
        y, sr = librosa.load(str(master), sr=22050, mono=True)
        yh, _ = librosa.effects.hpss(y)
        chroma = librosa.feature.chroma_cqt(y=yh, sr=sr, hop_length=512).mean(axis=1)
        keys = key_scores(chroma)
        top = keys[0]
        shift = wrap_shift(top[3])
        tempo, beats = librosa.beat.beat_track(y=y, sr=sr, hop_length=256, units="time")
        tempo = float(np.atleast_1d(tempo)[0])
        idx = np.arange(len(beats))
        fit = np.polyfit(idx, beats, 1)
        resid = beats - np.polyval(fit, idx)
        worst = int(np.argmax(np.abs(resid)))
        stab = f"max deviation {abs(resid[worst]) * 1000:.0f} ms at {beats[worst]:.1f} s (of {len(y) / sr:.0f} s)"
        times, midi = pyin_frames(yh, sr)
        onsets = librosa.onset.onset_detect(y=yh, sr=sr, hop_length=256, units="time")
        notes = draft_notes(times, midi, onsets, shift, tempo)
        beat_s = 60.0 / tempo
        draft = [(t, d, nearest_id(mid), max(0.5, round(d / beat_s * 2) / 2)) for t, d, mid in notes]
        pcs = [midi_of(k) % 12 for _, _, k, _ in draft]
        title = song.get("oldTitle") or song["title"]
        sim = None
        if title in melodies and pcs:
            app_pcs = [midi_of(k) % 12 for k in melodies[title]]
            sim = lcs_len(pcs, app_pcs) / len(app_pcs)
        rng = (LABEL_BY_ID[min((k for _, _, k, _ in draft), key=midi_of)], LABEL_BY_ID[max((k for _, _, k, _ in draft), key=midi_of)]) if draft else ("-", "-")
        lines = [f"# {song['title']} — analysis (B2)", "",
                 f"- master: `work/songs/{n:02d}_{slug}.wav`, {len(y) / sr:.1f} s",
                 "", "## Key (Krumhansl–Schmuckler)", "", "| rank | key | score | do |", "|---|---|---|---|"]
        for r, (sc, tonic, mode, do) in enumerate(keys[:3], 1):
            lines.append(f"| {r} | {PC_NAMES[tonic]} {mode} | {sc:.3f} | {PC_NAMES[do]} |")
        lines += ["", f"**Suggested shift:** {shift:+d} semitones (do {PC_NAMES[top[3]]} → C)",
                  "", "## Tempo", "",
                  f"- beat_track: **{tempo:.1f} bpm** (half {tempo / 2:.1f}, double {tempo * 2:.1f})",
                  f"- stability: {stab}", f"- beats tracked: {len(beats)}",
                  "", "## Draft melody (pyin, shifted so do = C)", "",
                  f"- notes: {len(draft)}, range {rng[0]} … {rng[1]}",
                  f"- similarity to the app melody: {'n/a (new song)' if sim is None else f'{sim:.2f}'}",
                  "", "```"]
        for i in range(0, len(draft), 8):
            lines.append(" ".join(f"{LABEL_BY_ID[k]}({b:g})" for _, _, k, b in draft[i:i + 8]))
        lines += ["```", "", "### First 30 detected notes", "", "| time (s) | label | beats |", "|---|---|---|"]
        for t, _, k, b in draft[:30]:
            lines.append(f"| {t:.2f} | {LABEL_BY_ID[k]} | {b:g} |")
        (BS / "reports" / f"{slug}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        rows[slug] = {"n": n, "title": song["title"], "key": f"{PC_NAMES[top[1]]} {top[2]}", "score": round(top[0], 3),
                      "second": round(keys[1][0], 3), "shift": shift, "bpm": round(tempo, 1), "stability": stab,
                      "notes": len(draft), "sim": None if sim is None else round(sim, 2)}
        rows_path.write_text(json.dumps(rows, indent=1, ensure_ascii=False))
        write_summary(rows)
    print("done")


def write_summary(rows):
    lines = ["# Backsound analysis summary", "",
             "| # | Song | Key guess (score / 2nd) | Shift | bpm | Tempo stability | Draft notes | Similarity |",
             "|---|------|------|------|-----|-----|-----|-----|"]
    for r in sorted(rows.values(), key=lambda r: r["n"]):
        sim = "new" if r["sim"] is None else f"{r['sim']:.2f}" + ("  ⚠️" if r["sim"] < 0.3 else "")
        lines.append(f"| {r['n']} | {r['title']} | {r['key']} ({r['score']:.2f} / {r['second']:.2f}) | {r['shift']:+d} | "
                     f"{r['bpm']} | {r['stability']} | {r['notes']} | {sim} |")
    (BS / "reports" / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def cmd_stub(args):
    sys.exit(f"'{args.cmd}' is not implemented yet (see BACKSOUND_PLAN.md)")


def main(argv=None):
    p = argparse.ArgumentParser(description="Melodissimo backsound pipeline")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selftest").set_defaults(func=cmd_selftest)
    sub.add_parser("fetch").set_defaults(func=cmd_fetch)
    cp = sub.add_parser("cut")
    cp.add_argument("--from-json", action="store_true")
    cp.set_defaults(func=cmd_cut)
    ap = sub.add_parser("analyze")
    ap.add_argument("--only")
    ap.set_defaults(func=cmd_analyze)
    for name in ("json2ref", "check-ref", "build", "emit-swift"):
        sp = sub.add_parser(name)
        sp.add_argument("--only")
        sp.set_defaults(func=cmd_stub)
    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
