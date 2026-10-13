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

- key check: shift +2 (r=0.26, next +4 r=0.15); B2 guess -3
- pitch shift: +2 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 126.0 bpm vs hint 126); DTW at 126.0 bpm: path slope 0.54, cost 0.364, melody starts at 38.0 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 19 within 5% of the best): j0 8, first note at 5.08 s, median |grid - DTW| over the first 12 notes 32639 ms (0% within 250 ms; over all notes 26520 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 36496/0.460; j0=0.25 36377/0.414; j0=0.5 36258/0.415; j0=0.75 36139/0.385
- best by chroma score (first note s / dtw err ms / score): 49.4 s / 11666 / 0.505; 88.9 s / 51169 / 0.502; 85.5 s / 47798 / 0.497; 80.7 s / 42979 / 0.497; 87.9 s / 50206 / 0.496; 72.5 s / 34787 / 0.495
- time map: smoothed tracked grid (tracker 126.0 bpm), refine +10 ms
- timing: median onset error 11 ms, p90 97 ms (66/67 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 23%
- tempo: steady, bpm 124.6; max line residual 16 ms
- game cut: 0.11–37.41 s of the shifted file (fade-out 2.0 s), 37 s long, pad 0.00 s
- offset 3.534 s (m4a lag +0.0 ms), m4a 0.61 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 7.2.00 `1` chroma 0.05, onset error 3 ms
- bar 10.4.75 `5.` chroma 0.07, onset error 24 ms
- bar 3.1.00 `5.` chroma 0.07, onset error 13 ms
- bar 15.3.00 `3` chroma 0.08, onset error 10 ms
- bar 10.3.00 `5.` chroma 0.08, onset error 19 ms
- bar 14.3.75 `5.` chroma 0.09, onset error 125 ms
- bar 13.1.00 `5` chroma 0.15, onset error 1 ms
- bar 10.4.00 `5.` chroma 0.17, onset error 12 ms
- bar 8.4.00 `5.` chroma 0.17, onset error 7 ms
- bar 8.1.00 `5.` chroma 0.17, onset error 12 ms
