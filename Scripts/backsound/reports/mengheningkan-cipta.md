# Mengheningkan Cipta — analysis (B2)

- master: `work/songs/15_mengheningkan-cipta.wav`, 90.6 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | C major | 0.945 | C |
| 2 | G major | 0.734 | G |
| 3 | C minor | 0.549 | D# |

**Suggested shift:** +0 semitones (do C → C)

## Tempo

- beat_track: **136.0 bpm** (half 68.0, double 272.0)
- stability: max deviation 112 ms at 6.0 s (of 91 s)
- beats tracked: 183

## Draft melody (pyin, shifted so do = C)

- notes: 12, range 1 … 1˙˙
- similarity to the app melody: 0.17

```
5(0.5) 5(0.5) 5(0.5) 5(0.5) 1˙˙(0.5) 1˙(0.5) 1(0.5) 1˙(0.5)
1˙(0.5) 1(0.5) 1(0.5) 1(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 0.35 | 5 | 0.5 |
| 0.53 | 5 | 0.5 |
| 0.68 | 5 | 0.5 |
| 0.81 | 5 | 0.5 |
| 11.17 | 1˙˙ | 0.5 |
| 11.59 | 1˙ | 0.5 |
| 42.59 | 1 | 0.5 |
| 61.25 | 1˙ | 0.5 |
| 71.97 | 1˙ | 0.5 |
| 87.50 | 1 | 0.5 |
| 88.26 | 1 | 0.5 |
| 90.44 | 1 | 0.5 |

## Build (B5)

- key check: shift +0 (r=0.89, next -5 r=0.71); B2 guess 0
- pitch shift: +0 semitones (copy)
- alignment: pulse ratio 1 (tracker 67.1 bpm vs hint 68); DTW at 67.1 bpm: path slope 0.97, cost 0.256, melody starts at 0.3 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 1 within 5% of the best): j0 0, first note at 1.88 s, median |grid - DTW| over the first 12 notes 1091 ms (0% within 250 ms; over all notes 808 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 1091/0.666; j0=0.25 1312/0.616; j0=0.5 1534/0.595; j0=0.75 1755/0.561
- best by chroma score (first note s / dtw err ms / score): 1.9 s / 1091 / 0.666; 2.1 s / 1312 / 0.616; 2.3 s / 1534 / 0.595; 2.8 s / 1977 / 0.578; 2.6 s / 1755 / 0.561
- time map: smoothed tracked grid (tracker 67.1 bpm), refine -20 ms
- timing: median onset error 22 ms, p90 52 ms (69/69 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 71%
- tempo: tempo map (beatTimes), bpm 67.7; max line residual 282 ms
- game cut: 0.00–90.58 s of the shifted file (natural ending), 91 s long, pad 0.31 s
- offset 0.000 s (m4a lag +0.0 ms), m4a 1.45 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 21.4.00 `2` chroma 0.02, onset error 21 ms
- bar 20.4.00 `6` chroma 0.06, onset error 38 ms
- bar 11.4.00 `2` chroma 0.10, onset error 31 ms
- bar 21.1.00 `5` chroma 0.11, onset error 37 ms
- bar 2.3.00 `3` chroma 0.12, onset error 5 ms
- bar 21.2.00 `3` chroma 0.13, onset error 40 ms
- bar 5.4.00 `1` chroma 0.14, onset error 35 ms
- bar 3.4.00 `6` chroma 0.14, onset error 8 ms
- bar 4.4.00 `5` chroma 0.14, onset error 25 ms
- bar 9.4.00 `6` chroma 0.15, onset error 23 ms
