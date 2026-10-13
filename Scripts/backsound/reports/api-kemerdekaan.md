# Api Kemerdekaan — analysis (B2)

- master: `work/songs/11_api-kemerdekaan.wav`, 195.3 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | F minor | 0.691 | G# |
| 2 | F major | 0.653 | F |
| 3 | C major | 0.479 | C |

**Suggested shift:** +4 semitones (do G# → C)

## Tempo

- beat_track: **129.2 bpm** (half 64.6, double 258.4)
- stability: max deviation 44 ms at 190.0 s (of 195 s)
- beats tracked: 410

## Draft melody (pyin, shifted so do = C)

- notes: 2, range 3 … 3˙
- similarity to the app melody: n/a (new song)

```
3(0.5) 3˙(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 0.10 | 3 | 0.5 |
| 78.74 | 3˙ | 0.5 |

## Build (B5)

- key check: shift -5 (r=0.63, next +2 r=0.35); B2 guess 4
- pitch shift: -5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 129.2 bpm vs hint 129); DTW at 129.2 bpm: path slope 0.76, cost 0.276, melody starts at 83.9 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 1 within 5% of the best): j0 166, first note at 78.51 s, median |grid - DTW| over the first 12 notes 3950 ms (0% within 250 ms; over all notes 680 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 81385/0.495; j0=0.25 81269/0.446; j0=0.5 81152/0.431; j0=0.75 81036/0.415
- best by chroma score (first note s / dtw err ms / score): 78.5 s / 3950 / 0.779; 110.2 s / 27785 / 0.709; 16.9 s / 65518 / 0.685; 93.4 s / 10990 / 0.684; 78.6 s / 3833 / 0.661; 78.4 s / 4067 / 0.649
- time map: smoothed tracked grid (tracker 129.2 bpm), refine +20 ms
- timing: median onset error 20 ms, p90 33 ms (56/56 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 74%
- tempo: steady, bpm 128.6; max line residual 7 ms
- game cut: 73.41–110.34 s of the shifted file (fade-out 2.0 s), 37 s long, pad 0.00 s
- offset 3.695 s (m4a lag +0.0 ms), m4a 0.59 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 5.3.00 `6` chroma 0.11, onset error 19 ms
- bar 7.2.00 `2` chroma 0.12, onset error 13 ms
- bar 7.4.50 `6.` chroma 0.21, onset error 39 ms
- bar 3.2.00 `5` chroma 0.31, onset error 19 ms
- bar 3.4.50 `6` chroma 0.32, onset error 37 ms
- bar 6.1.00 `2` chroma 0.32, onset error 20 ms
- bar 2.1.00 `3` chroma 0.32, onset error 12 ms
- bar 3.3.00 `4#` chroma 0.34, onset error 10 ms
- bar 4.2.00 `3` chroma 0.39, onset error 19 ms
- bar 5.4.00 `3` chroma 0.43, onset error 20 ms
