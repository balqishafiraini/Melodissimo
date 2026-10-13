# Indonesia Tetap Merdeka — analysis (B2)

- master: `work/songs/09_indonesia-tetap-merdeka.wav`, 192.7 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | F major | 0.736 | F |
| 2 | F minor | 0.622 | G# |
| 3 | C major | 0.566 | C |

**Suggested shift:** -5 semitones (do F → C)

## Tempo

- beat_track: **126.0 bpm** (half 63.0, double 252.1)
- stability: max deviation 53 ms at 1.5 s (of 193 s)
- beats tracked: 395

## Draft melody (pyin, shifted so do = C)

- notes: 10, range 5 … 1˙˙
- similarity to the app melody: 0.11

```
5(0.5) 5(0.5) 5(0.5) 5(0.5) 1˙˙(0.5) 1˙˙(0.5) 5(0.5) 5(0.5)
5(0.5) 1˙˙(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 21.87 | 5 | 0.5 |
| 25.22 | 5 | 0.5 |
| 29.58 | 5 | 0.5 |
| 33.09 | 5 | 0.5 |
| 33.94 | 1˙˙ | 0.5 |
| 34.03 | 1˙˙ | 0.5 |
| 77.75 | 5 | 0.5 |
| 110.23 | 5 | 0.5 |
| 117.84 | 5 | 0.5 |
| 118.83 | 1˙˙ | 0.5 |

## Build (B5)

- key check: shift -5 (r=0.81, next +0 r=0.47); B2 guess -5
- pitch shift: -5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 123.0 bpm vs hint 126); DTW at 123.0 bpm: path slope 0.83, cost 0.260, melody starts at 20.5 s
- grid pick (chroma score among 7 candidates that agree with DTW; earliest of 1 near-equal): j0 41, first note at 20.84 s, median |grid - DTW| over the first 12 notes 217 ms (58% within 250 ms; over all notes 211 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 19965/0.427; j0=0.25 19843/0.403; j0=0.5 19721/0.440; j0=0.75 19599/0.426
- best by chroma score (first note s / dtw err ms / score): 105.6 s / 84554 / 0.790; 20.8 s / 217 / 0.744; 59.3 s / 38319 / 0.739; 144.1 s / 123083 / 0.725; 105.7 s / 84674 / 0.717; 105.8 s / 84794 / 0.698
- time map: smoothed tracked grid (tracker 123.0 bpm), refine +30 ms
- timing: median onset error 27 ms, p90 35 ms (59/59 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 81%
- tempo: steady, bpm 124.5; max line residual 5 ms
- game cut: 15.54–53.65 s of the shifted file (fade-out 2.0 s), 38 s long, pad 0.00 s
- offset 3.852 s (m4a lag +0.0 ms), m4a 0.61 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 12.4.00 `2` chroma 0.04, onset error 25 ms
- bar 5.2.00 `1` chroma 0.10, onset error 24 ms
- bar 1.2.00 `1` chroma 0.11, onset error 21 ms
- bar 1.1.00 `1` chroma 0.12, onset error 27 ms
- bar 8.4.50 `4` chroma 0.12, onset error 30 ms
- bar 8.4.00 `3` chroma 0.16, onset error 44 ms
- bar 10.4.50 `4` chroma 0.18, onset error 35 ms
- bar 5.1.00 `1` chroma 0.20, onset error 19 ms
- bar 15.1.00 `2` chroma 0.23, onset error 21 ms
- bar 15.2.00 `4` chroma 0.28, onset error 14 ms
