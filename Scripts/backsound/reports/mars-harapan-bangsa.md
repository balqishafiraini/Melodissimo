# Mars Harapan Bangsa — analysis (B2)

- master: `work/songs/08_mars-harapan-bangsa.wav`, 205.7 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | A# minor | 0.620 | C# |
| 2 | A# major | 0.579 | A# |
| 3 | F major | 0.534 | F |

**Suggested shift:** -1 semitones (do C# → C)

## Tempo

- beat_track: **132.5 bpm** (half 66.3, double 265.0)
- stability: max deviation 29 ms at 152.9 s (of 206 s)
- beats tracked: 440

## Draft melody (pyin, shifted so do = C)

- notes: 0, range - … -
- similarity to the app melody: n/a (new song)

```
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|

## Build (B5)

- key check: shift +2 (r=0.47, next +4 r=0.44); B2 guess -1
- pitch shift: +2 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 132.5 bpm vs hint 132); DTW at 132.5 bpm: path slope 0.70, cost 0.366, melody starts at 56.2 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 2 within 5% of the best): j0 145, first note at 65.79 s, median |grid - DTW| over the first 12 notes 10595 ms (0% within 250 ms; over all notes 14600 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 55517/0.494; j0=0.25 55403/0.471; j0=0.5 55288/0.489; j0=0.75 55174/0.497
- best by chroma score (first note s / dtw err ms / score): 160.6 s / 105426 / 0.732; 65.8 s / 10595 / 0.729; 124.1 s / 68951 / 0.671; 109.5 s / 54368 / 0.665; 65.9 s / 10709 / 0.652; 14.7 s / 40462 / 0.649
- time map: smoothed tracked grid (tracker 132.5 bpm), refine +20 ms
- timing: median onset error 20 ms, p90 48 ms (66/66 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 68%
- tempo: steady, bpm 131.6; max line residual 8 ms
- game cut: 63.96–96.46 s of the shifted file (fade-out 2.0 s), 33 s long, pad 0.00 s
- offset 1.826 s (m4a lag +0.0 ms), m4a 0.52 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 29.1.00 `5` chroma 0.14, onset error 13 ms
- bar 23.1.75 `1˙` chroma 0.18, onset error 52 ms
- bar 29.2.75 `3` chroma 0.23, onset error 79 ms
- bar 27.2.00 `7` chroma 0.25, onset error 18 ms
- bar 28.2.00 `3` chroma 0.26, onset error 23 ms
- bar 26.2.00 `1˙` chroma 0.33, onset error 20 ms
- bar 27.2.50 `6` chroma 0.33, onset error 44 ms
- bar 25.2.00 `7` chroma 0.33, onset error 22 ms
- bar 11.1.00 `7` chroma 0.37, onset error 16 ms
- bar 22.1.00 `1˙` chroma 0.42, onset error 14 ms
