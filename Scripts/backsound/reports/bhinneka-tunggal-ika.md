# Bhinneka Tunggal Ika — analysis (B2)

- master: `work/songs/10_bhinneka-tunggal-ika.wav`, 222.0 s

## Key (Krumhansl–Schmuckler)

| rank | key | score | do |
|---|---|---|---|
| 1 | A minor | 0.435 | C |
| 2 | E major | 0.392 | E |
| 3 | C# minor | 0.374 | E |

**Suggested shift:** +0 semitones (do C → C)

## Tempo

- beat_track: **126.0 bpm** (half 63.0, double 252.1)
- stability: max deviation 34 ms at 0.1 s (of 222 s)
- beats tracked: 461

## Draft melody (pyin, shifted so do = C)

- notes: 0, range - … -
- similarity to the app melody: n/a (new song)

```
```

### First 30 detected notes

| time (s) | label | beats |
|---|---|---|

## Build (B5)

- key check: shift +3 (r=0.41, next -4 r=0.29); B2 guess 0
- pitch shift: +3 semitones (rubberband -3)
- alignment: pulse ratio 1 (tracker 126.0 bpm vs hint 110); DTW at 126.0 bpm: path slope 0.56, cost 0.364, melody starts at 4.6 s
- grid pick (chroma score alone (DTW did not settle it); earliest of 21 within 5% of the best): j0 6, first note at 3.91 s, median |grid - DTW| over the first 12 notes 527 ms (17% within 250 ms; over all notes 2733 ms)
- top grid candidates (dtw err ms / chroma score): j0=0 3282/0.471; j0=0.25 3164/0.428; j0=0.5 3046/0.454; j0=0.75 2929/0.426
- best by chroma score (first note s / dtw err ms / score): 13.3 s / 8944 / 0.521; 107.8 s / 103487 / 0.515; 119.8 s / 115477 / 0.515; 149.2 s / 144878 / 0.514; 24.6 s / 20235 / 0.511; 12.8 s / 8474 / 0.510
- time map: smoothed tracked grid (tracker 126.0 bpm), refine +30 ms
- timing: median onset error 29 ms, p90 35 ms (50/50 notes within 150 ms of an onset)
- melody-chroma agreement (duration weighted, notes with chroma >= 0.6): 28%
- tempo: steady, bpm 127.6; max line residual 4 ms
- game cut: 0.00–28.46 s of the shifted file (fade-out 2.0 s), 28 s long, pad 0.00 s
- offset 2.499 s (m4a lag +0.0 ms), m4a 0.47 MB, chart valid: True

Weakest 10 notes by chroma (bar.beat, expected):

- bar 4.4.00 `3` chroma 0.05, onset error 35 ms
- bar 5.2.00 `3` chroma 0.06, onset error 26 ms
- bar 7.2.50 `3` chroma 0.07, onset error 22 ms
- bar 5.4.50 `3` chroma 0.07, onset error 51 ms
- bar 4.3.00 `4` chroma 0.08, onset error 29 ms
- bar 7.1.00 `4` chroma 0.08, onset error 27 ms
- bar 3.3.50 `3` chroma 0.09, onset error 34 ms
- bar 1.3.00 `6.` chroma 0.09, onset error 27 ms
- bar 4.4.50 `4` chroma 0.10, onset error 31 ms
- bar 11.1.00 `3` chroma 0.11, onset error 33 ms
