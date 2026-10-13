# Halo Halo Bandung — analysis (B2)

- master: `work/songs/12_halo-halo-bandung.wav`, 180.3 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | C major | 0.665 | C |
| 2 | G major | 0.547 | G |
| 3 | E minor | 0.499 | G |

**Suggested shift:** +0 semitones (do C → C)

## Tempo

- beat_track: **114.8 bpm** (half 57.4, double 229.7)
- stability: max deviation 272 ms at 1.1 s (of 180 s)
- beats tracked: 343

## Draft melody (pyin, shifted so do = C)

- notes: 1, range 6 … 6
- similarity to the app melody: 0.02

```
6(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 104.36 | 6 | 0.5 |

## Build (B5)

- key check: shift +0 (r=0.61, next +5 r=0.31); B2 guess 0
- pitch shift: +0 semitones (copy)
- alignment: pulse ratio 1 (tracker 114.8 bpm vs hint 115); DTW at 114.8 bpm: path slope 0.84, cost 0.281, melody starts at 19.9 s
- grid pick (chroma score among 7 candidates that agree with DTW; earliest of 1 near-equal): j0 30.5, first note at 17.12 s, median |grid - DTW| over the first 12 notes 2291 ms (0% within 250 ms; over all notes 34 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 18064/0.432; j0=0.25 17935/0.386; j0=0.5 17805/0.445; j0=0.75 17676/0.393
- best by chroma score (first note s / dtw err ms / score): 96.8 s / 77365 / 0.800; 17.1 s / 2291 / 0.799; 129.9 s / 110473 / 0.725; 50.2 s / 30817 / 0.710; 130.0 s / 110602 / 0.688; 96.7 s / 77236 / 0.677
- time map: smoothed tracked grid (tracker 114.8 bpm), refine -10 ms
- timing: median onset error 7 ms, p90 20 ms (62/62 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 80%
- tempo: steady, bpm 116.0; max line residual 8 ms
- game cut: 11.45–51.79 s of the shifted file (fade-out 2.0 s), 40 s long, pad 0.00 s
- offset 4.132 s (m4a lag +0.0 ms), m4a 0.65 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 2.4.00 `6.` chroma 0.24, onset error 12 ms
- bar 10.4.00 `6.` chroma 0.24, onset error 57 ms
- bar 3.3.00 `6.` chroma 0.25, onset error 1 ms
- bar 12.4.00 `6.` chroma 0.28, onset error 9 ms
- bar 14.3.00 `1` chroma 0.38, onset error 3 ms
- bar 14.2.50 `5` chroma 0.39, onset error 11 ms
- bar 14.2.00 `3` chroma 0.42, onset error 3 ms
- bar 1.4.50 `7.` chroma 0.50, onset error 10 ms
- bar 9.4.50 `7.` chroma 0.51, onset error 13 ms
- bar 8.4.00 `5.` chroma 0.54, onset error 62 ms
