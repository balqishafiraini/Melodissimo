# Indonesia Raya — analysis (B2)

- master: `work/songs/01_indonesia-raya.wav`, 101.5 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | G major | 0.931 | G |
| 2 | D major | 0.596 | D |
| 3 | C major | 0.543 | C |

**Suggested shift:** +5 semitones (do G → C)

## Tempo

- beat_track: **97.5 bpm** (half 48.8, double 195.0)
- stability: max deviation 408 ms at 97.3 s (of 102 s)
- beats tracked: 159

## Draft melody (pyin, shifted so do = C)

- notes: 1, range 2 … 2
- similarity to the app melody: 0.01

```
2(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 9.94 | 2 | 0.5 |

## Build (B5)

- key check: shift +5 (r=0.86, next +0 r=0.58); B2 guess 5
- pitch shift: +5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 97.5 bpm vs hint 100); DTW at 97.5 bpm: path slope 0.72, cost 0.317, melody starts at 4.8 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 2 within 5% of the best): j0 14, first note at 9.93 s, median |grid - DTW| over the first 12 notes 5413 ms (0% within 250 ms; over all notes 14456 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 3171/0.512; j0=0.25 3019/0.474; j0=0.5 2865/0.455; j0=0.75 2712/0.458
- best by chroma score (first note s / dtw err ms / score): 9.9 s / 5413 / 0.603; 10.1 s / 5566 / 0.576; 30.9 s / 26340 / 0.560; 19.8 s / 15258 / 0.557; 10.5 s / 6022 / 0.555; 9.8 s / 5261 / 0.555
- time map: smoothed tracked grid (tracker 97.5 bpm), refine +20 ms
- timing: median onset error 29 ms, p90 67 ms (106/106 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 46%
- tempo: tempo map (beatTimes), bpm 97.2; max line residual 180 ms
- game cut: 3.23–71.91 s of the shifted file (fade-out 2.0 s), 69 s long, pad 0.00 s
- offset 4.862 s (m4a lag +0.0 ms), m4a 1.13 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 13.4.00 `2˙` chroma 0.02, onset error 100 ms
- bar 15.2.00 `4˙` chroma 0.04, onset error 56 ms
- bar 12.3.00 `6` chroma 0.04, onset error 21 ms
- bar 12.2.50 `6` chroma 0.04, onset error 4 ms
- bar 6.2.00 `6` chroma 0.05, onset error 8 ms
- bar 11.1.00 `6` chroma 0.06, onset error 35 ms
- bar 5.2.00 `2˙` chroma 0.06, onset error 16 ms
- bar 5.3.50 `2˙` chroma 0.07, onset error 89 ms
- bar 4.4.00 `2` chroma 0.07, onset error 26 ms
- bar 15.3.00 `3˙` chroma 0.08, onset error 43 ms
