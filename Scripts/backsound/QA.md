# Backsound listening QA

Open `Scripts/backsound/work/preview` (the app's own pianika samples playing the chart over each backing track, i.e. "the child playing perfectly") and tick each box after listening. Then check the same in the app (Listen mode, 1×) and tick the last column.

- **Cut clean**: the first and last seconds of the track sound musical (no click, fade-out ends the stanza smoothly).
- **Pitch natural**: the shifted recording sounds like normal music (not chipmunk/slowed) and the pianika is in tune with it.
- **Pianika in time**: the pianika notes land on the melody of the recording, from the first note to the last.
- **Right notes**: the notes are the right tune (pitch and rhythm).

## How sure the computer is (it cannot listen, R6)

`LIKELY` = the melody-range chroma of the recording agrees with the chart at the chosen position (≥ 60 % of the notes) **and** the DTW structure check agrees. `UNSURE` = it picked the best-looking position but the evidence is weak or the two checks disagree, so **listen to these first**. Numbers come from `reports/<slug>.md` → *Build (B5)*.
The onset-error test of the plan is not informative here (a busy guitar mix has an onset almost everywhere), so it is reported but not used.

## Fix sync by ear: the tap tool (recommended)

For recordings where the melody is buried under strings/chords (Indonesia Raya, Bagimu Negeri, Tanah Airku, Dari Sabang Sampai Merauke) the computer cannot find the tune, so tap it:

1. `Scripts/backsound/.venv/bin/python -I Scripts/backsound/backsound.py tap` and open http://localhost:8765
2. Pick the song, press **Play**, and tap **Space** on every melody note as you hear it (sing along in your head). 0.75× is easier. Backspace undoes; click a note to redo from there.
3. Tick **Check**: the pianika plays your taps over the music. Fix any note that is early/late.
4. **Save + build + install in app**: writes the taps to `overrides.json`, rebuilds the chart + backing track and copies them into the app. The player under the button is exactly what Listen mode plays.

Taps override everything else for that song. For songs with a clear melody on top, `backsound.py autotap --only <slug>` does this automatically (used for Mengheningkan Cipta); check it in the tool anyway.

## If a song is early/late or has the wrong notes

1. Wrong position or tempo (the pianika starts too early/late or drifts): find the real time (s, in the pitch-shifted file `work/shifted/<slug>.wav`, same clock as the original) when the first note of the written melody sounds, add it to `Scripts/backsound/overrides.json`, e.g. `{"tanah-airku": {"first_note": 21.0}}`, then run
   `Scripts/backsound/.venv/bin/python -I Scripts/backsound/backsound.py build --only tanah-airku` and copy `work/out/chart_<slug>.json` / `bgm_<slug>.m4a` into the app (`Melodissimo/Data/Charts`, `Melodissimo/Data/Sound/Backing`).
2. Wrong key (sounds off against the pianika): add `"shift": <semitones>` to the same override (try the value printed as the runner-up in the report).
3. Wrong notes or rhythm: fix `reference/<slug>.txt` (see `reference/SOURCES.md` for how it was read) and run `build --only <slug>` again.

| # | Song | Computer says | Cut clean | Pitch natural | Pianika in time | Right notes | In app (Listen 1×) | Notes |
|---|------|---------------|-----------|---------------|-----------------|-------------|--------------------|-------|
| 1 | Indonesia Raya | UNSURE (chroma 46 %, key +5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 2 | Bagimu Negeri | UNSURE (chroma 41 %, key +2) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 3 | Hari Merdeka | LIKELY (chroma 91 %, key -5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 4 | Garuda Pancasila | LIKELY (chroma 98 %, key -5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 5 | Maju Tak Gentar | LIKELY (chroma 70 %, key +3) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 6 | Bangun Pemudi Pemuda | LIKELY (chroma 93 %, key +5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 7 | Bendera Merah Putih | LIKELY (chroma 86 %, key -5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 8 | Mars Harapan Bangsa | UNSURE (chroma 68 %, key +2) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 9 | Indonesia Tetap Merdeka | LIKELY (chroma 81 %, key -5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 10 | Bhinneka Tunggal Ika | UNSURE (chroma 28 %, key +3) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 11 | Api Kemerdekaan | UNSURE (chroma 74 %, key -5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 12 | Halo Halo Bandung | LIKELY (chroma 80 %, key +0) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 13 | Tanah Airku | UNSURE (chroma 26 %, key +5) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 14 | Dari Sabang Sampai Merauke | UNSURE (chroma 23 %, key +2) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 15 | Mengheningkan Cipta | UNSURE (chroma 71 %, key +0) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| 16 | Gugur Bunga | UNSURE (chroma 71 %, key +0) | [ ] | [ ] | [ ] | [ ] | [ ] | |
