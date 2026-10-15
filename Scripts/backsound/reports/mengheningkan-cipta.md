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
- alignment: 68 tapped notes (tap tool (by ear)); first note at 0.06 s
- time map: note taps (68 used, 50 snapped to an onset within 40 ms)
- timing: median onset error 0 ms, p90 62 ms (69/69 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 94%
- tempo: tempo map (beatTimes), bpm 66.3; max line residual 1718 ms
- game cut: 0.00–90.58 s of the shifted file (natural ending), 91 s long, pad 2.66 s
- offset 0.000 s (m4a lag +0.0 ms), m4a 1.48 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 11.4.00 `2` chroma 0.06, onset error 0 ms
- bar 2.3.00 `3` chroma 0.08, onset error 0 ms
- bar 10.3.00 `3` chroma 0.46, onset error 0 ms
- bar 14.4.00 `1˙` chroma 0.50, onset error 70 ms
- bar 11.2.00 `2` chroma 0.50, onset error 0 ms
- bar 21.2.00 `3` chroma 0.57, onset error 58 ms
- bar 19.1.00 `3˙` chroma 0.67, onset error 0 ms
- bar 21.4.00 `2` chroma 0.70, onset error 43 ms
- bar 4.4.00 `5` chroma 0.70, onset error 0 ms
- bar 11.1.00 `3` chroma 0.72, onset error 0 ms
