# iPhone + iPad QA matrix (IPHONE_PLAN.md)

☑ = looked at on that simulator (14–15 Oct 2026, final build): nothing clipped or overlapping, no truncated text, tap targets ≥ 44 pt, content inside the safe area. On the iPad columns it also means "matches `shots/ipad-baseline` apart from animation noise" (see IPHONE_PLAN §8, I11). ☐ = not done yet; the two `real` columns are yours.

## How to capture

```bash
export DD=/tmp/melodissimo-dd
Scripts/iphone/build_install.sh <udid> [<udid> ...]      # one build, installed on each device
SEED=1 Scripts/iphone/capture_all.sh Scripts/iphone/shots/<run>   # every screen on all 6 devices, in parallel (~15 min)
SEED=1 DEVICES="se 15pro" Scripts/iphone/capture_all.sh Scripts/iphone/shots/<run> stageListen settings
SEED=1 LANG_ID=1 DEVICES="se" Scripts/iphone/capture_all.sh Scripts/iphone/shots/id dashboard shop     # Indonesian
Scripts/iphone/capture_all.sh Scripts/iphone/shots/<run> coach-0 coach-1 coach-2   # without SEED: a fresh profile
swiftc -O Scripts/iphone/imgdiff.swift -o /tmp/imgdiff && Scripts/iphone/compare.sh <baselineDir> <newDir>
```
`SEED=1` fills a mid-game profile (chapter 3, 40 stars, 500 coins). `LANG_ID=1` renders Indonesian. Screenshots land in `Scripts/iphone/shots/` (git-ignored). Devices and UDIDs are in `devices.txt`. The hooks are DEBUG-only: see `Views/Common/QARoutes.swift`. Install the microphone permission first on a fresh simulator (`xcrun simctl privacy <udid> grant microphone com.balqishafiraini.Melodissimo`), or its dialog covers the calibration screens.

## Screens

| screen (capture name) | SE | 15 Pro | 17 Pro Max | iPad mini | iPad Air | iPad Pro 13 | real iPhone | real iPad |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `dashboard` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `freePlay` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `learnHub` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `campaignMap` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `shop` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `settings` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `achievements` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `help` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `notationLearn` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `songRepositoryLearn` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `songRepositoryQuiz` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `notationLevelMenu` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `postplay` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `chartRecorder` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `songLearn` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stageSetup` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stageListen` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stagePractice` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stagePerform` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stageBoss` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `stageSolemn` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `battle` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `battleBoss` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `echo` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `rush` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `classic` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `result3` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `result0` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-first` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-tutorial` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-preplay` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-preplayScore` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-onboardPostplay` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-postplay` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `onboard-postplayScore` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `overlay-story` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `overlay-storyBoss` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `overlay-certificate` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `overlay-stageSheet` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `overlay-stageSheetBoss` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `cover-calibration` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `cover-micCalibration` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `coach-0` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `coach-1` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |
| `coach-2` | ☑ | ☑ | ☑ | ☑ | ☑ | ☑ | ☐ | ☐ |

Indonesian (`LANG_ID=1`), SE and 15 Pro: dashboard, freePlay, learnHub, settings, shop, stageSetup, result3, onboard-first, onboard-onboardPostplay, onboard-preplayScore, onboard-tutorial, overlay-story, overlay-stageSheet, help, achievements, campaignMap, both calibrations: ☑ (two clippings found and fixed: the "Kecepatan" label in stage setup, and captions in Settings on SE).

## Hands-on checklist (real devices)

- [ ] Install on a real iPhone (Xcode → the iPhone as run destination; free provisioning is fine) and on a real iPad.
- [ ] Play 2 songs in **Perform** with real fingers. Are the keys big enough for a child? On an iPhone SE the white keys are ≈ 32 pt wide, on a 15 Pro ≈ 35 pt. Is the timing OK? (Adjust the audio offset in Settings if needed.)
- [ ] **Real pianika mode** near the iPhone's bottom microphone, in a quiet room. Mic calibration screen included.
- [ ] Backing track volume through the iPhone loudspeaker, and with headphones.
- [ ] Rotate the phone both ways (Landscape Left / Right). The Dynamic Island side must never cover a button. (Simulators were checked in both orientations: the capture script found each one.)
- [ ] First-run flow on a fresh install: Splash → Hello → Tutorial → Pre-play test → score → Home → first stage with its coach bubbles.
- [ ] Learn → Skill Test → ten questions → score → Menu (the iPhone has its own screen for this, `PhoneSkillTestView`).
- [ ] Indonesian language (Settings → General → Language): long strings on SE-size screens.
- [ ] Launch time: the splash should appear within about two seconds of tapping the icon.
- [ ] The certificate's Share sheet on an iPhone (the shared picture must be 1760 × 1120 px).
- [ ] The achievement banner and the share sheet on a phone (not reachable in the simulator without a play-through).
