# Melodissimo — Backsound Plan (real instrumental music for every song)

> **Ringkasan (buat Balqis)**
> - Sumber musik: video YouTube *"INSTRUMEN LAGU WAJIB NASIONAL"* (16 lagu, 46:59). Kapan tiap lagu mulai udah dideteksi dari titik putih di video (§2.2). Sonnet nanti motong persis di jeda heningnya.
> - Daftar lagu di app diganti jadi **persis 16 lagu itu, urut sesuai video**. 8 lagu lama hilang dari daftar (progress-nya nggak dihapus), 6 lagu baru masuk, "Merah Putih" ganti nama jadi "Bendera Merah Putih" (progress-nya ikut dipindah).
> - Tiap lagu dapet backsound `.m4a` di dalam app (versi `.mp3` juga dibikin di folder kerja buat kamu). Nadanya digeser (pitch-shift) biar **do = C**, sama kayak not angka di app.
> - Chart (tuts yang jatuh kayak Piano Tiles) dan sheet not angka **dibikin ulang dari rekaman itu**: nadanya dari notasi (PNG di app + riset web), ketukannya dari rekaman.
> - Bagian kamu: izinin install tool (`brew`), dengerin preview tiap lagu lalu centang `Scripts/backsound/QA.md`, dan OK-in susunan campaign yang baru.
> - ⚠️ Rekaman itu karya orang lain. Aman buat dipakai sendiri atau presentasi kelas. Sebelum rilis ke App Store/TestFlight, minta izin dulu atau ganti backsound-nya. Pipeline-nya tinggal dijalanin ulang dengan file audio lain.

This document is written for an AI executor (Claude Sonnet 5.5) working **one task per session**, exactly like `GAME_PLAN.md`. It adds **Phase 9 (tasks B0–B9)**.

**Session prompt for the user to paste:**
```
Read GAME_PLAN.md sections 3 and 4, then BACKSOUND_PLAN.md sections 1–4 fully, then Task B<N>.
Execute Task B<N> only, following the executor rules in both files.
For tasks marked ⚠︎, write a short plan first and wait for my OK before coding.
Finish with: build + tests passing (code tasks), checkbox ticked, commit, and a list of things I should check by hand.
```

---

## Progress tracker

| Task | Title | Kind | Depends on |
|---|---|---|---|
| B0 | Prep: clean tree, tools, skeleton | setup | — |
| B1 | Download and cut the 16 songs | audio | B0 |
| B2 | Analyze each recording (key, tempo, draft melody) | audio | B1 |
| B3 | ⚠︎ Reference melodies (research) | data | B2 |
| B4 | Chart format v2 + engine hooks (logic only) | code | — (any time) |
| B5 | ⚠︎ Build charts and game tracks (listening gate) | audio + data | B3 |
| B6 | ⚠︎ Install the 16 songs (library + campaign + migration) | code | B4, B5 |
| B7 | ⚠︎ Backing track playback in Song Stage | code | B6 |
| B8 | ⚠︎ Not angka sheet drawn from the chart | code | B6 |
| B9 | Final QA and docs | QA | all |

B4 touches no data and can run first or in parallel with B1–B3.

---

## 1. Goal and decisions

### 1.1 Goal
When a song is played in the Song Stage (the falling-notes, Piano-Tiles-like mode), its real instrumental plays underneath, in sync with the falling notes, at every speed (0.5×, 0.75×, 1×). The song list, the charts and the score sheets all match those recordings.

### 1.2 Decisions (already made; don't re-litigate)

| # | Decision | Why |
|---|---|---|
| D1 | The app's song list becomes **exactly the 16 songs of the video, in video order** (§2.3). | The user chose this. |
| D2 | Titles use the **official spelling**: "Bagimu Negeri" (video: "Bagimu Negri"), "Bangun Pemudi Pemuda" (video: "Bangun Pemuda Pemudi"), "Bhinneka Tunggal Ika" (video: "Bhineka"), "Bendera Merah Putih" (app was "Merah Putih"). | The video's labels have typos. Changing a title later costs a progress migration, so get it right once. |
| D3 | Every backing track is **pitch-shifted so do = C** (shift range −6…+5 semitones, smallest move wins). | The app teaches not angka with fixed keys (`1` = C4). A track in, say, B♭ would clash with what the child plays. |
| D4 | Charts take their **pitches and rhythm from the written melody** (§3.2 reference files) and their **timing from the recording's beat grid**. They do not come from note-by-note audio transcription. | Melody extraction from a full mix is unreliable. A beat grid is reliable, so written rhythm on a measured grid gives an exact, playable chart. |
| D5 | The in-game track (the "game cut") = **up to 2 bars or 6 s of intro, plus the first complete pass of the melody**, then either the natural ending or a 1.5 s fade. | Stage length stays close to today's charts (about 1–2 min). |
| D6 | Bundled format is **AAC `.m4a`, 128 kb/s** (`bgm_<slug>.m4a`). MP3 copies of the full songs go to `Scripts/backsound/work/mp3/` for the user. | Same format as the note samples. AVFoundation decodes it with exact timing. |
| D7 | The backing plays in **Listen, Practice and Perform**. It **pauses while Practice waits** for the right key. It is **off in Real-pianika (microphone) mode**. A **Settings toggle** (on by default) controls it. | The microphone would hear the music and detect wrong notes. |
| D8 | The score sheet shown in the app is **drawn from the chart** (not angka) for all 16 songs, replacing the PNGs. | 5 new songs have no PNG, and the sheet must match what the backing plays. |
| D9 | **"Gugur Bunga" becomes solemn** (calm stage, no monster, no combo flames), like Indonesia Raya and Mengheningkan Cipta. *(Default; the user may veto at the B6 ⚠︎ review.)* | It is a song of mourning for fallen heroes. |
| D10 | "Merah Putih" → "Bendera Merah Putih": progress keys are **copied** to the new slug once. Old keys stay. | GAME_PLAN §4 rule 2: never remove keys. |
| D11 | The 8 retired songs disappear from every list. Their progress keys stay in UserDefaults, untouched. | Same rule. |
| D12 | The campaign is rebuilt from the 16 songs with **the smallest possible curriculum change** (§5 B6). | Chapter 1 has lost both of its songs. |

---

## 2. Source data (already researched; trust it, but verify)

### 2.1 The video
- URL: `https://www.youtube.com/watch?v=8zULnhUmem4`, channel "JABBAR", title "INSTRUMEN LAGU WAJIB NASIONAL", **2819 s (46:59)**, no description and no chapters.
- The picture is static: a guitar plus a numbered list of 16 titles. A **white dot** marks the song that is playing. The times below were found by sampling YouTube's storyboard frames (one every 10 s) and detecting which row has the dot. They are accurate to **about ±10 s**. B1 finds the exact cut points in the audio.

### 2.2 Track list and approximate timestamps

| # | Video label | App title (D2) | Approx. start | Approx. length | B1 boundary search window (s) before this song |
|---|---|---|---|---|---|
| 1 | Indonesia Raya | Indonesia Raya | 0:00 | 1:45 | — (start of file) |
| 2 | Bagimu Negri | Bagimu Negeri | ~1:45 | 1:10 | 85–125 |
| 3 | Hari Merdeka | Hari Merdeka | ~2:55 | 3:00 | 155–195 |
| 4 | Garuda Pancasila | Garuda Pancasila | ~5:55 | 2:50 | 335–375 |
| 5 | Maju Tak Gentar | Maju Tak Gentar | ~8:45 | 3:30 | 505–545 |
| 6 | Bangun Pemuda Pemudi | Bangun Pemudi Pemuda | ~12:15 | 3:30 | 715–755 |
| 7 | Bendera Merah Putih | Bendera Merah Putih | ~15:45 | 2:30 | 925–965 |
| 8 | Mars Harapan Bangsa | Mars Harapan Bangsa | ~18:15 | 3:30 | 1075–1115 |
| 9 | Indonesia Tetap Merdeka | Indonesia Tetap Merdeka | ~21:45 | 3:10 | 1285–1325 |
| 10 | Bhineka Tunggal Ika | Bhinneka Tunggal Ika | ~24:55 | 3:40 | 1475–1515 |
| 11 | Api Kemerdekaan | Api Kemerdekaan | ~28:35 | 3:20 | 1695–1735 |
| 12 | Halo Halo Bandung | Halo Halo Bandung | ~31:55 | 3:10 | 1895–1935 |
| 13 | Tanah Airku | Tanah Airku | ~35:05 | 4:00 | 2085–2125 |
| 14 | Dari Sabang Sampai Merauke | Dari Sabang Sampai Merauke | ~39:05 | 2:50 | 2325–2365 |
| 15 | Mengheningkan Cipta | Mengheningkan Cipta | ~41:55 | 1:30 | 2495–2535 |
| 16 | Gugur Bunga | Gugur Bunga | ~43:25 | 3:35 | 2585–2625 (song ends at the file end, ~2819 s) |

(Raw detection: the dot was on row *n* until storyboard frame L and on row *n+1* from frame L+1, frame time = index × 10 s. Each window is [L×10 − 15, (L+1)×10 + 15].)

### 2.3 Song manifest (B0 writes this to `Scripts/backsound/songs.json` verbatim)

```json
[
  {"n": 1,  "title": "Indonesia Raya",             "slug": "indonesia-raya",             "image": "indonesiaRaya",           "status": "kept",    "png": true,  "draft": false, "solemn": true},
  {"n": 2,  "title": "Bagimu Negeri",              "slug": "bagimu-negeri",              "image": "bagimuNegeri",            "status": "new",     "png": true,  "draft": false, "solemn": false},
  {"n": 3,  "title": "Hari Merdeka",               "slug": "hari-merdeka",               "image": "hariMerdeka",             "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 4,  "title": "Garuda Pancasila",           "slug": "garuda-pancasila",           "image": "garudaPancasila",         "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 5,  "title": "Maju Tak Gentar",            "slug": "maju-tak-gentar",            "image": "majuTakGentar",           "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 6,  "title": "Bangun Pemudi Pemuda",       "slug": "bangun-pemudi-pemuda",       "image": "bangunPemudiPemuda",      "status": "new",     "png": false, "draft": false, "solemn": false},
  {"n": 7,  "title": "Bendera Merah Putih",        "slug": "bendera-merah-putih",        "image": "merahPutih",              "status": "renamed", "oldTitle": "Merah Putih", "oldSlug": "merah-putih", "png": true, "draft": true, "solemn": false},
  {"n": 8,  "title": "Mars Harapan Bangsa",        "slug": "mars-harapan-bangsa",        "image": "marsHarapanBangsa",       "status": "new",     "png": false, "draft": false, "solemn": false},
  {"n": 9,  "title": "Indonesia Tetap Merdeka",    "slug": "indonesia-tetap-merdeka",    "image": "indonesiaTetapMerdeka",   "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 10, "title": "Bhinneka Tunggal Ika",       "slug": "bhinneka-tunggal-ika",       "image": "bhinnekaTunggalIka",      "status": "new",     "png": false, "draft": false, "solemn": false},
  {"n": 11, "title": "Api Kemerdekaan",            "slug": "api-kemerdekaan",            "image": "apiKemerdekaan",          "status": "new",     "png": false, "draft": false, "solemn": false},
  {"n": 12, "title": "Halo Halo Bandung",          "slug": "halo-halo-bandung",          "image": "haloHaloBandung",         "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 13, "title": "Tanah Airku",                "slug": "tanah-airku",                "image": "tanahAirku",              "status": "kept",    "png": true,  "draft": false, "solemn": false},
  {"n": 14, "title": "Dari Sabang Sampai Merauke", "slug": "dari-sabang-sampai-merauke", "image": "dariSabangSampaiMerauke", "status": "kept",    "png": true,  "draft": true,  "solemn": false},
  {"n": 15, "title": "Mengheningkan Cipta",        "slug": "mengheningkan-cipta",        "image": "mengheningkanCipta",      "status": "kept",    "png": true,  "draft": true,  "solemn": true},
  {"n": 16, "title": "Gugur Bunga",                "slug": "gugur-bunga",                "image": "gugurBunga",              "status": "new",     "png": false, "draft": false, "solemn": true}
]
```
- `png`: a score sheet exists in `Melodissimo/Assets.xcassets/Notasi/<image>.imageset/`.
- `draft`: a hand-drafted chart exists in `Melodissimo/Data/Charts/chart_<slug or oldSlug>.json` (made from the PNG, unverified).
- **Retired songs** (removed from the app; keep their keys and their PNG assets): Berkibarlah Benderaku, Hymne Guru, Ibu Kita Kartini, Ibu Pertiwi, Indonesia Pusaka, Rayuan Pulau Kelapa, Satu Nusa Satu Bangsa, Terima Kasih Guru.

---

## 3. Technical design

### 3.1 Folder layout
```
Scripts/backsound/
  backsound.py            ONE file, argparse subcommands (no local imports, see rule R3)
  songs.json              manifest (§2.3)
  cuts.json               generated by B1: exact start/end of each song in the source (committed)
  reference/<slug>.txt    melody + rhythm, hand-made and verified (§3.2) (committed)
  reference/SOURCES.md    where each melody came from, conflicts, choices (committed)
  reports/<slug>.md       generated analysis/build reports, plus reports/summary.md (committed, small)
  sheets/<slug>.txt       generated not angka sheet of the final chart, for humans (committed)
  QA.md                   the user's listening checklist (committed)
  work/                   GITIGNORED: source audio, full.wav, masters, shifted wavs, previews, mp3, out/
  .venv/                  GITIGNORED
Melodissimo/Data/Sound/Backing/bgm_<slug>.m4a    bundled tracks (installed in B6)
Melodissimo/Data/Charts/chart_<slug>.json        bundled charts v2 (installed in B6)
```
The Xcode project uses synchronized folders (`objectVersion = 70`), so files on disk are bundled automatically. Resources are copied flat, which is why `Bundle.main.url(forResource: "bgm_<slug>", withExtension: "m4a")` works without a subdirectory.

### 3.2 Melody reference format (`reference/<slug>.txt`)
A small text format that maps 1:1 from not angka. The same format is used for the generated `sheets/<slug>.txt`.

```
title: Contoh Lagu
slug: contoh-lagu
beats_per_bar: 4
bpm_hint: 100
pickup: 1                 # beats before the first full bar (0 if none)
ending: auto              # auto | natural | fade   (see B5 step 10)
sources: Notasi/contohLagu.png; https://example.org/...
---
5. | 1 - 3 [2 1] | 5 - - 0 | [6 5] [4 3] 2 1 |
1 - [- 7.] 6. | 5. - - - ||
@anchor bar=9 time=48.210   # optional, see B5 step 7
```
(The melody above is invented, just to show the syntax.)

Rules:
- **Pitch tokens are the app's labels** (`NoteCatalog`): `4. 5. 6. 7. 1 2 3 4 5 6 7 1˙ 2˙ 3˙ 4˙ 5˙ 6˙ 7˙ 1˙˙` and sharps `4.# 5.# 6.# 1# 2# 4# 5# 6# 1˙# 2˙# 4˙# 5˙# 6˙#`. ASCII alias: `'` = `˙` (`1'` = `1˙`, `1''` = `1˙˙`).
- ⚠️ **In the app's labels a trailing `.` means LOW OCTAVE (dot under the digit), never "hold".** Sustain is always `-`.
- One whitespace-separated token = **one beat**: a pitch, `0` (rest) or `-` (hold the previous note one more beat).
- `[ … ]` splits **one beat** into 2, 3, 4, 6 or 8 equal slots. Inside it, `-` holds for one slot and `0` rests for one slot. Underline = `[a b]`, double underline = `[a b c d]`, dotted eighth + sixteenth = `[a - - b]`, triplet = `[a b c]`.
- `-` as the first token of a bar ties over the bar line.
- `|` = bar line, `||` = end. The first bar holds `pickup` beats when `pickup > 0`. Every other bar must hold exactly `beats_per_bar` beats, except the last one.
- **Beat numbering:** beat 0 is the downbeat of the (possibly partial) first bar. The first pickup note therefore sits at `b = beats_per_bar − pickup`. Bar *n* (1-based, first full bar = 1) starts at `b = (n − 1 + (pickup > 0 ? 1 : 0)) × beats_per_bar`. `check-ref` prints each bar number with its start beat.
- Flats → the sharp of the note below (`7b` → `6#`, `3b` → `2#`, `6b` → `5#`).
- Write the music **out in full, in the order it is played** (expand repeat signs and voltas). Don't copy lyrics.

### 3.3 Chart format v2 (`chart_<slug>.json`)
Backwards compatible: every new field is optional, and old files still decode.
```json
{
  "id": "hari-merdeka",
  "title": "Hari Merdeka",
  "bpm": 112.4,
  "beatsPerBar": 4,
  "offset": 3.412,
  "beatTimes": [3.412, 3.946, 4.480],
  "notes": [ { "k": 2, "b": 3.0, "d": 0.5 }, { "k": 2, "b": 3.5, "d": 0.5 } ]
}
```
- `offset`: seconds into `bgm_<slug>.m4a` (at 1×) where **beat 0** sounds. If it is `nil`, the chart is not synced and no backing plays.
- `beatTimes` (optional tempo map): the track time (s, at 1×) of beat 0, 1, 2, … It is present only when the recording's tempo moves (rubato, ritardando), and then `beatTimes[0] == offset`. Beats past either end continue at the edge interval.
- `bpm`: the tempo of the first beats (it drives the 3-beat count-in). With a tempo map, it is `60 / median(first 8 intervals)`.
- `beatsPerBar`: bar lines on the sheet. `nil` means 4.
- **Song time 0 = beat 0.** Track position for a song time `t` at speed `s` = `offset + t × s`. This holds with or without a tempo map, because `seconds(atBeat:)` is measured from `beatTimes[0]`.

### 3.4 Runtime playback design (B4 + B7)
```
song clock (wall s):  −leadIn ……………… −countIn ··· 3 · 2 · 1 ··· 0 (beat 0) ……… notes ……… finish
backing position:     offset + t·speed (+ outputLatency·speed so the sound reaches the ears on time)
```
- `RhythmEngine` gains a `leadIn` (a longer pre-roll so the track's intro can play) and an `onClockEvent` callback. The callback fires `.running(songTime, hostTime)`, `.halted(songTime)` or `.finished` whenever the song clock starts, pauses, freezes (Practice wait), resumes, restarts or ends.
- `BackingTrackPlayer` (a service with AVFoundation) only reacts to those events: seek + `play(atTime:)` on `.running`, pause on `.halted`, fade out on `.finished`. A 1-second drift check re-seeks if the player and the clock differ by more than 50 ms.
- `AVAudioPlayer.enableRate = true` + `rate = speed` time-stretches without changing pitch (0.5×–2× supported).
- The count-in numbers only show in the **last 3 beats** before beat 0, even when the lead-in is longer.

### 3.5 New persistence keys (add them to GAME_PLAN §3.4 in B6/B7)

| Key | Type | Meaning |
|---|---|---|
| `settings_backingTrack` | Bool | backing music on/off, default **true** (absent = true) |
| `migration_songRenames_v1` | Bool | the D10 copy has run |

---

## 4. Executor rules (in addition to GAME_PLAN §4)

- **R1** Never commit `Scripts/backsound/work/` or `Scripts/backsound/.venv/`. Stage only the paths you touched (GAME_PLAN §4 rule 9).
- **R2** Run Python only through the venv, **with `-I`**: `Scripts/backsound/.venv/bin/python -I Scripts/backsound/backsound.py <cmd> …`. The downloaded audio is untrusted data. Only decode and analyze it (ffmpeg, afconvert, librosa); never execute anything from `work/`.
- **R3** Keep `backsound.py` as **one file**. `-I` removes the script's folder from `sys.path`, so local imports would fail.
- **R4** Ask the user before any `brew install` / `brew upgrade`.
- **R5** Long commands (download, analyzing 16 songs) need a timeout of ≥ 10 min or a background run. Each subcommand accepts `--only <slug>` so one song can be redone.
- **R6** You cannot listen to audio. Rely on the numeric checks in each task and on the user's ears (QA.md). Never claim a track "sounds right". Say which numbers passed.
- **R7** Copyright: don't copy lyrics into the repo or the reports. Melodies only. Record every web source URL in `reference/SOURCES.md`.
- **R8** If YouTube blocks the download, don't use cookies or account credentials. Ask the user to save the audio themselves to `Scripts/backsound/work/source.<ext>`.
- **R9** Swift rules are GAME_PLAN §3.1 (iOS 16.6, iPad landscape, no iOS 17 APIs) and §4 (tests, localization, style, commits). Record decisions under **§7 Executor notes** of this file.

---

## 5. Tasks

### Task B0 — Prep: clean tree, tools, skeleton
- [x] done

**Touches:** `.gitignore`, `Scripts/backsound/` (new), `BACKSOUND_PLAN.md`.

1. `git status`. Earlier sessions left uncommitted work: modified `SoundModel.swift`, `EchoView/EchoViewModel`, `BattleView`, `TilesComponentView`, `CalibrationView`, `AppRouter` and tests, plus **15 untracked `Melodissimo/Data/Charts/chart_*.json` drafts**. **Ask the user** whether to commit it (suggested message: `Stop sounds on screen exit + draft charts`) or stash it. Don't start on a dirty tree. B3 needs the drafts, so they must survive.
2. Tools: `which yt-dlp ffmpeg ffprobe`. If any is missing, ask, then `brew install yt-dlp ffmpeg`. Check `ffmpeg -hide_banner -filters | grep rubberband`. If it's absent, ask, then `brew install rubberband` (B5 then uses the `rubberband` CLI).
3. Python: Homebrew's Python 3.14 is too new for librosa (its numba dependency). Use `~/.local/bin/python3.11` (it exists on this Mac). Otherwise ask to `brew install python@3.12`.
   ```bash
   ~/.local/bin/python3.11 -m venv Scripts/backsound/.venv
   ```
   ```bash
   Scripts/backsound/.venv/bin/pip install "librosa>=0.10" soundfile numpy scipy
   ```
   ```bash
   Scripts/backsound/.venv/bin/python -I -c "import librosa, soundfile; print(librosa.__version__)"
   ```
4. Append to `.gitignore`:
   ```
   # Backsound pipeline (BACKSOUND_PLAN.md)
   Scripts/backsound/work/
   Scripts/backsound/.venv/
   ```
5. Create `Scripts/backsound/songs.json` (§2.3 verbatim), `reference/SOURCES.md` (one `## <title>` heading per song) and `QA.md` (template in B5).
6. Create `backsound.py` with argparse subcommands, stubs for now: `selftest, fetch, cut, analyze, json2ref, check-ref, build, emit-swift`. Shared helpers:
   - Paths: the repo root is found from `__file__`. `WORK = Scripts/backsound/work`.
   - `load_manifest()`.
   - `NOTE_TABLE`: the 32 `(id, label, sound, semitone)` rows. MIDI = 53 + semitone. `selftest` re-parses `Melodissimo/Models/Music/Note.swift` with a regex over `Note(id: …, label: "…", sound: "…", semitone: …)` and asserts the table is identical. It also checks the `'` → `˙` alias.
   - `parse_ref(path)` → header dict + list of `(k, b, d)` + anchors (§3.2), with clear error messages (line, token, bar number).
   - `chart_to_dsl(notes, beats_per_bar, pickup)` → DSL text (the inverse; used by `json2ref` and the sheets). Per beat, pick the smallest slot count in {1, 2, 3, 4, 6, 8} that puts every start/end inside the beat on a slot (tolerance 0.01 beat).
7. `selftest` also round-trips a small invented melody: DSL → notes → DSL → notes, equal.
8. Commit: `Task B0: backsound pipeline setup`.

**Done when:** tools present, the venv imports librosa, `selftest` passes, tree clean.

---

### Task B1 — Download and cut the 16 songs
- [x] done

**Touches:** `backsound.py` (`fetch`, `cut`), `Scripts/backsound/cuts.json`.

1. **`fetch`**:
   ```bash
   yt-dlp -f bestaudio -o "Scripts/backsound/work/source.%(ext)s" "https://www.youtube.com/watch?v=8zULnhUmem4"
   ```
   Then convert to `work/full.wav` (44.1 kHz, stereo, 16-bit PCM) with `ffmpeg -i work/source.<ext> -ar 44100 -ac 2 -c:a pcm_s16le work/full.wav`. Assert the duration is 2819 ± 3 s. If it's blocked, see R8.
2. **`cut`**, implemented in Python with `soundfile` (sample-exact; read only the 40 s window, never the whole 47-min file):
   - For each of the 15 windows in §2.2: RMS in 20 ms frames of the mono mix, in dBFS. Find the **longest run below −45 dBFS lasting ≥ 0.3 s**. If none, retry at −40, −35, −30 dBFS. If still none, take the lowest point of the 200 ms-smoothed RMS and mark the boundary `"no-silence"`.
   - Song *n* ends at `silence_start + 0.25 s` (keeps the reverb tail). Song *n+1* starts at `silence_end − 0.05 s`.
   - Song 1 starts at the first frame above −45 dBFS minus 0.05 s. Song 16 ends at the last frame above −45 dBFS plus 0.5 s.
   - Write `cuts.json`: `[{ "n", "slug", "start", "end", "duration", "boundary": "silence -45dB" | "silence -40dB" | … | "no-silence" }]`, seconds with 3 decimals.
   - Write masters `work/songs/NN_<slug>.wav` (exact slices, no fades) and MP3 copies `work/mp3/NN - <Title>.mp3` (`ffmpeg -i … -c:a libmp3lame -q:a 2`). The MP3s are for the user; the app doesn't use them.
   - `cut --from-json` re-slices from an edited `cuts.json` (for manual fixes).
3. Print a table: n, title, start (m:ss.s), end, duration, boundary type. Sanity: each duration is within ±20 s of §2.2 and between 0:50 and 5:00. If not, investigate (wrong silence picked?) before going on.
4. Ask the user to spot-check the boundaries: `open Scripts/backsound/work/mp3`. They listen to the first and last 5 s of each file, especially the `no-silence` ones. Fix any reports via `cuts.json` + `cut --from-json`.
5. Commit `backsound.py` + `cuts.json`: `Task B1: cut the 16 backing songs`.

**Done when:** 16 masters + 16 MP3s exist, `cuts.json` is committed, and the user confirmed the cuts are clean.

---

### Task B2 — Analyze each recording
- [x] done

**Touches:** `backsound.py` (`analyze`), `Scripts/backsound/reports/<slug>.md`, `reports/summary.md`.

For each master (`analyze [--only slug]`):
1. `y, sr = librosa.load(master, sr=22050, mono=True)`, then `yh, yp = librosa.effects.hpss(y)`.
2. **Key guess (Krumhansl–Schmuckler)**: `chroma = librosa.feature.chroma_cqt(y=yh, sr=sr, hop_length=512).mean(axis=1)`. Correlate it with the 12 rotations of the major profile `[6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]` and the minor profile `[6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]`. **do** = the tonic for major, tonic + 3 for minor. Suggested shift = `−do` wrapped into [−6, +5]. Report the top 3 keys with their scores.
3. **Tempo**: `tempo, beats = librosa.beat.beat_track(y=y, sr=sr, hop_length=256, units="time")`. Report bpm, the half and double alternatives, and stability: the max deviation of the beat times from a straight-line fit, plus where it happens (e.g. "ritardando in the last 10 s").
4. **Draft melody** (to help B3, not used directly in charts): `f0, voiced, prob = librosa.pyin(yh, fmin=130.8, fmax=2093, sr=sr, frame_length=2048, hop_length=256)`. Keep frames with `prob ≥ 0.6`. MIDI = `hz_to_midi(f0) + shift`. Segment into notes: runs of the same rounded MIDI (ignore 1-frame glitches), ≥ 70 ms long, split a run wherever `librosa.onset.onset_detect` (on `yh`) finds an onset, so repeated notes separate. Move the octave so the median note lands in C4…B4, then map to the nearest app label. Durations in beats come from the detected tempo, rounded to 0.5.
5. **Song identity check** (kept songs only): pitch-class LCS ratio between the draft and the app's current melody (`LevelFeederModel` `answer` array; parse the Swift file by regex). Ratio = LCS length / app melody length. **≥ 0.5** = plausible. **< 0.3** = probably the wrong song or a wrong cut, so tell the user.
6. Write `reports/<slug>.md` (key table, shift, tempo + stability, range, the draft melody as DSL-ish lines, the first 30 detected notes with times, the similarity) and a one-row-per-song `reports/summary.md`.
7. Commit: `Task B2: analyze backing songs`.

**Done when:** 16 reports + summary exist, and every song with similarity < 0.3 has been raised with the user.

---

### Task B3 — ⚠︎ Reference melodies (research)
- [x] done

**Touches:** `Scripts/backsound/reference/<slug>.txt` (16), `reference/SOURCES.md`, `backsound.py` (`json2ref`, `check-ref`).

Goal: for each song, the melody **exactly as the child should play it on the pianika**, in the §3.2 format, do = C, written out in full for **one complete pass**.

**Sources, in priority order:**
1. **The app's score sheets.** Open `Melodissimo/Assets.xcassets/Notasi/<image>.imageset/*.png` with the Read tool (it shows images). 11 songs have one: Indonesia Raya, Bagimu Negeri, Hari Merdeka, Garuda Pancasila, Maju Tak Gentar, Bendera Merah Putih (`merahPutih`), Indonesia Tetap Merdeka, Halo Halo Bandung, Tanah Airku, Dari Sabang Sampai Merauke, Mengheningkan Cipta.
2. **The draft charts** (8 songs, `draft: true`). `json2ref Melodissimo/Data/Charts/chart_<slug-or-oldSlug>.json --beats-per-bar N` converts them to DSL as a starting point. They start at b = 0 with no pickup, so fix the pickup and bar lines against the PNG.
3. **The web**, for the 5 songs with neither (Bangun Pemudi Pemuda, Mars Harapan Bangsa, Bhinneka Tunggal Ika, Api Kemerdekaan, Gugur Bunga). Use WebSearch with several phrasings: `not angka <judul>`, `not pianika <judul>`, `partitur <judul>`, `<judul> do = C`, `<judul> ciptaan`. WebFetch the hits. You need **≥ 2 independent sources that agree**, or 1 source that agrees with the B2 audio draft. Prefer sources that show the composer and the key. If "Mars Harapan Bangsa" is ambiguous (several songs share the name), identify the one in the recording by comparing it with the B2 draft.
4. **The B2 audio draft**: the tie-breaker. When the recording and the sources disagree, **the recording wins on rhythm and structure** (the child plays along with it). **The sources win on pitch**, unless the recording clearly holds a different note for ≥ 1 beat.

**Rules:**
- Not angka is already relative (1 = do), so the digits stay as written. Only copy the octave dots and the rhythm carefully (§3.2; mind the `.` vs `-` trap).
- Range must stay within `4.` … `1˙˙` (F3–C6). If a source goes lower, raise the whole song an octave and note it.
- Kept songs: stay consistent with the app's current melody unless the recording clearly differs; then follow the recording and note it.
- **Bendera Merah Putih**: confirm the app's "Merah Putih" is the same tune as track 7 (B2 similarity + PNG). If it isn't, research "Bendera Merah Putih" fresh.
- `beats_per_bar` and `pickup` come from the score (a 6/8 song: use `beats_per_bar: 2` with triplet slots, or `6` with the eighth as the beat; pick whichever gives a `bpm_hint` between 50 and 140, and say which).
- `bpm_hint` = B2's tempo in the reference's beat unit.

**`check-ref <slug>`**: parses the file. Checks bar lengths, keys 1–32, a pickup consistent with the first bar, and at least 16 notes. Prints the bar list (number → start beat), the note count, and the pitch-class LCS ratio against the B2 draft (expect **≥ 0.5**). Exits non-zero on any error.

⚠︎ **Before writing the 16 files**, post a table for the user: song | sources used | meter | pickup | agreement with the recording | open doubts. Wait for an OK, especially on the 5 web-sourced songs.

**SOURCES.md**, per song: the files and URLs used, which version was chosen, every conflict and how it was resolved, and any octave change.

Commit: `Task B3: reference melodies for the 16 songs`.

**Done when:** all 16 pass `check-ref`, each has similarity ≥ 0.5 or a written explanation, and the user has OK'd them.

---

### Task B4 — Chart format v2 + engine hooks (logic only)
- [x] done

Independent of B0–B3; it can run first.

**Touches:** `Models/Music/SongChart.swift`, `Models/Game/BackingSchedule.swift` (new), `Models/Game/HighwayGeometry.swift` (`CountIn`), `ViewModels/Stage/RhythmEngine.swift`; tests `SongChartTests`, `RhythmEngineTests`, `HighwayGeometryTests` (or wherever `CountIn` is tested), new `BackingScheduleTests`.

1. **`SongChart`**: add the fields **after `notes`** so existing `SongChart(id:title:bpm:notes:)` calls still compile:
   ```swift
   /// Beats per bar, for bar lines on the score sheet. `nil` means 4.
   var beatsPerBar: Int? = nil
   /// Seconds into the backing track (at 1×) where beat 0 sounds. `nil` when the chart isn't synced to a track.
   var offset: Double? = nil
   /// Optional tempo map for recordings whose tempo moves: the track time (s, at 1×) of beat 0, 1, 2, …
   /// `beatTimes[0] == offset`. Beats past either end continue at the edge interval.
   var beatTimes: [Double]? = nil
   ```
   Synthesized `Codable` decodes missing optionals as `nil`, so old files keep working.
   ```swift
   /// Seconds after beat 0 at 1× speed.
   func seconds(atBeat beat: Double) -> Double {
       guard let map = beatTimes, map.count >= 2 else { return beat * 60 / bpm }
       let i = min(max(Int(beat.rounded(.down)), 0), map.count - 2)
       return map[i] + (beat - Double(i)) * (map[i + 1] - map[i]) - map[0]
   }

   /// The backing-track position that goes with a song-clock time (song time 0 = beat 0).
   func backingTime(songTime: Double, speed: Double) -> Double {
       (offset ?? 0) + songTime * speed
   }
   ```
   Rewrite `timedNotes(speed:)` on top of it: `time = seconds(atBeat: b) / speed`, `duration = (seconds(atBeat: b + d) − seconds(atBeat: b)) / speed`.
   Extend `isValid`: `offset == nil || offset >= 0`; `beatsPerBar == nil || (1...12).contains`; if `beatTimes` is present: ≥ 2 entries, strictly increasing, `offset != nil` and `abs(beatTimes[0] − offset!) < 0.001`.
2. **`BackingSchedule`** (new, `Foundation` only):
   ```swift
   /// Timing maths for playing a backing track in step with the song clock. Pure, so it's unit-tested.
   enum BackingSchedule {
       /// The pre-roll may outlast the count-in by at most this much, so a long intro isn't a long wait.
       static let maxExtraLeadIn = 4.0
       /// Drift beyond this is corrected by seeking.
       static let resyncTolerance = 0.05

       /// How long the song clock runs before beat 0 when a backing track plays (wall seconds).
       static func leadIn(offset: Double, speed: Double, countIn: Double) -> Double {
           max(countIn, min(offset / speed, countIn + maxExtraLeadIn))
       }

       /// Where to start the track and how long to wait from `hostTime`, so the sound *heard*
       /// at `hostTime` belongs to `songTime` (output latency is sent ahead).
       static func start(songTime: Double, speed: Double, offset: Double, outputLatency: Double) -> (position: Double, delay: Double) {
           let position = offset + songTime * speed + outputLatency * speed
           return position >= 0 ? (position, 0) : (0, -position / speed)
       }

       static func needsResync(expected: Double, actual: Double) -> Bool {
           abs(expected - actual) > resyncTolerance
       }
   }
   ```
3. **`CountIn.display`**: return `nil` while more than `beats` beats remain (`-songTime > Double(beats) * secondsPerBeat + 1e-9`), so the 3-2-1 only shows in the last 3 beats of a longer lead-in. Inside the 3 beats, nothing changes.
4. **`RhythmEngine`**:
   - Add the init parameter `leadIn: Double = 0` (wall seconds) and `let leadInDuration: Double` = `max(countInDuration, leadIn)`. Use `-leadInDuration` everywhere `-countInDuration` is used for the clock (init `freeze`, `start`, `restart`). Keep `countInDuration` for the count-in display.
   - Add the event type and a callback:
     ```swift
     /// What the song clock is doing, for anything that must follow it (the backing track).
     enum ClockEvent: Equatable {
         /// Running: at host time `hostTime` the clock reads `songTime`.
         case running(songTime: Double, hostTime: CFTimeInterval)
         /// Stopped at `songTime` (pause, Practice wait, restart).
         case halted(songTime: Double)
         case finished
     }
     var onClockEvent: ((ClockEvent) -> Void)?
     ```
   - Emit `.running(-leadInDuration, now)` in `start`. Emit `.halted(t)` in `pause`. In `resume`, emit `.running(t, now)` only when not waiting. In `restart`, emit `.halted(-leadInDuration)` and then let `start` emit `.running`. When `stepPractice` freezes at a note, emit `.halted(note.time)`. When `pressPractice` unfreezes, emit `.running(note.time, now)`. In `finish`, emit `.finished` (once).
5. **Tests**:
   - SongChart: a v1 JSON (no new keys) decodes with nils; a v2 JSON decodes; `seconds(atBeat:)` interpolates, extrapolates below 0 and past the end; `timedNotes` with a map at speed 0.5; `isValid` rejects decreasing `beatTimes`, an offset mismatch, a negative offset and `beatsPerBar: 0`; `backingTime`.
   - BackingSchedule: the lead-in cap (short intro → count-in; long intro → count-in + 4); `start` with a positive and a negative position; latency at speed 0.5; `needsResync`.
   - CountIn: `nil` at 5 beats before 0; 3 at exactly 3 beats; unchanged at 1.5.
   - RhythmEngine with fake times: the initial song time is `−max(countIn, leadIn)`; the event sequences for Perform (start → pause → resume → finish), Practice (`.halted(note.time)` on reaching a note, `.running` on the right key) and restart.
6. Build + all tests pass. Commit: `Task B4: chart format v2 and clock events`.

---

### Task B5 — ⚠︎ Build charts and game tracks (listening gate)
- [x] done

**Touches:** `backsound.py` (`build`, `emit-swift`), `reference/*.txt` (anchors only), `sheets/`, `reports/`, `QA.md`. Outputs are **staged** in `work/out/` and `work/preview/`; nothing goes into the app yet.

⚠︎ Plan first: post which songs B2 flagged (unstable tempo, low similarity, big shifts) and how you'll handle them.

`build [--only slug]`, per song:
1. **Parse** `reference/<slug>.txt` → notes `(k, b, d)` + anchors.
2. **Key check**: the duration-weighted pitch-class histogram of the reference vs the histogram of the master's pyin frames (prob ≥ 0.6). The best of the 12 rotations gives the audio's do; shift = `−do` wrapped into [−6, +5]. If it disagrees with B2's guess, use it when its correlation beats the runner-up by ≥ 0.1; otherwise stop and report.
3. **Pitch-shift** the master to `work/shifted/<slug>.wav` (44.1 kHz stereo). Preference order: the ffmpeg filter `rubberband=pitch=<2^(shift/12)>:pitchq=quality`; then the `rubberband` CLI (`rubberband -3 -p <shift> in.wav out.wav`); last, `librosa.effects.pitch_shift` per channel. Shift 0 = copy. Assert the length is unchanged (±1 ms; pad or trim the end).
4. **Features** of the shifted file (mono 22050): `hpss` harmonic part, `chroma_cqt` (hop 512), `pyin` (hop 256), onset envelope (hop 256), beats from `beat_track(hop_length=256, start_bpm=bpm_hint, tightness=100, units="time")`. Extend the beat list at both ends with the median interval so it covers the whole file.
5. **Pulse ratio and beat 0**: for each ratio r in {0.5, 2/3, 1, 1.5, 2} (reference beats per tracked beat), the reference beat *i* maps to time `T(i) = interp(trackedBeats, j0 + i·r)`. Search `j0` in steps of 0.5 tracked beats over the first 70% of the song. Score =
   mean over notes of `0.5·chromaMatch + 0.3·pyinMatch + 0.2·onsetHit`, where:
   - `chromaMatch` = mean over the note's middle 80% of `chroma[pc] / max(chroma)`
   - `pyinMatch` = the share of voiced frames whose pitch class is the note's
   - `onsetHit` = the normalized onset envelope peak within ±40 ms of the note start.

   Take the best `(r, j0)`. Among candidates scoring ≥ 0.95 × best, take the **earliest** `j0`, so the first pass wins over a repeat. Report the top 5.
6. **Song check**: if the best score is far below the other songs (< 0.75 × the median of finished songs), stop. Likely causes: the wrong song, a different arrangement, or a wrong meter.
7. **Anchors** (`@anchor bar=N time=T`, T in shifted-file seconds): pin the downbeat of bar N to T. Between two anchors, re-space beats linearly. Outside them, shift the grid to meet the nearest anchor. Use anchors for fermatas, rubato or a beat tracker that slipped. Find the times from the onset list in the report.
8. **Timing and pitch QA**, then a pass/fail:
   - onset error = the distance from each note start to the nearest detected onset within ±150 ms. **Median ≤ 40 ms, 90th percentile ≤ 100 ms.**
   - pitch agreement = the duration-weighted share of notes whose pyinMatch ≥ 0.5. **≥ 55%** (a full mix hides the melody sometimes; compare with the other songs).
   - List the 10 worst notes: bar.beat, expected label, heard label, timing error.
   - On a fail, try in this order: another pulse ratio or meter, the reference vs the recording (fix the reference), anchors. After 3 tries, ask the user.
9. **Tempo map decision**: fit a straight line to `T(i)` over beat 0 … the last note's end. If every residual is ≤ 20 ms, the tempo is steady: `bpm = 60 / slope`, `offsetTime = T(0)` from the fit, and no `beatTimes`. Otherwise keep `beatTimes` = `T(0…ceil(lastEnd)+1)` and set `bpm = 60 / median(first 8 intervals)`.
10. **Game cut** (D5), times in the shifted file:
    - `firstNote = T(b_first)`, `lastEnd = T(b_last + d_last)`, `bar = beats_per_bar × beat length`.
    - `start` = the beat time closest to and not after `firstNote − min(2·bar, 6.0)`, never below 0.
    - Ending: `ending: natural`, or `auto` with ≤ 8 s of audio left after `lastEnd`, keeps the master's own ending (end = file end, 0.3 s fade). Otherwise `end = lastEnd + bar` with a 1.5 s fade-out finishing at `end`.
    - Fade in 0.15 s.
11. **Render**: slice `[start, end]` from the shifted file (soundfile, sample-exact) and apply the fades. Run two-pass `loudnorm` (`I=-16:TP=-1.5:LRA=11`, then the second pass with the measured values and `linear=true`, `-ar 44100`) → `work/out/bgm_<slug>.wav`. Encode with `afconvert -f m4af -d aac -b 128000 work/out/bgm_<slug>.wav work/out/bgm_<slug>.m4a`. **Verify the timing**: decode the m4a back (`afconvert -f WAVE -d LEI16 …`), cross-correlate its first 15 s with the pre-loudnorm slice and get the lag. `offset = (T(0) − start) + lag`. Report any |lag| > 5 ms.
12. **Chart** → `work/out/chart_<slug>.json`: `id`/`title` from the manifest, `bpm`, `beatsPerBar`, `offset` (3 decimals), `beatTimes` shifted by `−start` (4 decimals) or omitted, and the notes exactly as in the reference (b and d unchanged). Validate with a Python port of `SongChart.isValid` (v2 rules from B4). Format it like the existing chart files (sorted keys, 2-space indent).
13. **Preview** → `work/preview/NN_<slug>_preview.m4a`: the decoded m4a at gain 0.8, plus the app's own pianika samples (decode `Melodissimo/Data/Sound/whiteTiles|blackTiles/<sound>.m4a` with afconvert once into `work/samples/`). Each sample is placed at `offset + seconds(atBeat: b)`, cut to the note length plus a 30 ms fade. This is "the child playing perfectly over the backing".
14. **Sheet** → `sheets/<slug>.txt`: a header (title, `do = C`, meter, ♩ = bpm) plus the DSL from `chart_to_dsl`, 4 bars per line.
15. **Report**: append a "Build" section to `reports/<slug>.md` (shift, ratio, j0, scores, timing stats, the worst notes, tempo-map yes/no, cut start/end, offset, lag, file size). Update `reports/summary.md`.

`emit-swift`: reads the manifest and `work/out/chart_*.json`. Prints the 16 Swift `LevelModel(levelCategory: "song", levelNo: 1, question: [labels…], answer: [ids…], songTitle: "…", songNotImg: "<image>")` entries in manifest order, ready to paste in B6.

**`QA.md` template** (B0 creates it; the user fills it in):
```
| # | Song | Cut clean | Pitch natural | Pianika in time | Right notes | Notes |
|---|------|-----------|---------------|-----------------|-------------|-------|
| 1 | Indonesia Raya | [ ] | [ ] | [ ] | [ ] | |
… (16 rows)
```
**Listening gate:** run `open Scripts/backsound/work/preview` for the user and ask them to fill in QA.md. Fix every flagged song (back to step 7 or B3) and re-run `build --only <slug>` until all 64 boxes are ticked.

Commit (reference anchors, sheets, reports, QA.md, script): `Task B5: build charts and backing tracks`.

**Done when:** all 16 songs pass step 8, all 16 m4a files are under 3 MB each, and QA.md is fully ticked by the user.

---

### Task B6 — ⚠︎ Install the 16 songs (library + campaign + migration)
- [x] done

**Touches:** `Melodissimo/Data/Charts/` (add 16, remove retired), `Melodissimo/Data/Sound/Backing/` (new, 16 files), `Models/Level/LevelFeederModel.swift`, `Models/Music/SongLibrary.swift`, `Models/Campaign/Campaign.swift`, `Models/Campaign/StoryCards.swift`, `Models/Progress/ProgressStore+Game.swift`, `MelodissimoApp.swift` (migration call), `Views/FreePlay/FreePlayView.swift`, `Data/id.lproj/Localizable.strings`, `GAME_PLAN.md` (§2.3, §3.4), tests (list below).

⚠︎ Plan first: post the proposed **chapter table** (step 5) together with each song's required chapter, and wait for the user's OK (the D9 Gugur Bunga choice is part of this review).

1. **Install the files**: copy `work/out/chart_<slug>.json` → `Melodissimo/Data/Charts/` and `work/out/bgm_<slug>.m4a` → `Melodissimo/Data/Sound/Backing/`. `git rm` the charts of the retired songs (`berkibarlah-benderaku, hymne-guru, ibu-kita-kartini, ibu-pertiwi, indonesia-pusaka, rayuan-pulau-kelapa, satu-nusa-satu-bangsa`) and `chart_merah-putih.json` (now `chart_bendera-merah-putih.json`). Keep the `Notasi` PNGs.
2. **`LevelFeederModel.songLevel`**: replace the whole array with the `emit-swift` output (16 entries, video order). By construction, `answer` equals each chart's keys.
3. **`SongLibrary`**: update the doc comment (16 songs). `solemnTitles = ["Indonesia Raya", "Mengheningkan Cipta", "Gugur Bunga"]` (D9). Add:
   ```swift
   /// Songs whose title changed; their progress is copied once to the new slug (see `ProgressStore.migrateRenamedSongs`).
   static let renamedTitles: [String: String] = ["Merah Putih": "Bendera Merah Putih"]
   /// Songs no longer in the app. Their keys stay; "Reset progress" still clears their trophy flags.
   static let retiredTitles: Set<String> = ["Berkibarlah Benderaku", "Hymne Guru", "Ibu Kita Kartini", "Ibu Pertiwi",
       "Indonesia Pusaka", "Rayuan Pulau Kelapa", "Satu Nusa Satu Bangsa", "Terima Kasih Guru", "Merah Putih"]
   ```
4. **Migration (D10)**: `ProgressStore.migrateRenamedSongs()` runs once, guarded by `migration_songRenames_v1`. For each old → new pair:
   - copy `song_bestScore_`, `song_bestAccuracy_`, `song_stars_` with **max**, and `song_practiced_`, `song_fullCombo_` with **or**, from the old slug to the new slug;
   - copy the trophy bool key `<old title>` → `<new title>` (or).

   Old keys stay. Call it from `MelodissimoApp` next to `runMigrationIfNeeded()`. `isResettableKey`'s default `songTitles` becomes `current ∪ retiredTitles`.
5. **Campaign (D12)**, working with `CampaignCatalog.chapters`:
   1. `required(song)` = the smallest chapter c whose `notesTaught(through: c)` contains all the song's keys. Compute it for all 16. Today's curriculum is c1 `[5…12]`, c2 `[4,3,2]`, c3 `[1,13,14]`, c4 `[15,16,17]`, c5 sharps, c6 the rest. The 10 kept songs all need c2 or later, so **chapter 1 probably has no song that fits.**
   2. If no non-solemn song has `required == 1`, move notes from **c2's `newNotes` to the end of c1's** one at a time, in the order `2` (5.), `4` (7.), `3` (6.), re-computing after each move, and stop as soon as one non-solemn song fits c1. If c2 is then left with fewer than 2 new notes, also move `1` (4.) from c3 to the end of c2. **Never change c4–c6.** If it's still impossible, stop and ask.
   3. The finale (c6) stays **Indonesia Raya**.
   4. **Bosses** (one per chapter, never solemn, `required ≤ chapter`): keep the current boss where it still exists and fits (c2 Garuda Pancasila, c3 Hari Merdeka, c6 Dari Sabang Sampai Merauke). Fill the other chapters with the hardest remaining fitting song (highest `required`, then most notes).
   5. **Chapter songs**: the remaining 9 (including Mengheningkan Cipta and Gugur Bunga). Each goes to a chapter ≥ its `required`. Keep each chapter's count **≤ its current count** (c1 1, c2 3, c3 2, c4 3, c5 2, c6 0). Then stage ids only get removed from the end of a chapter, never added, so nobody loses an unlocked stage.
   6. Post the table for the ⚠︎ OK, then edit `chapters`.
6. **Story cards**: rewrite each line that names a boss song (`boss_N`) to name the new boss. If c1/c2 changed, fix any intro line that describes the notes ("low notes", "black keys") so it stays true. Add the Indonesian lines.
7. **Free Play**: `"Pick any of the 18 songs"` → `Text("Pick any of the \(SongLibrary.all.count) songs")`, with the id.lproj key `"Pick any of the %lld songs" = "Pilih salah satu dari %lld lagu";`.
8. **Tests to update** (found by grep):
   - `SongChartTests`: the `berkibarlah` helper → `"Hari Merdeka"`; counts 18 → 16; the solemn set (3 titles); the all-songs test now also asserts `chart.offset != nil` and that `Bundle.main` has `bgm_<id>.m4a`.
   - `NoteCatalogTests`: count 18 → 16.
   - `CampaignTests`: `used.count` 16. Keep `testEverySongBossAndFinaleOnlyUsesNotesTaughtSoFar` and make it pass with the new table.
   - `ChartRecorderTests`, `SongProgressTests`, `ResultRecorderTests`: `"merah-putih"` → `"bendera-merah-putih"`; `SongProgressTests` count 18 → 16.
   - `StoryAndBossTests`, `DailyChallengeTests`, `CoinTests`: `"Terima Kasih Guru"` → a non-solemn kept song (e.g. `"Halo Halo Bandung"`), keeping each test's intent.
   - `SettingsTests`: `isResettableKey("Berkibarlah Benderaku")` still true (a retired title).
   - New: a migration test (max/or semantics, runs once, old keys kept).
9. **GAME_PLAN.md**: update the §2.3 chapter table and the §3.4 keys (§3.5 of this file), and add an executor note pointing here.
10. Build + all tests. Commit: `Task B6: install the 16 backing-track songs`.

**Manual QA:** Free Play lists the 16 in video order with the right titles. A player who had stars on "Merah Putih" sees them on "Bendera Merah Putih". The campaign map shows the new songs. Every song opens in Practice. (No music plays until B7. The 5 new songs show a blank score card until B8; both are expected.)

---

### Task B7 — ⚠︎ Backing track playback in Song Stage
- [x] done

**Touches:** `Services/BackingTrackPlayer.swift` (new), `Views/Stage/SongStageView.swift`, `Models/Progress/ProgressStore+Game.swift`, `Views/Settings/SettingsView.swift`, `Views/Song/Learn/SongLearnView.swift` (optional step 6), `Data/id.lproj/Localizable.strings`, tests.

1. **Setting**: `backingTrackEnabled` (key `settings_backingTrack`, absent = true), copying the `sfxEnabled` pattern. Add a test for the default.
2. **`BackingTrackPlayer`** (`ObservableObject`, AVFoundation):
   ```swift
   /// Plays a song's instrumental (`bgm_<songId>.m4a`) in step with the stage's song clock by following the
   /// engine's `ClockEvent`s: seek and start on `.running`, pause on `.halted`, fade out on `.finished`.
   final class BackingTrackPlayer: ObservableObject {
       static let volume: Float = 0.55
       static func resourceName(for songId: String) -> String { "bgm_\(songId)" }
       static func isAvailable(for songId: String, bundle: Bundle = .main) -> Bool { … }

       func load(songId: String, offset: Double, speed: Double, bundle: Bundle = .main)  // enableRate before prepareToPlay
       func handle(_ event: ClockEvent)
       func stop()
   }
   ```
   - `.running(t, host)`: call `configureAudioSessionIfNeeded()`. `plan = BackingSchedule.start(songTime: t, speed:, offset:, outputLatency: AVAudioSession.sharedInstance().outputLatency)`. Then `pause()`; if `plan.position ≥ duration`, return; `currentTime = plan.position`; `volume = Self.volume`; `wait = max(0, host − CACurrentMediaTime()) + plan.delay`; `play(atTime: deviceCurrentTime + wait)`. Remember `anchor = (plan.position, CACurrentMediaTime() + wait)` and start a 1 s repeating `Timer` (RunLoop `.common`) for the drift check (step 3).
   - `.halted`: stop the timer, `pause()`, `anchor = nil`.
   - `.finished`: stop the timer, `setVolume(0, fadeDuration: 1.2)`, then `stop()` after 1.3 s.
   - `stop()`: stop the timer and the player. Also call it in `deinit`.
3. **Drift check**: once ≥ 0.5 s past the anchor's host time, `expected = anchor.position + (now − anchor.host) × speed`. If `BackingSchedule.needsResync(expected:actual: currentTime)`, set `currentTime = expected`.
4. **Wire it into `SongStageView`**:
   - In `init`, compute `let usesBacking = settings.backingTrackEnabled && !microphone && chart == nil && BackingTrackPlayer.isAvailable(for: song.id)` (`chart == nil` excludes the recorder's preview). Store it, and capture it in the engine's autoclosure: `leadIn = usesBacking && playedChart.offset != nil ? BackingSchedule.leadIn(offset: playedChart.offset!, speed: speed, countIn: RhythmEngine.countInBeats * 60 / (playedChart.bpm * speed)) : 0`.
   - `@StateObject private var backing = BackingTrackPlayer()`.
   - In `onAppear`, **before** `engine.start`: if `usesBacking`, `backing.load(songId: song.id, offset: engine.chart.offset ?? 0, speed: speed)` and `engine.onClockEvent = { [weak backing] in backing?.handle($0) }`.
   - In `onDisappear`: `engine.onClockEvent = nil` and `backing.stop()`.
   - Pause/resume/restart/background/finish already go through the engine, so the events cover them. Check each one by hand anyway.
5. **Settings**: a toggle card under the sound-effects toggle: "Backing music", with the footnote "Plays the song's instrumental in the song stage. Off in Real pianika mode." Indonesian: "Musik pengiring" / "Memutar musik instrumental lagu di panggung lagu. Mati saat mode Pianika asli."
6. *(Optional, small)* `SongLearnView`: a play/stop button that plays the song's backing from the start, with no sync (the learn screen has no clock). Stop it on disappear.
7. Build + tests. Commit: `Task B7: backing tracks in the song stage`.

**Manual QA** (iPad simulator, then a real iPad if available):
- Listen at 1×, 0.75× and 0.5× on one steady-tempo song and one with `beatTimes`: the pianika notes land on the music, and the music keeps its pitch at slow speeds.
- Perform: hits feel on the beat. Pause mid-song, resume: the music continues in sync. Restart: the music restarts from the intro.
- Practice: the music pauses while the stage waits and resumes on the right key.
- Home button / app switcher mid-song: the music stops; coming back shows the pause overlay; resuming is in sync.
- Finish: the music fades out and the results screen is silent. A Daily-challenge sprint (32 notes) fades after the 32nd note.
- The toggle off means no music. Real-pianika mode means no music.
- Solemn songs: the music plays, with no SFX or count-in ticks (unchanged rule).
- Bluetooth headphones: the music still lines up with the falling notes (latency compensation).

---

### Task B8 — ⚠︎ Not angka sheet drawn from the chart
- [x] done

**Touches:** `Models/Music/NotAngkaLayout.swift` (new, pure), `Views/Stage/NotAngkaSheetView.swift` (new), `Views/Stage/StageSetupView.swift` (`notationCard`), `Views/Song/Learn/SongLearnView.swift`, tests `NotAngkaLayoutTests`.

1. **`NotAngkaLayout`** (pure):
   ```swift
   enum NotAngkaSymbol: Hashable { case note(keyId: Int), hold, rest }
   struct NotAngkaBeat: Hashable { let slots: [NotAngkaSymbol] }   // 1, 2, 3, 4, 6 or 8 slots
   struct NotAngkaBar: Hashable { let number: Int; let beats: [NotAngkaBeat] }
   enum NotAngkaLayout { static func bars(for chart: SongChart) -> [NotAngkaBar] }
   ```
   Use the same algorithm as `chart_to_dsl` in B0 (the smallest slot count that fits every start/end in the beat; a slot is `.note` if a note starts there, `.hold` if one is sounding, else `.rest`). Bars are `beatsPerBar ?? 4` long. In the first bar, drop leading rest-only beats (a pickup shows only its notes). Ties across beats and bars become `.hold`.
2. **`NotAngkaSheetView(chart:)`**:
   - A header line "do = C · 4/4 · ♩ = 112".
   - A vertical `ScrollView` of rows of 4 bars, with `|` between bars and `||` at the end.
   - Digits in Baloo (~34 pt). Octave dots drawn as small circles: 1 below for labels ending in `.`, 1 above for `˙`, 2 above for `˙˙`. A small `#` superscript for sharps. `.hold` → a centred `·`. `.rest` → `0`.
   - One underline under a beat with 2 slots, two lines for 4 or 8 slots, and one line plus a small "3" for 3 or 6 slots.
   - Colours from the palette (`Color.darkGreen` text on white).
3. Replace `Image(song.notationImage)` in `StageSetupView.notationCard` and the score image in `SongLearnView` with `NotAngkaSheetView(chart: SongChart.load(for: song))`. Keep the white rounded card.
4. **Tests**: crafted charts covering a pickup, half beats, a dotted rhythm `[a - - b]`, rests inside a beat, a triplet, a tie across a bar, and 3/4 bars. Plus all 16 bundled charts produce bars whose beat counts match `beatsPerBar` (except the first and last bar).
5. Build + tests. Commit: `Task B8: not angka sheet from the chart`.

**Manual QA:** the sheet for 3 songs matches `Scripts/backsound/sheets/<slug>.txt`; long songs scroll; nothing is clipped in landscape on the smallest iPad.

---

### Task B9 — Final QA and docs
- [ ] done

1. The user plays each of the 16 songs in **Listen at 1×** in the app and adds an "In app" ✓ column to QA.md. Fix anything flagged (usually the chart offset: re-run `build --only`, re-install, and re-check).
2. Check that the audio-timing calibration (Settings) still behaves as before.
3. App size: `du -sh` of the built `.app`. The backing tracks should total < 30 MB; report the number.
4. GAME_PLAN.md: add a row "9 | Backsound: real instrumentals for the 16 songs | v3.x" to the progress tracker, update §1.3 (the inventory now has 16 songs with backing tracks), point §3.6 to §3.3 of this file for chart v2, and add an executor note that the DEBUG Chart Recorder writes charts **without** `offset`, so a re-recorded chart loses its backing sync until B5's `build` is re-run.
5. Tick every box in this file. Commit: `Task B9: backsound QA and docs`.

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| **Copyright**: the recording belongs to someone else (a YouTube re-upload). | Fine for personal use and class demos. Before App Store/TestFlight, get permission or replace the tracks. B5 accepts any audio file, so swapping is a re-run with new `cuts.json`/masters, not a rewrite. |
| YouTube blocks yt-dlp. | `brew upgrade yt-dlp` once; then the user saves the audio manually (R8). |
| The dot in the video is off by one song. | B2's similarity check plus the user's spot-check in B1. |
| A track is in a minor key or modulates. | The reference-based key check (B5 step 2) beats the profile guess. A modulating song gets a note in §7, and the user decides. |
| Big pitch shifts (±5–6) sound artificial. | rubberband at quality settings. If the user flags it in QA, try the other direction (e.g. +6 instead of −6) or accept a key the pianika can still play (that needs a chart transposition; ask first). |
| Rubato or fermatas break a single tempo. | The tempo map (`beatTimes`) and `@anchor`s. |
| The arrangement differs from the written melody. | The recording wins on rhythm and structure (B3 rule 4). |
| Chapter 1 has no song that fits. | The B6 step 5.2 curriculum shift, reviewed by the user. |
| Bluetooth latency. | Output latency is compensated in `BackingSchedule.start`. The existing audio-offset setting still covers input timing. |
| The microphone hears the music. | The backing is off in Real-pianika mode (D7). |

---

## 7. Executor notes
*(Record decisions where this plan was silent, one bullet per task.)*
- **B3:** (executed unattended, user pre-approved the table). The web score sources were images only, so they were downloaded to the scratchpad just to be read. Rhythm in the PNG angka sheets is ambiguous ('.' columns); bar-length sums decided it. Only one image source existed for Bangun Pemudi Pemuda, Mars Harapan Bangsa, Api Kemerdekaan and Gugur Bunga, so those four need the user's ear. One-stanza rule (user request): repeats, second verses and bridges were cut from every reference (see `reference/SOURCES.md`). `check-ref` also prints the B2 draft LCS, but most B2 drafts were empty/garbage, so B5's audio alignment score is the real pitch check.
- **B5:** (run unattended; the ⚠︎ plan was pre-approved) The pipeline is implemented as in the plan with these deviations, all forced by what a full guitar mix allows: (1) **ffmpeg here has no `rubberband` filter**, so shifting uses the `rubberband` CLI (`-3 -p <semitones>`, length trimmed/padded to the original). (2) The **key check** correlates the audio's mean *melody-range* chroma (MIDI 53–84) with the reference's duration-weighted pitch-class histogram; an optional `do_hint:` header (used for Mars Harapan Bangsa = Bb and Api Kemerdekaan = G) adds +0.08 to the sheet's own key. It overruled B2's guess for 6 songs: Mars Harapan Bangsa (−1 → +2), Dari Sabang Sampai Merauke (−3 → +2), Bangun Pemudi Pemuda (−2 → +5), Bhinneka Tunggal Ika (0 → +3), Gugur Bunga (+5 → 0, the recording is already in C) and Api Kemerdekaan (+4 → −5). (3) **pyin finds almost nothing in these mixes**, so it was dropped; the per-note score is 0.8·melody-chroma + 0.2·onset. (4) A plain beat-grid search (plan step 5) could not tell a right position from a wrong one, so each song is aligned by: tracker tempo → pulse ratio from `bpm_hint`; a **DTW** of a synthetic melody chroma against the recording at that tempo (rough note times); then the **smoothed tracker grid** gives precision. The grid offset `j0` is picked by melody-chroma score, DTW vetoing candidates only where it agrees with at least one; among near-equal candidates the earliest wins (the first pass beats a repeat). (5) The plan's **onset-error test is not informative** (peak picking on a busy mix finds an onset almost everywhere, so medians are ~25 ms regardless), so each song is labelled `LIKELY` (chroma agreement ≥ 60 % **and** DTW agrees) or `UNSURE`; 7 are LIKELY, 9 UNSURE (see `reports/summary.md`, QA.md). (6) `overrides.json` (`first_note`, `shift`) lets the user fix a position without touching code; `build --first-note` does the same from the command line. (7) The cut starts on a **bar line** (beat 0 of a bar, ≤ 2 bars or 6 s before the first note) with a 0.2 s fade-in and ends 0.75 bar after the last note (≥ 1.5 s) with a 2 s fade-out, or keeps the recording's own ending when ≤ 8 s remain. The user's one-stanza request is handled by the *references* (they stop at the end of the first pass or the end of a natural section; repeats are never spliced into the audio, because the chart must follow the recording continuously). (8) The m4a-vs-source cross-correlation lag was 0.0 ms for every song (afconvert's decoded AAC is sample-aligned), so `offset` = T(0) − start. The **listening gate (QA.md) is left for the user**; nothing was or could be listened to (R6).
- **B6:** (⚠︎ pre-approved) Campaign table, as computed by §5 step 5: no non-solemn song fit chapter 1, so `5.` (id 2) and `7.` (id 4) moved from chapter 2 to the end of chapter 1; chapter 2 was left with one new note, so `4.` (id 1) moved from chapter 3 to the end of chapter 2 (chapter 2 = `6. 4.`, chapter 3 = `2˙ 3˙`). Chapters 4–6 are untouched. Songs: c1 Bendera Merah Putih (boss Indonesia Tetap Merdeka); c2 Halo Halo Bandung, Bhinneka Tunggal Ika, Dari Sabang Sampai Merauke (boss Garuda Pancasila); c3 Bagimu Negeri, Mars Harapan Bangsa (boss Hari Merdeka); c4 Tanah Airku, Gugur Bunga (solemn) (boss Maju Tak Gentar); c5 Mengheningkan Cipta (solemn) (boss Api Kemerdekaan); c6 boss **Bangun Pemudi Pemuda**, finale Indonesia Raya. **Deviation:** Bangun Pemudi Pemuda needs `4˙#` (id 30, a chapter-6 note) and chapter 6 has no song slot, so it became the chapter-6 boss and Dari Sabang Sampai Merauke (the old c6 boss, which only needs chapter 2) moved to chapter 2. Stage ids in chapters 4 and 5 changed (the tour has **49 stages** now, 53 before), because those chapters have fewer songs than before; stage stars are keyed by stage id, so a player already in chapters 4–5 may see stars on different stages. Story cards `boss_1/4/5` now name Indonesia Tetap Merdeka / Maju Tak Gentar / Api Kemerdekaan. D9 (Gugur Bunga solemn) was applied as the default. The recorder test `ChartRecorderViewModelTests` uses Maju Tak Gentar because it starts 5, 5, 3.
- **B7:** `BackingTrackPlayer` follows the plan. The Settings toggle sits in the existing Sound-effects card under a divider (not a card of its own). Plan step 6 (play button in `SongLearnView`) was **skipped** (optional). **Not verified on a device:** no one could listen, so sync, latency compensation, pause/resume and Bluetooth behaviour need the manual QA list in §5 B7.
- **B8:** `NotAngkaLayout` mirrors `chart_to_dsl`; the sheet is drawn by `NotAngkaSheetView` (four bars to a row, vertical scroll) and replaces the PNG in `StageSetupView` and `SongLearnView`. The old `Notasi` PNGs stay in the asset catalog. Not checked on the smallest iPad (no screenshots taken).
