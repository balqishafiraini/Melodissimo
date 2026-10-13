# Garuda Pancasila — analysis (B2)

- master: `work/songs/04_garuda-pancasila.wav`, 158.9 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | F major | 0.853 | F |
| 2 | C major | 0.766 | C |
| 3 | F minor | 0.639 | G# |

**Suggested shift:** -5 semitones (do F → C)

## Tempo

- beat_track: **129.2 bpm** (half 64.6, double 258.4)
- stability: max deviation 163 ms at 0.1 s (of 159 s)
- beats tracked: 333

## Draft melody (pyin, shifted so do = C)

- notes: 1, range 1˙ … 1˙
- similarity to the app melody: 0.01

```
1˙(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 0.07 | 1˙ | 0.5 |

## Build (B5)

- key check: shift -5 (r=0.90, next +0 r=0.72); B2 guess -5
- pitch shift: -5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 129.2 bpm vs hint 129); DTW at 129.2 bpm: path slope 0.85, cost 0.205, melody starts at 48.2 s
- grid pick (chroma score among 9 candidates that agree with DTW; earliest of 1 near-equal): j0 102, first note at 48.57 s, median |grid - DTW| over the first 12 notes 72 ms (92% within 250 ms; over all notes 59 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 47442/0.488; j0=0.25 47326/0.478; j0=0.5 47210/0.507; j0=0.75 47093/0.473
- best by chroma score (first note s / dtw err ms / score): 48.6 s / 72 / 0.877; 7.7 s / 40943 / 0.858; 115.4 s / 66810 / 0.843; 48.7 s / 80 / 0.776; 7.8 s / 40826 / 0.773; 7.6 s / 41059 / 0.763
- time map: smoothed tracked grid (tracker 129.2 bpm), refine -0 ms
- timing: median onset error 5 ms, p90 34 ms (72/72 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 98%
- tempo: steady, bpm 129.2; max line residual 5 ms
- game cut: 43.46–83.51 s of the shifted file (fade-out 2.0 s), 40 s long, pad 0.00 s
- offset 3.717 s (m4a lag +0.0 ms), m4a 0.64 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 15.2.00 `6.` chroma 0.10, onset error 1 ms
- bar 16.3.00 `2` chroma 0.16, onset error 48 ms
- bar 16.3.50 `3` chroma 0.60, onset error 14 ms
- bar 15.2.75 `5.` chroma 0.63, onset error 37 ms
- bar 14.4.00 `1` chroma 0.65, onset error 0 ms
- bar 15.3.00 `1` chroma 0.65, onset error 2 ms
- bar 17.4.00 `7.` chroma 0.80, onset error 2 ms
- bar 10.4.00 `1` chroma 0.86, onset error 9 ms
- bar 9.2.75 `1` chroma 0.87, onset error 51 ms
- bar 9.3.00 `4` chroma 0.87, onset error 5 ms
