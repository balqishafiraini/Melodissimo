# Bagimu Negeri — analysis (B2)

- master: `work/songs/02_bagimu-negeri.wav`, 70.6 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | A# major | 0.898 | A# |
| 2 | F major | 0.830 | F |
| 3 | D minor | 0.726 | F |

**Suggested shift:** +2 semitones (do A# → C)

## Tempo

- beat_track: **147.7 bpm** (half 73.8, double 295.3)
- stability: max deviation 128 ms at 64.3 s (of 71 s)
- beats tracked: 163

## Draft melody (pyin, shifted so do = C)

- notes: 3, range 5 … 1˙
- similarity to the app melody: n/a (new song)

```
5(0.5) 1˙(1.5) 5(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 2.67 | 5 | 0.5 |
| 5.17 | 1˙ | 1.5 |
| 15.72 | 5 | 0.5 |

## Build (B5)

- key check: shift +2 (r=0.88, next -5 r=0.64); B2 guess 2
- pitch shift: +2 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 73.8 bpm vs hint 74); DTW at 73.8 bpm: path slope 0.53, cost 0.295, melody starts at 8.0 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 24 within 5% of the best): j0 0, first note at -0.27 s, median |grid - DTW| over the first 12 notes 6960 ms (0% within 250 ms; over all notes 3078 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 6960/0.578; j0=0.25 6759/0.567; j0=0.5 6557/0.571; j0=0.75 6355/0.544
- best by chroma score (first note s / dtw err ms / score): 3.1 s / 3042 / 0.584; 40.4 s / 34195 / 0.580; -0.3 s / 6960 / 0.578; 4.9 s / 1206 / 0.577; 35.8 s / 29523 / 0.572; -0.0 s / 6557 / 0.571
- time map: smoothed tracked grid (tracker 73.8 bpm), refine -10 ms
- timing: median onset error 25 ms, p90 61 ms (41/42 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 41%
- tempo: tempo map (beatTimes), bpm 75.2; max line residual 371 ms
- game cut: 0.00–30.73 s of the shifted file (fade-out 2.0 s), 31 s long, pad 0.27 s
- offset 0.000 s (m4a lag +0.0 ms), m4a 0.50 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 6.2.75 `2˙` chroma 0.02, onset error 13 ms
- bar 1.3.00 `5` chroma 0.03, onset error 7 ms
- bar 2.2.75 `2˙` chroma 0.04, onset error 49 ms
- bar 5.2.75 `6` chroma 0.06, onset error 41 ms
- bar 4.2.75 `3` chroma 0.07, onset error 97 ms
- bar 1.4.00 `3` chroma 0.09, onset error 20 ms
- bar 5.4.00 `3` chroma 0.14, onset error 59 ms
- bar 8.1.67 `4` chroma 0.19, onset error 1 ms
- bar 6.3.00 `3˙` chroma 0.20, onset error 31 ms
- bar 8.1.33 `3` chroma 0.22, onset error 44 ms
