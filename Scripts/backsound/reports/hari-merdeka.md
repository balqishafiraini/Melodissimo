# Hari Merdeka — analysis (B2)

- master: `work/songs/03_hari-merdeka.wav`, 179.3 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | F major | 0.884 | F |
| 2 | A minor | 0.751 | C |
| 3 | C major | 0.719 | C |

**Suggested shift:** -5 semitones (do F → C)

## Tempo

- beat_track: **120.2 bpm** (half 60.1, double 240.4)
- stability: max deviation 243 ms at 50.4 s (of 179 s)
- beats tracked: 354

## Draft melody (pyin, shifted so do = C)

- notes: 8, range 5. … 7
- similarity to the app melody: 0.06

```
2(1) 7(0.5) 4#(0.5) 6(0.5) 5.(0.5) 2(0.5) 1(0.5) 1(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 0.09 | 2 | 1 |
| 1.36 | 7 | 0.5 |
| 48.34 | 4# | 0.5 |
| 48.79 | 6 | 0.5 |
| 84.44 | 5. | 0.5 |
| 103.86 | 2 | 0.5 |
| 104.87 | 1 | 0.5 |
| 136.32 | 1 | 0.5 |

## Build (B5)

- key check: shift -5 (r=0.81, next +0 r=0.52); B2 guess -5
- pitch shift: -5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 120.2 bpm vs hint 120); DTW at 120.2 bpm: path slope 0.97, cost 0.293, melody starts at 84.0 s
- grid pick (chroma score among 8 candidates that agree with DTW; earliest of 1 near-equal): j0 168, first note at 83.98 s, median |grid - DTW| over the first 12 notes 49 ms (100% within 250 ms; over all notes 62 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 83971/0.420; j0=0.25 83843/0.406; j0=0.5 83715/0.412; j0=0.75 83588/0.398
- best by chroma score (first note s / dtw err ms / score): 84.0 s / 49 / 0.814; 84.1 s / 115 / 0.748; 83.8 s / 134 / 0.696; 83.7 s / 259 / 0.647; 127.9 s / 43984 / 0.637; 84.2 s / 240 / 0.634
- time map: smoothed tracked grid (tracker 120.2 bpm), refine +10 ms
- timing: median onset error 36 ms, p90 76 ms (72/72 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 91%
- tempo: tempo map (beatTimes), bpm 120.4; max line residual 48 ms
- game cut: 81.74–111.22 s of the shifted file (fade-out 2.0 s), 29 s long, pad 0.00 s
- offset 1.998 s (m4a lag +0.0 ms), m4a 0.43 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 16.1.00 `2` chroma 0.49, onset error 15 ms
- bar 14.2.75 `1` chroma 0.57, onset error 15 ms
- bar 19.1.00 `2` chroma 0.59, onset error 44 ms
- bar 14.2.00 `1` chroma 0.62, onset error 50 ms
- bar 15.2.00 `2` chroma 0.63, onset error 10 ms
- bar 21.2.00 `4` chroma 0.63, onset error 18 ms
- bar 12.2.00 `3` chroma 0.64, onset error 17 ms
- bar 2.2.00 `3` chroma 0.66, onset error 46 ms
- bar 5.1.50 `5.` chroma 0.67, onset error 36 ms
- bar 20.2.00 `3` chroma 0.68, onset error 22 ms
