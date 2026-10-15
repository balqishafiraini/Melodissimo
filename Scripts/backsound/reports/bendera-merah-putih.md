# Bendera Merah Putih — analysis (B2)

- master: `work/songs/07_bendera-merah-putih.wav`, 146.5 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | F major | 0.756 | F |
| 2 | F minor | 0.665 | G# |
| 3 | C major | 0.551 | C |

**Suggested shift:** -5 semitones (do F → C)

## Tempo

- beat_track: **132.5 bpm** (half 66.3, double 265.0)
- stability: max deviation 53 ms at 0.5 s (of 146 s)
- beats tracked: 313

## Draft melody (pyin, shifted so do = C)

- notes: 0, range - … -
- similarity to the app melody: n/a (new song)

```
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|

## Build (B5)

- key check: shift -5 (r=0.61, next +2 r=0.46); B2 guess -5
- pitch shift: -5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 132.5 bpm vs hint 132); DTW at 132.5 bpm: path slope 0.76, cost 0.321, melody starts at 46.9 s
- grid pick (chroma score among 8 candidates that agree with DTW; earliest of 2 near-equal): j0 93, first note at 43.47 s, median |grid - DTW| over the first 12 notes 2760 ms (0% within 250 ms; over all notes 268 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 45154/0.456; j0=0.25 45040/0.421; j0=0.5 44925/0.432; j0=0.75 44811/0.440
- best by chroma score (first note s / dtw err ms / score): 109.1 s / 62903 / 0.752; 43.4 s / 2760 / 0.739; 109.2 s / 63017 / 0.739; 43.6 s / 2646 / 0.730; 79.9 s / 33717 / 0.723; 109.3 s / 63130 / 0.698
- time map: smoothed tracked grid (tracker 132.5 bpm), refine +30 ms
- timing: median onset error 29 ms, p90 80 ms (47/47 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 86%
- tempo: steady, bpm 131.6; max line residual 8 ms
- game cut: 38.45–66.86 s of the shifted file (fade-out 2.0 s), 28 s long, pad 0.00 s
- offset 3.645 s (m4a lag +0.0 ms), m4a 0.45 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 9.2.50 `2` chroma 0.23, onset error 29 ms
- bar 3.4.75 `6` chroma 0.25, onset error 80 ms
- bar 6.4.75 `2` chroma 0.25, onset error 74 ms
- bar 7.4.75 `3` chroma 0.37, onset error 74 ms
- bar 7.4.00 `2` chroma 0.38, onset error 23 ms
- bar 6.4.00 `1` chroma 0.58, onset error 34 ms
- bar 11.4.00 `2` chroma 0.58, onset error 30 ms
- bar 8.1.00 `2` chroma 0.58, onset error 26 ms
- bar 1.1.00 `3` chroma 0.60, onset error 23 ms
- bar 5.1.00 `6` chroma 0.62, onset error 14 ms
