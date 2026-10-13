# Bangun Pemudi Pemuda — analysis (B2)

- master: `work/songs/06_bangun-pemudi-pemuda.wav`, 203.0 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | D major | 0.798 | D |
| 2 | B minor | 0.668 | D |
| 3 | G major | 0.666 | G |

**Suggested shift:** -2 semitones (do D → C)

## Tempo

- beat_track: **117.5 bpm** (half 58.7, double 234.9)
- stability: max deviation 360 ms at 201.2 s (of 203 s)
- beats tracked: 390

## Draft melody (pyin, shifted so do = C)

- notes: 2, range 4 … 4˙
- similarity to the app melody: n/a (new song)

```
4˙(0.5) 4(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 191.11 | 4˙ | 0.5 |
| 199.76 | 4 | 0.5 |

## Build (B5)

- key check: shift +5 (r=0.73, next -2 r=0.45); B2 guess -2
- pitch shift: +5 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 117.5 bpm vs hint 118); DTW at 117.5 bpm: path slope 0.97, cost 0.258, melody starts at 55.1 s
- grid pick (chroma score among 7 candidates that agree with DTW; earliest of 1 near-equal): j0 108, first note at 55.10 s, median |grid - DTW| over the first 12 notes 70 ms (100% within 250 ms; over all notes 54 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 55657/0.456; j0=0.25 55537/0.424; j0=0.5 55415/0.408; j0=0.75 55291/0.403
- best by chroma score (first note s / dtw err ms / score): 150.2 s / 95026 / 0.822; 55.1 s / 70 / 0.817; 104.7 s / 49626 / 0.804; 9.6 s / 45447 / 0.800; 55.0 s / 168 / 0.703; 150.0 s / 94898 / 0.702
- time map: smoothed tracked grid (tracker 117.5 bpm), refine -0 ms
- timing: median onset error 21 ms, p90 67 ms (42/42 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 93%
- tempo: tempo map (beatTimes), bpm 117.5; max line residual 73 ms
- game cut: 50.97–80.95 s of the shifted file (fade-out 2.0 s), 30 s long, pad 0.00 s
- offset 4.133 s (m4a lag +0.0 ms), m4a 0.50 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 3.4.50 `6` chroma 0.16, onset error 64 ms
- bar 11.2.00 `3˙` chroma 0.42, onset error 25 ms
- bar 11.1.00 `3˙` chroma 0.45, onset error 1 ms
- bar 5.2.75 `4` chroma 0.49, onset error 25 ms
- bar 5.2.00 `3` chroma 0.55, onset error 14 ms
- bar 3.3.50 `1˙` chroma 0.60, onset error 17 ms
- bar 10.2.50 `3˙` chroma 0.63, onset error 85 ms
- bar 11.4.00 `3˙` chroma 0.65, onset error 40 ms
- bar 9.4.00 `3˙` chroma 0.73, onset error 0 ms
- bar 9.3.00 `3˙` chroma 0.74, onset error 2 ms
