# Dari Sabang Sampai Merauke — analysis (B2)

- master: `work/songs/14_dari-sabang-sampai-merauke.wav`, 168.5 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | D# major | 0.351 | D# |
| 2 | G minor | 0.330 | A# |
| 3 | D major | 0.301 | D |

**Suggested shift:** -3 semitones (do D# → C)

## Tempo

- beat_track: **126.0 bpm** (half 63.0, double 252.1)
- stability: max deviation 24 ms at 5.5 s (of 169 s)
- beats tracked: 332

## Draft melody (pyin, shifted so do = C)

- notes: 2, range 1# … 1#
- similarity to the app melody: 0.00

```
1#(2) 1#(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 0.05 | 1# | 2 |
| 0.98 | 1# | 0.5 |

## Build (B5)

- key check: shift +2 (r=0.29, next -3 r=0.18); B2 guess -3
- pitch shift: +2 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 126.0 bpm vs hint 126); DTW at 126.0 bpm: path slope 0.54, cost 0.364, melody starts at 32.7 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 14 within 5% of the best): j0 25, first note at 13.21 s, median |grid - DTW| over the first 12 notes 19151 ms (0% within 250 ms; over all notes 13021 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 31192/0.453; j0=0.25 31072/0.414; j0=0.5 30952/0.460; j0=0.75 30831/0.432
- best by chroma score (first note s / dtw err ms / score): 44.0 s / 11664 / 0.506; 83.6 s / 51169 / 0.505; 80.2 s / 47799 / 0.499; 80.7 s / 48280 / 0.497; 82.6 s / 50207 / 0.495; 60.9 s / 28528 / 0.494
- time map: smoothed tracked grid (tracker 126.0 bpm), refine -20 ms
- timing: median onset error 27 ms, p90 95 ms (66/67 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 23%
- tempo: steady, bpm 124.6; max line residual 7 ms
- game cut: 7.92–45.53 s of the shifted file (fade-out 2.0 s), 38 s long, pad 0.00 s
- offset 3.845 s (m4a lag +0.0 ms), m4a 0.62 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 11.4.00 `2` chroma 0.04, onset error 24 ms
- bar 15.1.00 `5` chroma 0.05, onset error 23 ms
- bar 16.1.00 `1` chroma 0.07, onset error 25 ms
- bar 12.4.00 `3` chroma 0.07, onset error 36 ms
- bar 1.4.00 `3` chroma 0.08, onset error 35 ms
- bar 3.1.00 `5.` chroma 0.09, onset error 32 ms
- bar 13.1.00 `5` chroma 0.09, onset error 32 ms
- bar 8.4.00 `5.` chroma 0.10, onset error 26 ms
- bar 7.3.00 `7.` chroma 0.10, onset error 17 ms
- bar 6.4.00 `6.` chroma 0.10, onset error 23 ms
