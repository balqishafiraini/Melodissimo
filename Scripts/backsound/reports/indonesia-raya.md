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

- key check: shift +5 (r=0.87, next +0 r=0.60); B2 guess 5
- pitch shift: +5 semitones (rubberband -3)
- alignment: 106 tapped notes (tap tool (by ear)); first note at 0.30 s
- time map: note taps (106 used, 46 snapped to an onset within 40 ms)
- timing: median onset error 45 ms, p90 95 ms (105/106 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 62%
- tempo: tempo map (beatTimes), bpm 113.3; max line residual 915 ms
- game cut: 0.00–62.30 s of the shifted file (fade-out 2.0 s), 62 s long, pad 1.29 s
- offset 0.000 s (m4a lag +0.0 ms), m4a 1.05 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 21.1.00 `6` chroma 0.11, onset error 46 ms
- bar 17.1.00 `6` chroma 0.13, onset error 0 ms
- bar 19.4.75 `4˙` chroma 0.18, onset error 146 ms
- bar 23.4.00 `3˙` chroma 0.20, onset error 130 ms
- bar 14.4.75 `6` chroma 0.20, onset error 72 ms
- bar 7.2.00 `6` chroma 0.21, onset error 0 ms
- bar 13.4.00 `2˙` chroma 0.22, onset error 59 ms
- bar 5.3.75 `2˙` chroma 0.22, onset error 94 ms
- bar 5.2.00 `2˙` chroma 0.22, onset error 53 ms
- bar 9.4.75 `2˙` chroma 0.24, onset error 0 ms
