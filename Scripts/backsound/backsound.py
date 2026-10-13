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
                header[k.strip()] = re.split(r"\s#", v)[0].strip() if k.strip() != "sources" else v.strip()
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
        line = re.split(r"(?:^|\s)#", raw)[0].strip()
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
        row = {"n": n, "title": song["title"], "key": f"{PC_NAMES[top[1]]} {top[2]}", "score": round(top[0], 3),
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


def cmd_json2ref(args):
    """Convert a draft chart JSON to DSL text (a starting point for a reference file)."""
    data = json.loads(Path(args.chart).read_text(encoding="utf-8"))
    notes = [(n["k"], n["b"], n["d"]) for n in data["notes"]]
    bpb = args.beats_per_bar
    pickup = args.pickup
    shift = (bpb - pickup) if pickup else 0
    notes = [(k, b + shift, d) for k, b, d in notes]
    print(f"title: {data.get('title', '')}\nbeats_per_bar: {bpb}\npickup: {pickup}\nbpm_hint: {data.get('bpm', 100)}\n---")
    print(chart_to_dsl(notes, bpb, pickup))


def ref_draft_similarity(slug, notes):
    """Pitch-class LCS (share of the reference notes found in order in the B2 audio draft)."""
    rp = BS / "reports" / f"{slug}.md"
    if not rp.exists():
        return None
    txt = rp.read_text(encoding="utf-8")
    m = re.search(r"## Draft melody.*?```\n(.*?)```", txt, re.S)
    if not m:
        return None
    labels = re.findall(r"(\S+?)\([0-9.]+\)", m.group(1))
    draft = [midi_of(ID_BY_LABEL[l]) % 12 for l in labels if l in ID_BY_LABEL]
    ref = [midi_of(k) % 12 for k, _, _ in notes]
    if not draft or not ref:
        return None
    return lcs_len(ref, draft) / len(ref)


def cmd_check_ref(args):
    manifest = select(load_manifest(), args.only)
    rows = json.loads((BS / "reports" / "rows.json").read_text()) if (BS / "reports" / "rows.json").exists() else {}
    bad = 0
    for song in manifest:
        slug = song["slug"]
        path = BS / "reference" / f"{slug}.txt"
        try:
            header, notes, anchors, bars = parse_ref(path)
        except (RefError, FileNotFoundError) as e:
            print(f"[{slug}] ERROR {e}")
            bad += 1
            continue
        errs = []
        if len(notes) < 16:
            errs.append(f"only {len(notes)} notes")
        if any(not (1 <= k <= 32) for k, _, _ in notes):
            errs.append("key id out of range")
        bpb = int(header.get("beats_per_bar", 4))
        pickup = float(header.get("pickup", 0))
        first = (bpb - pickup) if pickup > 0 else 0
        if notes and notes[0][1] < first - 1e-6:
            errs.append("first note before the pickup bar")
        end = max(b + d for _, b, d in notes)
        bpm = float(header.get("bpm_hint", 0))
        if not (50 <= bpm <= 140):
            errs.append(f"bpm_hint {bpm} outside 50-140")
        sim = ref_draft_similarity(slug, notes)
        simtxt = "" if sim is None else f", draft LCS {sim:.2f}"
        print(f"[{slug}] {len(notes)} notes, {len(bars)} bars, {end:.1f} beats, bpb {bpb}, pickup {pickup:g}, bpm_hint {bpm:g}{simtxt}"
              + (" ERRORS: " + "; ".join(errs) if errs else " OK"))
        if args.bars:
            print("   bars: " + ", ".join(f"{n}@{s:g}" for n, s, _ in bars))
        bad += bool(errs)
    if bad:
        sys.exit(1)


# --------------------------------------------------------------------------
# B5: build (align reference to recording, game cut, chart, preview)
# --------------------------------------------------------------------------

SAMPLES = ROOT / "Melodissimo" / "Data" / "Sound"
RATIOS = (0.5, 2 / 3, 1.0, 1.5, 2.0)


def pitch_shift_file(src, dst, shift):
    """Pitch-shift with the rubberband CLI (ffmpeg here has no rubberband filter), keep the length."""
    import numpy as np
    import soundfile as sf
    if shift == 0:
        import shutil
        shutil.copyfile(src, dst)
        return "copy"
    tmp = Path(str(dst) + ".tmp.wav")
    run(["rubberband", "-3", "-p", f"{shift}", src, tmp])
    a, sr = sf.read(str(src), always_2d=True)
    b, sr2 = sf.read(str(tmp), always_2d=True)
    assert sr == sr2
    if len(b) > len(a):
        b = b[: len(a)]
    elif len(b) < len(a):
        b = np.vstack([b, np.zeros((len(a) - len(b), b.shape[1]))])
    sf.write(str(dst), b, sr, subtype="PCM_16")
    tmp.unlink()
    return "rubberband -3"


class Features:
    """Frame features of the shifted recording."""

    def __init__(self, wav, bpm_hint):
        import librosa
        import numpy as np
        from scipy.ndimage import maximum_filter1d
        self.sr = 22050
        y, sr = librosa.load(str(wav), sr=self.sr, mono=True)
        self.dur = len(y) / sr
        yh, _ = librosa.effects.hpss(y)
        # chroma of the melody range only (MIDI 53..84 = the app's keyboard), so bass and chords count less
        cq = np.abs(librosa.cqt(yh, sr=sr, hop_length=512, fmin=librosa.midi_to_hz(48), n_bins=48, bins_per_octave=12))
        ch = np.zeros((12, cq.shape[1]))
        for i in range(5, 37):
            ch[(48 + i) % 12] += cq[i]
        self.chroma = ch / (ch.max(axis=0, keepdims=True) + 1e-9)
        self.ch_hop = 512 / sr
        self.ch_cum = np.concatenate([np.zeros((12, 1)), np.cumsum(self.chroma, axis=1)], axis=1)
        self.py_hop = 256 / sr
        env = librosa.onset.onset_strength(y=yh, sr=sr, hop_length=256)
        env = env / (np.percentile(env, 99) + 1e-9)
        self.onset_env = np.clip(env, 0, 1.5)
        w = int(round(0.04 / self.py_hop)) * 2 + 1
        self.onset_max = maximum_filter1d(self.onset_env, size=w)
        # relative peak picking, so soft/legato recordings still get onsets
        pk = librosa.util.peak_pick(self.onset_env, pre_max=3, post_max=3, pre_avg=12, post_avg=12, delta=0.06, wait=5)
        self.onsets = np.asarray(pk, dtype=float) * 256 / sr
        tempo, beats = librosa.beat.beat_track(y=y, sr=sr, hop_length=256, start_bpm=float(bpm_hint), tightness=100, units="time")
        beats = np.asarray(beats, dtype=float)
        iv = float(np.median(np.diff(beats)))
        pre = [beats[0] - iv * k for k in range(int(beats[0] / iv) + 1, 0, -1)]
        post = [beats[-1] + iv * k for k in range(1, int((self.dur - beats[-1]) / iv) + 1)]
        self.beats = np.array(pre + list(beats) + post)
        self.beat_iv = iv
        self.tempo = float(np.atleast_1d(tempo)[0])

    def note_scores(self, pcs, t0, t1):
        """Per-note 0.8·melody-chroma + 0.2·onset scores for notes (pc, start s, end s) arrays (pyin was dropped: it finds almost nothing in these mixes)."""
        import numpy as np
        a = np.clip((t0 + 0.1 * (t1 - t0)) / self.ch_hop, 0, self.chroma.shape[1] - 1).astype(int)
        b = np.clip(np.maximum((t1 - 0.1 * (t1 - t0)) / self.ch_hop, a + 1), 1, self.chroma.shape[1]).astype(int)
        cm = (self.ch_cum[pcs, b] - self.ch_cum[pcs, a]) / np.maximum(b - a, 1)
        pm = cm
        oi = np.clip(np.round(t0 / self.py_hop).astype(int), 0, len(self.onset_max) - 1)
        oh = np.minimum(self.onset_max[oi], 1.0)
        return 0.8 * cm + 0.2 * oh, cm, pm, oh


def beat_time_fn(tb, j0, r, delta=0.0):
    """Reference beat -> seconds by mapping onto tracked beat index j0 + b*r."""
    import numpy as np
    idx = np.arange(len(tb), dtype=float)
    slope_lo = tb[1] - tb[0]
    slope_hi = tb[-1] - tb[-2]

    def T(b):
        x = j0 + np.asarray(b, dtype=float) * r
        y = np.interp(x, idx, tb)
        y = np.where(x < 0, tb[0] + x * slope_lo, y)
        y = np.where(x > idx[-1], tb[-1] + (x - idx[-1]) * slope_hi, y)
        return y + delta
    return T


def search_alignment(feat, notes, pcs):
    """Best (ratio, j0) per plan B5 step 5. Returns list of dicts sorted by score."""
    import numpy as np
    tb = feat.beats
    ks = np.array([n[0] for n in notes])
    b0 = np.array([n[1] for n in notes], dtype=float)
    d = np.array([n[2] for n in notes], dtype=float)
    cands = []
    for r in RATIOS:
        hi = len(tb) - 1 - (b0 + d).max() * r - 2
        hi = min(hi, 0.7 * len(tb))
        for j0 in np.arange(0.0, max(hi, 0.0) + 1e-9, 0.25):
            T = beat_time_fn(tb, j0, r)
            t0, t1 = T(b0), T(b0 + d)
            if t1.max() > feat.dur:
                continue
            sc, *_ = feat.note_scores(pcs, t0, t1)
            cands.append({"r": r, "j0": float(j0), "score": float(sc.mean())})
    cands.sort(key=lambda c: -c["score"])
    return cands


def dtw_align(feat, notes, bpm_hint, hyps=None):
    """Subsequence DTW of a synthetic melody chroma against the recording's chroma, for several tempo
    hypotheses. Returns the best hypothesis: per-note start times (s) and a normalised path cost."""
    import librosa
    import numpy as np
    C = feat.chroma
    hop = feat.ch_hop
    out = []
    b_end = max(b + d for _, b, d in notes)
    if hyps is None:
        hyps = sorted({round(bpm_hint * r, 1) for r in RATIOS} | {round(feat.tempo * f, 1) for f in (0.5, 1.0, 2.0)})
    for bpm in hyps:
        if not 35 <= bpm <= 260:
            continue
        spb = 60.0 / bpm / hop            # audio frames per reference beat
        m = int(math.ceil(b_end * spb)) + 1
        if m > C.shape[1]:
            continue
        ref = np.full((12, m), 0.02)
        for k, b, d in notes:
            a0, a1 = int(round(b * spb)), max(int(round((b + d) * spb)), int(round(b * spb)) + 1)
            pc = midi_of(k) % 12
            ref[pc, a0:a1] = 1.0
            ref[(pc + 7) % 12, a0:a1] = np.maximum(ref[(pc + 7) % 12, a0:a1], 0.25)
        try:
            D, wp, steps = librosa.sequence.dtw(X=ref, Y=C, metric="cosine", subseq=True, return_steps=True,
                                                step_sizes_sigma=np.array([[1, 1], [1, 2], [2, 1]]),
                                                weights_mul=np.array([1.0, 1.3, 1.3]))
        except Exception as e:  # pragma: no cover
            print("   dtw failed", bpm, e)
            continue
        last = D[-1] / m
        lo = float(last.min())
        win = int(2.0 / hop)
        cands = [j for j in range(len(last)) if last[j] <= lo * 1.04 and last[j] == last[max(0, j - win): j + win + 1].min()]
        j_end = min(cands) if cands else int(np.argmin(last))
        wp = librosa.sequence.dtw_backtracking(steps, step_sizes_sigma=np.array([[1, 1], [1, 2], [2, 1]]),
                                               subseq=True, start=j_end)[::-1]
        cost = float(last[j_end])
        rf, af = wp[:, 0], wp[:, 1]
        starts = []
        for k, b, d in notes:
            f0 = int(round(b * spb))
            idx = np.where(rf >= f0)[0]
            starts.append(float(af[idx[0]]) * hop if len(idx) else float(af[-1]) * hop)
        span = float(af[-1] - af[0]) * hop
        slope = max(span / (m * hop), 1e-3)
        out.append({"bpm": bpm, "cost": cost, "starts": np.array(starts), "dur": span, "slope": slope,
                    "begin": float(af[0]) * hop, "score": cost * (1 + 3 * abs(math.log(slope)))})
    out.sort(key=lambda o: o["score"])
    return out


def lufs_normalize(src, dst):
    import json as _json
    flt = "loudnorm=I=-16:TP=-1.5:LRA=11"
    p = run(["ffmpeg", "-hide_banner", "-i", src, "-af", flt + ":print_format=json", "-f", "null", "-"])
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", p.stderr, re.S)
    st = _json.loads(m.group(0))
    second = (f"{flt}:measured_I={st['input_i']}:measured_TP={st['input_tp']}:measured_LRA={st['input_lra']}"
              f":measured_thresh={st['input_thresh']}:offset={st['target_offset']}:linear=true")
    run(["ffmpeg", "-y", "-hide_banner", "-i", src, "-af", second, "-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le", dst])


def decode_to_wav(src, dst):
    run(["afconvert", "-f", "WAVE", "-d", "LEI16", src, dst])


def xcorr_lag(a, b, sr, max_lag=0.2):
    """Lag (s) by which `a` is later than `b` (both mono arrays)."""
    import numpy as np
    n = min(len(a), len(b), int(15 * sr))
    a, b = a[:n] - a[:n].mean(), b[:n] - b[:n].mean()
    from scipy.signal import fftconvolve
    c = fftconvolve(a, b[::-1], mode="full")
    mid = n - 1
    m = int(max_lag * sr)
    seg = c[mid - m: mid + m + 1]
    return (int(np.argmax(seg)) - m) / sr


def py_is_valid(chart):
    """Python port of SongChart.isValid (v2 rules)."""
    if not chart["notes"]:
        return False
    if chart["bpm"] <= 0:
        return False
    if chart.get("offset") is not None and chart["offset"] < 0:
        return False
    if chart.get("beatsPerBar") is not None and not 1 <= chart["beatsPerBar"] <= 12:
        return False
    bt = chart.get("beatTimes")
    if bt is not None:
        if len(bt) < 2 or any(y <= x for x, y in zip(bt, bt[1:])):
            return False
        if chart.get("offset") is None or abs(bt[0] - chart["offset"]) >= 0.001:
            return False
    for n in chart["notes"]:
        if not 1 <= n["k"] <= 32 or n["b"] < 0 or n["d"] <= 0:
            return False
    return True


def cmd_build(args):
    import numpy as np
    import soundfile as sf
    manifest = select(load_manifest(), args.only)
    for d in ("shifted", "out", "preview", "samples", "feat"):
        (WORK / d).mkdir(parents=True, exist_ok=True)
    (BS / "sheets").mkdir(exist_ok=True)
    rows_dir = WORK / "build_rows"
    rows_dir.mkdir(exist_ok=True)
    b2rows = json.loads((BS / "reports" / "rows.json").read_text())
    ov_path = BS / "overrides.json"
    overrides = json.loads(ov_path.read_text()) if ov_path.exists() else {}
    cuts = {c["slug"]: c for c in json.loads((BS / "cuts.json").read_text())}
    for song in manifest:
        n, slug = song["n"], song["slug"]
        print(f"[{n:02d}] {song['title']}", flush=True)
        header, notes, anchors, bars = parse_ref(BS / "reference" / f"{slug}.txt")
        bpb = int(header.get("beats_per_bar", 4))
        bpm_hint = float(header["bpm_hint"])
        pickup = float(header.get("pickup", 0))
        ending = header.get("ending", "auto")
        master = WORK / "songs" / f"{n:02d}_{slug}.wav"
        pcs = np.array([midi_of(k) % 12 for k, _, _ in notes])
        # 2. key check: audio chroma vs the reference pitch-class histogram (duration weighted)
        import librosa
        y0, sr0 = librosa.load(str(master), sr=22050, mono=True)
        yh0, _ = librosa.effects.hpss(y0)
        chroma_mean = librosa.feature.chroma_cqt(y=yh0, sr=sr0, hop_length=512).mean(axis=1)
        hist = np.zeros(12)
        for k, _, dd in notes:
            hist[midi_of(k) % 12] += dd
        corr = []
        for shift in range(-6, 6):
            # audio pitch class p becomes (p + shift) % 12 after shifting
            rolled = np.roll(chroma_mean, shift)
            corr.append((float(np.corrcoef(rolled, hist)[0, 1]), shift))
        corr.sort(reverse=True)
        shift = corr[0][1]
        b2shift = b2rows.get(slug, {}).get("shift")
        ov = overrides.get(slug, {})
        if "do_hint" in header:
            do_pc = PC_NAMES.index(header["do_hint"])
            hint_shift = wrap_shift(do_pc)
            corr = [((c + 0.08, sh) if sh == hint_shift else (c, sh)) for c, sh in corr]
            corr.sort(reverse=True)
            shift = corr[0][1]
        key_note = f"key check: shift {shift:+d} (r={corr[0][0]:.2f}, next {corr[1][1]:+d} r={corr[1][0]:.2f}); B2 guess {b2shift}"
        if args.shift is None and "shift" in ov:
            args_shift = ov["shift"]
        else:
            args_shift = args.shift
        if args_shift is not None:
            shift = args_shift
            key_note += f"; forced {shift:+d}"
        print("   " + key_note, flush=True)
        # 3. pitch shift
        shifted = WORK / "shifted" / f"{slug}.wav"
        how = pitch_shift_file(master, shifted, shift)
        # 4. features
        feat = Features(shifted, bpm_hint)
        # 5. alignment. (a) pulse ratio from the tracked tempo vs the reference's bpm_hint,
        #    (b) DTW at that tempo gives rough note times (global structure, +-0.3 s),
        #    (c) the (smoothed) tracked beat grid supplies precision: pick the grid offset j0 that best fits the DTW times.
        b0 = np.array([x[1] for x in notes], dtype=float)
        dd = np.array([x[2] for x in notes], dtype=float)
        r = min(RATIOS, key=lambda q: abs(math.log(q * feat.tempo / bpm_hint)))
        dtws = dtw_align(feat, notes, bpm_hint, hyps=[round(feat.tempo * r, 1)])
        dbest = dtws[0]
        cands = []
        from scipy.ndimage import gaussian_filter1d
        tbs = gaussian_filter1d(feat.beats, 1.5, mode="nearest")      # tracker jitter out, tempo drift kept
        hi = min(len(tbs) - 1 - (b0 + dd).max() * r - 2, 0.9 * len(tbs))
        for j0 in np.arange(0.0, max(hi, 0.0) + 1e-9, 0.25):
            T_ = beat_time_fn(tbs, j0, r)
            t0_, t1_ = T_(b0), T_(b0 + dd)
            if t1_.max() > feat.dur:
                continue
            sc_, *_ = feat.note_scores(pcs, t0_, t1_)
            err_ = np.abs(t0_ - dbest["starts"])
            head = np.argsort(b0)[:12]          # the start of a subsequence DTW is the reliable part
            cands.append({"r": r, "j0": float(j0), "score": float(sc_.mean()), "dtw_err": float(np.median(err_[head])),
                          "dtw_ok": float((err_[head] < 0.25).mean()), "dtw_all": float(np.median(err_))})
        first_note = args.first_note if args.first_note is not None else ov.get("first_note")
        if first_note is not None:
            for c in cands:
                c["dtw_err"] = abs(float(beat_time_fn(tbs, c["j0"], r)(b0.min())) - first_note)
        best = max(cands, key=lambda c: c["score"])
        if first_note is None:
            # Melody chroma decides. DTW (global structure) is trusted only where it agrees with some candidate;
            # among near-equal candidates take the earliest, so the first pass wins over a repeat (plan B5 step 5).
            cons = [c for c in cands if c["dtw_all"] <= 0.5]
            if cons and max(c["score"] for c in cons) >= 0.65:
                top = max(c["score"] for c in cons)
                good = [c for c in cons if c["score"] >= top - 0.02]
                pick_how = f"chroma score among {len(cons)} candidates that agree with DTW; earliest of {len(good)} near-equal"
            else:
                top = best["score"]
                good = [c for c in cands if c["score"] >= 0.95 * top]
                pick_how = f"chroma score alone (DTW did not settle it); earliest of {len(good)} within 5% of the best"
            pick = min(good, key=lambda c: c["j0"])
        else:
            cands.sort(key=lambda c: c["dtw_err"])
            pick = cands[0]
            pick_how = "forced first note"
        j0 = pick["j0"]
        T = beat_time_fn(tbs, j0, r)
        # global refinement (+-100 ms) of the grid against onsets/chroma
        bestd, bests = 0.0, -1
        for delta in np.arange(-0.1, 0.1001, 0.01):
            sc_, *_ = feat.note_scores(pcs, T(b0) + delta, T(b0 + dd) + delta)
            if sc_.mean() > bests + 1e-9:
                bests, bestd = float(sc_.mean()), float(delta)
        T = beat_time_fn(tbs, j0, r, bestd)
        info = f"smoothed tracked grid (tracker {feat.tempo:.1f} bpm), refine {bestd * 1000:+.0f} ms"
        # 7. anchors
        if anchors:
            starts = {num: s_ for num, s_, _ in bars}
            pts = [(starts[num], t) for num, t in anchors if num in starts]
            base = T
            corrs = np.array([t - float(base(b_)) for b_, t in pts])
            xs = np.array([b_ for b_, _ in pts])
            T = lambda b_, base=base, xs=xs, corrs=corrs: base(b_) + np.interp(np.asarray(b_, dtype=float), xs, corrs)
        # 8. QA
        t0, t1 = T(b0), T(b0 + dd)
        sc, cm, pm, oh = feat.note_scores(pcs, t0, t1)
        ons = feat.onsets
        err = np.array([np.min(np.abs(ons - t)) if len(ons) else 9 for t in t0])
        close = err <= 0.15
        err_close = err[close] if close.any() else err
        med, p90 = float(np.median(err_close)), float(np.percentile(err_close, 90))
        pitch_agree = float((dd * (pm >= 0.6)).sum() / dd.sum())
        # 9. tempo map decision
        last_end_beat = float((b0 + dd).max())
        nb = int(math.ceil(last_end_beat)) + 2
        grid = np.arange(0, nb + 1, dtype=float)
        tg = T(grid)
        slope, icpt = np.polyfit(grid, tg, 1)
        resid = tg - (slope * grid + icpt)
        steady = float(np.abs(resid).max()) <= 0.02
        # smooth jitter, then re-test
        if not steady:
            from scipy.ndimage import gaussian_filter1d
            sm = gaussian_filter1d(tg, 1.0, mode="nearest")
            resid2 = sm - (slope * grid + icpt)
            if float(np.abs(resid2).max()) <= 0.02:
                steady = True
            else:
                tg = sm
        # 10. game cut
        first_t = float(T(b0.min()))
        last_end = float(T(last_end_beat))
        beat_len = float(np.median(np.diff(tg[: min(len(tg), 9)]))) if not steady else slope
        bar = bpb * beat_len
        want_start = max(0.0, first_t - min(2 * bar, 6.0))
        # start on a bar line (beat 0 of a bar) so the intro begins musically
        bar_first = math.floor(b0.min() / bpb)
        cand_starts = [float(T(float(k * bpb))) for k in range(bar_first - 12, bar_first + 1)]
        cand_starts = [t for t in cand_starts if 0.0 <= t <= want_start + 1e-6]
        start = max(cand_starts) if cand_starts else 0.0
        file_end = feat.dur
        left = file_end - last_end
        natural = ending == "natural" or (ending == "auto" and left <= 8.0)
        if natural:
            end, fade_out = file_end, 0.3
        else:
            end = min(file_end, last_end + max(1.5, 0.75 * bar))
            fade_out = min(2.0, end - last_end + 0.5)
        # 11. render
        data, sr = sf.read(str(shifted), always_2d=True)
        a, bidx = int(round(start * sr)), int(round(end * sr))
        seg = data[a:bidx].copy()
        pad = max(0.0, -(float(T(0.0)) - start))
        fi, fo = int(0.2 * sr), int(fade_out * sr)
        seg[:fi] *= np.linspace(0, 1, fi)[:, None]
        seg[-fo:] *= np.linspace(1, 0, fo)[:, None]
        if pad > 0:
            seg = np.vstack([np.zeros((int(round(pad * sr)), seg.shape[1])), seg])
        pre = WORK / "out" / f"pre_{slug}.wav"
        sf.write(str(pre), seg, sr, subtype="PCM_16")
        wav = WORK / "out" / f"bgm_{slug}.wav"
        lufs_normalize(pre, wav)
        m4a = WORK / "out" / f"bgm_{slug}.m4a"
        if m4a.exists():
            m4a.unlink()
        run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", wav, m4a])
        dec = WORK / "out" / f"dec_{slug}.wav"
        decode_to_wav(m4a, dec)
        d_arr, _ = sf.read(str(dec), always_2d=True)
        p_arr, _ = sf.read(str(pre), always_2d=True)
        lag = xcorr_lag(d_arr.mean(axis=1), p_arr.mean(axis=1), sr)
        offset = float(T(0.0)) - start + pad + lag
        # 12. chart
        iv8 = np.diff(tg[:9]) if not steady else None
        bpm = 60.0 / slope if steady else 60.0 / float(np.median(iv8))
        chart = {"id": slug, "title": song["title"], "bpm": round(bpm, 2), "beatsPerBar": bpb,
                 "offset": round(offset, 3)}
        if not steady:
            bt = (tg - start + pad + lag)
            bt[0] = offset
            bt = np.maximum.accumulate(bt)
            chart["beatTimes"] = [round(float(x), 4) for x in bt]
            chart["beatTimes"][0] = chart["offset"]
        chart["notes"] = [{"k": int(k), "b": round(float(b), 4), "d": round(float(dd_), 4)} for k, b, dd_ in notes]
        ok = py_is_valid(chart)
        (WORK / "out" / f"chart_{slug}.json").write_text(json.dumps(chart, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
        size = m4a.stat().st_size
        # 13. preview
        make_preview(slug, n, chart, dec)
        # 14. sheet
        sheet = [f"# {song['title']}", f"do = C · {bpb}/4 · ♩ = {chart['bpm']:.0f}", "", chart_to_dsl([(k, b, d_) for k, b, d_ in notes], bpb, int(pickup))]
        (BS / "sheets" / f"{slug}.txt").write_text("\n".join(sheet) + "\n", encoding="utf-8")
        # 15. report
        worst = np.argsort(pm)[:10]
        bar_of = lambda beat: next((num for num, s, ln in reversed(bars) if s <= beat + 1e-6), 0)
        lines = ["", "## Build (B5)", "",
                 f"- {key_note}", f"- pitch shift: {shift:+d} semitones ({how})",
                 f"- alignment: pulse ratio {r:g} (tracker {feat.tempo:.1f} bpm vs hint {bpm_hint:g}); DTW at {dbest['bpm']} bpm: path slope {dbest['slope']:.2f}, cost {dbest['cost']:.3f}, melody starts at {dbest['begin']:.1f} s",
                 f"- grid pick ({pick_how}): j0 {j0:g}, first note at {float(T(b0.min())):.2f} s, median |grid - DTW| over the first 12 notes {pick['dtw_err'] * 1000:.0f} ms ({pick['dtw_ok'] * 100:.0f}% within 250 ms; over all notes {pick['dtw_all'] * 1000:.0f} ms)",
                 f"- top grid candidates (dtw err ms / chroma score): " + "; ".join(f"j0={c['j0']:g} {c['dtw_err'] * 1000:.0f}/{c['score']:.3f}" for c in cands[:4]),
                 f"- best by chroma score (first note s / dtw err ms / score): " + "; ".join(f"{float(beat_time_fn(tbs, c['j0'], c['r'])(b0.min())):.1f} s / {c['dtw_err'] * 1000:.0f} / {c['score']:.3f}" for c in sorted(cands, key=lambda c: -c['score'])[:6]),
                 f"- time map: {info}",
                 f"- timing: median onset error {med * 1000:.0f} ms, p90 {p90 * 1000:.0f} ms ({int(close.sum())}/{len(close)} notes within 150 ms of an onset)",
                 f"- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): {pitch_agree * 100:.0f}%",
                 f"- tempo: {'steady' if steady else 'tempo map (beatTimes)'}, bpm {chart['bpm']:.1f}; max line residual {np.abs(resid).max() * 1000:.0f} ms",
                 f"- game cut: {start:.2f}–{end:.2f} s of the shifted file ({'natural ending' if natural else f'fade-out {fade_out:.1f} s'}), {end - start:.0f} s long, pad {pad:.2f} s",
                 f"- offset {chart['offset']:.3f} s (m4a lag {lag * 1000:+.1f} ms), m4a {size / 1e6:.2f} MB, chart valid: {ok}",
                 "", "Weakest 10 notes by chroma (bar.beat, expected):", ""]
        for i in worst:
            bb = float(b0[i])
            bn = bar_of(bb)
            bstart = next(s for num, s, ln in bars if num == bn)
            lines.append(f"- bar {bn}.{bb - bstart + 1:.2f} `{LABEL_BY_ID[notes[i][0]]}` chroma {pm[i]:.2f}, onset error {err[i] * 1000:.0f} ms")
        rp = BS / "reports" / f"{slug}.md"
        txt = rp.read_text(encoding="utf-8") if rp.exists() else f"# {song['title']}\n"
        txt = txt.split("\n## Build (B5)")[0].rstrip("\n") + "\n" + "\n".join(lines) + "\n"
        rp.write_text(txt, encoding="utf-8")
        # The onset test is easy to pass (a busy mix has an onset nearly everywhere), so the DTW consistency decides.
        verdict = "LIKELY" if (pitch_agree >= 0.6 and pick["dtw_all"] <= 0.35 and ok and size < 3e6) else "UNSURE"
        row = {"n": n, "title": song["title"], "shift": shift, "score": round(pick["score"], 3), "ratio": round(r, 3), "dtwok": round(pick["dtw_ok"] * 100),
                      "med": round(med * 1000), "p90": round(p90 * 1000), "pitch": round(pitch_agree * 100),
                      "tempo": "steady" if steady else "map", "bpm": chart["bpm"], "len": round(end - start), "mb": round(size / 1e6, 2),
                      "lag": round(lag * 1000, 1), "verdict": verdict}
        (rows_dir / f"{slug}.json").write_text(json.dumps(row, indent=1, ensure_ascii=False))
        print(f"   {verdict}: score {pick['score']:.3f}, ratio {r:g}, onset med {med * 1000:.0f}/p90 {p90 * 1000:.0f} ms, pitch {pitch_agree * 100:.0f}%, "
              f"{'steady' if steady else 'map'} {chart['bpm']:.1f} bpm, cut {end - start:.0f}s, {size / 1e6:.2f} MB, lag {lag * 1000:+.1f} ms", flush=True)
    write_build_summary()


def write_build_summary():
    rows = {p.stem: json.loads(p.read_text()) for p in (WORK / "build_rows").glob("*.json")}
    p = BS / "reports" / "summary.md"
    base = p.read_text(encoding="utf-8").split("\n## Build summary")[0].rstrip("\n")
    lines = ["", "", "## Build summary (B5)", "",
             "| # | Song | Verdict | Shift | Align score | Pulse ratio | Onset med/p90 (ms) | Pitch % | Tempo | bpm | Cut (s) | m4a MB |",
             "|---|------|---------|-------|-------------|-------------|--------------------|---------|-------|-----|---------|--------|"]
    for r in sorted(rows.values(), key=lambda r: r["n"]):
        lines.append(f"| {r['n']} | {r['title']} | {r['verdict']} | {r['shift']:+d} | {r['score']:.2f} | {r['ratio']:g} | {r['med']}/{r['p90']} | {r['pitch']} | {r['tempo']} | {r['bpm']:.0f} | {r['len']} | {r['mb']:.2f} |")
    p.write_text(base + "\n".join(lines) + "\n", encoding="utf-8")


def sample_wav(sound):
    """Decode one of the app's pianika samples once; returns a mono float array at 44.1 kHz."""
    import soundfile as sf
    out = WORK / "samples" / f"{sound}.wav"
    if not out.exists():
        for d in ("whiteTiles", "blackTiles"):
            src = SAMPLES / d / f"{sound}.m4a"
            if src.exists():
                decode_to_wav(src, out)
                break
    data, sr = sf.read(str(out), always_2d=True)
    return data.mean(axis=1), sr


def make_preview(slug, n, chart, dec_wav):
    import numpy as np
    import soundfile as sf
    music, sr = sf.read(str(dec_wav), always_2d=True)
    mix = np.zeros_like(music)
    mix += 0.8 * music
    sound_by_id = {i: s for i, _, s, _ in NOTE_TABLE}
    c = {"bpm": chart["bpm"], "beatTimes": chart.get("beatTimes")}

    def sec(beat):
        bt = c["beatTimes"]
        if not bt or len(bt) < 2:
            return beat * 60 / c["bpm"]
        i = min(max(int(math.floor(beat)), 0), len(bt) - 2)
        return bt[i] + (beat - i) * (bt[i + 1] - bt[i]) - bt[0]

    for nt in chart["notes"]:
        s0 = chart["offset"] + sec(nt["b"])
        s1 = chart["offset"] + sec(nt["b"] + nt["d"])
        smp, ssr = sample_wav(sound_by_id[nt["k"]])
        length = int(max(s1 - s0, 0.25) * sr)
        piece = smp[:length].copy()
        f = min(int(0.03 * sr), len(piece))
        if f:
            piece[-f:] *= np.linspace(1, 0, f)
        a = int(round(s0 * sr))
        if a < 0 or a >= len(mix):
            continue
        b = min(a + len(piece), len(mix))
        mix[a:b] += 0.6 * piece[: b - a, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    wav = WORK / "preview" / f"{n:02d}_{slug}_preview.wav"
    sf.write(str(wav), mix, sr, subtype="PCM_16")
    m4a = WORK / "preview" / f"{n:02d}_{slug}_preview.m4a"
    if m4a.exists():
        m4a.unlink()
    run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", wav, m4a])
    wav.unlink()


def cmd_emit_swift(args):
    manifest = load_manifest()
    for s in manifest:
        chart = json.loads((WORK / "out" / f"chart_{s['slug']}.json").read_text())
        notes = sorted(chart["notes"], key=lambda x: (x["b"], x["k"]))
        q = ", ".join(f'"{LABEL_BY_ID[x["k"]]}"' for x in notes)
        a = ", ".join(str(x["k"]) for x in notes)
        print(f'        LevelModel(levelCategory: "song", levelNo: 1, question: [{q}], answer: [{a}], songTitle: "{s["title"]}", songNotImg: "{s["image"]}"),')



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
    jp = sub.add_parser("json2ref")
    jp.add_argument("chart")
    jp.add_argument("--beats-per-bar", type=int, default=4)
    jp.add_argument("--pickup", type=int, default=0)
    jp.set_defaults(func=cmd_json2ref)
    kp = sub.add_parser("check-ref")
    kp.add_argument("--only")
    kp.add_argument("--bars", action="store_true")
    kp.set_defaults(func=cmd_check_ref)
    bp = sub.add_parser("build")
    bp.add_argument("--only")
    bp.add_argument("--shift", type=int, default=None)
    bp.add_argument("--first-note", type=float, default=None, help="force the time (s, in the shifted file) of the first reference note")
    bp.set_defaults(func=cmd_build)
    sub.add_parser("emit-swift").set_defaults(func=cmd_emit_swift)
    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
