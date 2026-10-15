# Bagimu Negeri — analysis (B2)

- master: `work/songs/02_bagimu-negeri.wav`, 70.6 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | A# major | 0.898 | A# |
| 2 | F major | 0.830 | F |
| 3 | D minor | 0.726 | F |

**Suggested shift:** +2 semitones (do A# → C)

## Tempo

- beat_track: **147.7 bpm** (half 73.8, double 295.3)
- stability: max deviation 128 ms at 64.3 s (of 71 s)
- beats tracked: 163

## Draft melody (pyin, shifted so do = C)

- notes: 3, range 5 … 1˙
- similarity to the app melody: n/a (new song)

```
5(0.5) 1˙(1.5) 5(0.5)
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|
| 2.67 | 5 | 0.5 |
| 5.17 | 1˙ | 1.5 |
| 15.72 | 5 | 0.5 |

## Build (B5)

- key check: shift +2 (r=0.88, next -5 r=0.64); B2 guess 2
- pitch shift: +2 semitones (rubberband -3)
- alignment: 41 tapped notes (tap tool (by ear)); first note at 14.92 s
- time map: note taps (41 used, 26 snapped to an onset within 40 ms)
- timing: median onset error 0 ms, p90 65 ms (42/42 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 86%
- tempo: tempo map (beatTimes), bpm 37.6; max line residual 2221 ms
- game cut: 3.22–70.58 s of the shifted file (natural ending), 67 s long, pad 0.00 s
- offset 11.703 s (m4a lag +0.0 ms), m4a 1.08 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 8.2.00 `3` chroma 0.35, onset error 0 ms
- bar 8.3.00 `2` chroma 0.36, onset error 0 ms
- bar 4.2.75 `3` chroma 0.41, onset error 0 ms
- bar 6.2.75 `2˙` chroma 0.51, onset error 63 ms
- bar 3.3.00 `3` chroma 0.57, onset error 0 ms
- bar 5.4.00 `3` chroma 0.60, onset error 40 ms
- bar 7.1.00 `4` chroma 0.69, onset error 0 ms
- bar 7.3.00 `3` chroma 0.69, onset error 0 ms
- bar 8.1.33 `3` chroma 0.72, onset error 70 ms
- bar 3.2.75 `5` chroma 0.79, onset error 0 ms
