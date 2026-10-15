# Gugur Bunga — analysis (B2)

- master: `work/songs/16_gugur-bunga.wav`, 210.8 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | G major | 0.825 | G |
| 2 | C major | 0.815 | C |
| 3 | E minor | 0.706 | G |

**Suggested shift:** +5 semitones (do G → C)

## Tempo

- beat_track: **120.2 bpm** (half 60.1, double 240.4)
- stability: max deviation 123 ms at 1.5 s (of 211 s)
- beats tracked: 411

## Draft melody (pyin, shifted so do = C)

- notes: 57, range 4. … 6
- similarity to the app melody: n/a (new song)

```
4(1.5) 4(0.5) 5(0.5) 5(0.5) 5(0.5) 4(1) 2(0.5) 4(1)
3(0.5) 6.(0.5) 6.(0.5) 6.(1) 5.(0.5) 5.(0.5) 5.(0.5) 5.(0.5)
5.(0.5) 3(0.5) 4(0.5) 3(0.5) 3(1) 1(0.5) 1(1) 7.(0.5)
2(1.5) 1(0.5) 1(1) 1(0.5) 1(0.5) 1(0.5) 2(0.5) 4(2)
5(0.5) 5(0.5) 6(0.5) 4(0.5) 2(0.5) 4(0.5) 4.(0.5) 3(1)
2(0.5) 6.(0.5) 5.(0.5) 5.(0.5) 5(0.5) 5(0.5) 3(1) 3(1)
2(0.5) 1(0.5) 1(2) 3(0.5) 3(0.5) 5(0.5) 5(0.5) 4.(0.5)
4.(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 3.27 | 4 | 1.5 |
| 3.92 | 4 | 0.5 |
| 4.27 | 5 | 0.5 |
| 4.44 | 5 | 0.5 |
| 4.59 | 5 | 0.5 |
| 7.70 | 4 | 1 |
| 8.42 | 2 | 0.5 |
| 8.71 | 4 | 1 |
| 11.04 | 3 | 0.5 |
| 14.28 | 6. | 0.5 |
| 14.52 | 6. | 0.5 |
| 16.73 | 6. | 1 |
| 17.24 | 5. | 0.5 |
| 17.82 | 5. | 0.5 |
| 17.95 | 5. | 0.5 |
| 18.32 | 5. | 0.5 |
| 18.47 | 5. | 0.5 |
| 20.84 | 3 | 0.5 |
| 23.02 | 4 | 0.5 |
| 23.30 | 3 | 0.5 |
| 24.22 | 3 | 1 |
| 25.52 | 1 | 0.5 |
| 26.56 | 1 | 1 |
| 27.48 | 7. | 0.5 |
| 28.29 | 2 | 1.5 |
| 29.47 | 1 | 0.5 |
| 30.20 | 1 | 1 |
| 30.89 | 1 | 0.5 |
| 31.78 | 1 | 0.5 |
| 32.00 | 1 | 0.5 |

## Build (B5)

- key check: shift +0 (r=0.83, next -5 r=0.68); B2 guess 5
- pitch shift: +0 semitones (copy)
- alignment: pulse ratio 1 (tracker 60.1 bpm vs hint 60); DTW at 60.1 bpm: path slope 0.88, cost 0.237, melody starts at 0.0 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 3 within 5% of the best): j0 31, first note at 32.23 s, median |grid - DTW| over the first 12 notes 31940 ms (0% within 250 ms; over all notes 31924 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 1619/0.554; j0=0.25 1855/0.510; j0=0.5 2091/0.511; j0=0.75 2327/0.443
- best by chroma score (first note s / dtw err ms / score): 96.2 s / 95947 / 0.847; 32.2 s / 31940 / 0.834; 128.2 s / 127965 / 0.820; 96.4 s / 96197 / 0.776; 128.5 s / 128213 / 0.753; 32.4 s / 32192 / 0.741
- time map: smoothed tracked grid (tracker 60.1 bpm), refine +30 ms
- timing: median onset error 30 ms, p90 47 ms (38/38 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 71%
- tempo: tempo map (beatTimes), bpm 61.3; max line residual 155 ms
- game cut: 25.28–68.14 s of the shifted file (fade-out 2.0 s), 43 s long, pad 0.00 s
- offset 4.124 s (m4a lag +0.0 ms), m4a 0.70 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 7.3.00 `6` chroma 0.03, onset error 44 ms
- bar 7.2.50 `4` chroma 0.06, onset error 26 ms
- bar 0.1.00 `3` chroma 0.25, onset error 28 ms
- bar 8.1.00 `5` chroma 0.26, onset error 27 ms
- bar 5.3.00 `4˙` chroma 0.28, onset error 43 ms
- bar 3.3.00 `5` chroma 0.34, onset error 32 ms
- bar 5.3.50 `3˙` chroma 0.45, onset error 32 ms
- bar 5.2.50 `3˙` chroma 0.62, onset error 17 ms
- bar 5.4.50 `7` chroma 0.67, onset error 33 ms
- bar 5.4.00 `2˙` chroma 0.79, onset error 22 ms
