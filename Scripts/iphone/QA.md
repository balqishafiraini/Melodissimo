# iPhone + iPad QA matrix (IPHONE_PLAN.md)

Tick a box when the screen has been **looked at** on that device: nothing clipped or overlapping, no truncated text, every tap target ≥ 44 pt, content inside the safe area. The iPad columns also mean "identical to `shots/ipad-baseline`".

Simulator columns are filled by the executor; the two `real` columns are yours.

## How to capture

```bash
export DD=/tmp/melodissimo-dd
Scripts/iphone/build_install.sh <udid> [<udid> ...]      # one build, installed on each device
SEED=1 Scripts/iphone/capture_all.sh Scripts/iphone/shots/<run>   # every screen on all 6 devices, in parallel
SEED=1 DEVICES="se 15pro" Scripts/iphone/capture_all.sh Scripts/iphone/shots/<run> stageListen settings
```
`SEED=1` fills a mid-game profile (chapter 3, 40 stars, 500 coins). Leave it out to capture whatever the simulator holds. `LANG_ID=1` renders Indonesian. Screenshots land in `Scripts/iphone/shots/` (git-ignored). Devices and UDIDs are in `devices.txt`. The hooks are DEBUG-only: see `Views/Common/QARoutes.swift`.

## Screens

| screen (`-qaRoute` name) | SE | 15 Pro | 17 Pro Max | iPad mini | iPad Air | iPad Pro 13 | real iPhone | real iPad |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `dashboard` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `freePlay` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `learnHub` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `campaignMap` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `shop` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `settings` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `achievements` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `help` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `notationLearn` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `songRepositoryLearn` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `songRepositoryQuiz` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `notationLevelMenu` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `postplay` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `chartRecorder` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `songLearn` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stageSetup` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stageListen` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stagePractice` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stagePerform` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stageBoss` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `stageSolemn` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `battle` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `battleBoss` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `echo` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `rush` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `classic` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `result3` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `result0` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-first` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-tutorial` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-preplay` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-preplayScore` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-onboardPostplay` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-postplay` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `onboard-postplayScore` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `overlay-story` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `overlay-storyBoss` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| `overlay-certificate` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

## Hands-on checklist (real devices; I11 fills the results)

- [ ] Install on a real iPhone (Xcode → the iPhone as run destination; free provisioning is fine) and on a real iPad.
- [ ] Play 2 songs in **Perform** with real fingers. Are the keys big enough for a child? Is the timing OK? (Adjust the audio offset in Settings if needed.)
- [ ] **Real pianika mode** near the iPhone's bottom microphone, in a quiet room. Mic calibration screen included.
- [ ] Backing track volume through the iPhone loudspeaker, and with headphones.
- [ ] Rotate the phone both ways (Landscape Left / Right). The Dynamic Island side must never cover a button.
- [ ] First-run flow on a fresh install: Splash → Hello → Tutorial → Pre-play test → score → Home.
- [ ] Indonesian language (Settings → General → Language): long Indonesian strings must fit on the iPhone.
- [ ] Launch time: the splash should appear within about two seconds of tapping the icon.
