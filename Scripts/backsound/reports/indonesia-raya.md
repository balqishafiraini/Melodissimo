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

- key check: shift +5 (r=0.86, next +0 r=0.58); B2 guess 5
- pitch shift: +5 semitones (rubberband -3)
- alignment: 106 tapped notes (tap tool (by ear)); first note at 0.21 s
- time map: note taps (106 used, 51 snapped to an onset within 40 ms)
- timing: median onset error 42 ms, p90 84 ms (106/106 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 41%
- tempo: tempo map (beatTimes), bpm 193.1; max line residual 6918 ms
- game cut: 0.00–67.79 s of the shifted file (fade-out 2.0 s), 68 s long, pad 0.68 s
- offset 0.000 s (m4a lag +0.0 ms), m4a 1.13 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 19.1.00 `2˙` chroma 0.03, onset error 0 ms
- bar 9.4.00 `2˙` chroma 0.06, onset error 84 ms
- bar 4.4.75 `3` chroma 0.06, onset error 76 ms
- bar 14.1.00 `5` chroma 0.07, onset error 51 ms
- bar 17.1.00 `6` chroma 0.07, onset error 80 ms
- bar 7.2.00 `6` chroma 0.08, onset error 0 ms
- bar 1.4.00 `2˙` chroma 0.10, onset error 0 ms
- bar 21.1.00 `6` chroma 0.11, onset error 0 ms
- bar 11.4.00 `2˙` chroma 0.12, onset error 56 ms
- bar 11.2.00 `5` chroma 0.12, onset error 81 ms
