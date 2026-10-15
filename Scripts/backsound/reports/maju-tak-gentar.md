# Maju Tak Gentar — analysis (B2)

- master: `work/songs/05_maju-tak-gentar.wav`, 218.2 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | A major | 0.826 | A |
| 2 | A minor | 0.606 | C |
| 3 | E major | 0.551 | E |

**Suggested shift:** +3 semitones (do A → C)

## Tempo

- beat_track: **132.5 bpm** (half 66.3, double 265.0)
- stability: max deviation 22 ms at 89.7 s (of 218 s)
- beats tracked: 473

## Draft melody (pyin, shifted so do = C)

- notes: 61, range 5. … 3˙
- similarity to the app melody: 0.51

```
5(0.5) 5(0.5) 3˙(0.5) 3˙(0.5) 3˙(0.5) 1˙(0.5) 1˙(0.5) 5(0.5)
5(0.5) 4(0.5) 4(0.5) 7(0.5) 7(0.5) 2˙(0.5) 2˙(0.5) 3˙(0.5)
1˙(0.5) 1˙(0.5) 4(0.5) 4(0.5) 7(0.5) 2˙(0.5) 1˙(0.5) 1˙(0.5)
5(0.5) 5(0.5) 3˙(0.5) 1˙(0.5) 1˙(0.5) 1˙(0.5) 5(0.5) 5.(0.5)
4(0.5) 4(0.5) 2˙(0.5) 2˙(0.5) 3˙(0.5) 1˙(0.5) 4(0.5) 4(0.5)
2˙(0.5) 2˙(0.5) 1˙(0.5) 5(0.5) 3˙(0.5) 1˙(0.5) 1˙(0.5) 1˙(0.5)
4(0.5) 4(0.5) 2˙(0.5) 2˙(0.5) 3˙(0.5) 1˙(0.5) 4(0.5) 4(0.5)
7(0.5) 7(0.5) 2˙(0.5) 2˙(0.5) 1˙(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 15.22 | 5 | 0.5 |
| 15.70 | 5 | 0.5 |
| 17.09 | 3˙ | 0.5 |
| 17.45 | 3˙ | 0.5 |
| 17.93 | 3˙ | 0.5 |
| 18.90 | 1˙ | 0.5 |
| 19.26 | 1˙ | 0.5 |
| 20.70 | 5 | 0.5 |
| 21.61 | 5 | 0.5 |
| 22.49 | 4 | 0.5 |
| 22.95 | 4 | 0.5 |
| 24.31 | 7 | 0.5 |
| 24.79 | 7 | 0.5 |
| 26.13 | 2˙ | 0.5 |
| 26.59 | 2˙ | 0.5 |
| 31.60 | 3˙ | 0.5 |
| 33.43 | 1˙ | 0.5 |
| 33.83 | 1˙ | 0.5 |
| 36.99 | 4 | 0.5 |
| 37.43 | 4 | 0.5 |
| 38.81 | 7 | 0.5 |
| 40.65 | 2˙ | 0.5 |
| 42.48 | 1˙ | 0.5 |
| 42.89 | 1˙ | 0.5 |
| 65.94 | 5 | 0.5 |
| 66.39 | 5 | 0.5 |
| 68.17 | 3˙ | 0.5 |
| 69.60 | 1˙ | 0.5 |
| 69.78 | 1˙ | 0.5 |
| 69.97 | 1˙ | 0.5 |

## Build (B5)

- key check: shift +3 (r=0.81, next -2 r=0.37); B2 guess 3
- pitch shift: +3 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 132.5 bpm vs hint 132); DTW at 132.5 bpm: path slope 0.87, cost 0.296, melody starts at 15.7 s
- grid pick (chroma score among 7 candidates that agree with DTW; earliest of 1 near-equal): j0 34, first note at 15.06 s, median |grid - DTW| over the first 12 notes 187 ms (67% within 250 ms; over all notes 299 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 15562/0.436; j0=0.25 15451/0.420; j0=0.5 15340/0.416; j0=0.75 15227/0.432
- best by chroma score (first note s / dtw err ms / score): 159.8 s / 144603 / 0.665; 15.0 s / 187 / 0.658; 65.7 s / 50484 / 0.657; 160.0 s / 144829 / 0.636; 15.3 s / 201 / 0.631; 65.9 s / 50709 / 0.630
- time map: smoothed tracked grid (tracker 132.5 bpm), refine +30 ms
- timing: median onset error 27 ms, p90 65 ms (85/85 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 70%
- tempo: steady, bpm 132.6; max line residual 10 ms
- game cut: 9.63–60.00 s of the shifted file (fade-out 2.0 s), 50 s long, pad 0.00 s
- offset 5.424 s (m4a lag +0.0 ms), m4a 0.83 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 1.3.00 `3` chroma 0.03, onset error 33 ms
- bar 11.3.00 `2˙` chroma 0.04, onset error 27 ms
- bar 15.3.00 `4˙` chroma 0.04, onset error 21 ms
- bar 9.3.00 `3` chroma 0.06, onset error 33 ms
- bar 3.3.00 `2˙` chroma 0.06, onset error 23 ms
- bar 18.2.00 `3˙` chroma 0.14, onset error 36 ms
- bar 22.2.00 `3˙` chroma 0.17, onset error 15 ms
- bar 20.1.00 `3˙` chroma 0.19, onset error 28 ms
- bar 17.4.75 `2˙` chroma 0.21, onset error 84 ms
- bar 23.4.00 `3˙` chroma 0.23, onset error 20 ms
