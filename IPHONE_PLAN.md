# Melodissimo — iPhone Plan (iPhone + iPad, one app)

> **Ringkasan (buat Balqis)**
> - Target sekarang udah `iPhone + iPad` (kamu yang ganti). App-nya udah bisa ke-build dan jalan di iPhone, tapi **hampir semua layar rusak**. Semua UI dirancang buat tinggi layar iPad (±820 pt), sedangkan iPhone landscape cuma **±375–440 pt**, kurang dari setengahnya.
> - Yang udah dicek langsung di iPhone 15 Pro Simulator (14 Okt 2026):
>   - **Onboarding pertama** kosong total. Gambar tampil di ukuran asli, jadi pemain baru nggak bisa lanjut.
>   - **Dashboard**: teks kepotong jadi "•••", angka bintang keluar kartu, deretan kartu bawah hilang.
>   - **Settings** meluber ke kiri-kanan.
>   - **Cerita pembuka**: kolom teks kepotong per huruf.
>   - Keyboard pianika tingginya 290–450 pt, padahal layarnya cuma 393 pt.
>   - Dari buka app sampai Dashboard muncul ada **layar putih ±20 detik**.
> - Strateginya: satu helper ukuran (`Sizing`). **Di iPad helper ini mengembalikan angka yang persis sama**, jadi tampilan iPad nggak berubah sama sekali. Di iPhone semua ukuran dikecilin secara proporsional. Layar yang tetap nggak muat (layar main lagu, battle, settings, onboarding) disusun ulang khusus iPhone.
> - Tiap task wajib di-screenshot di **3 iPhone + 3 iPad** dan dibandingin sama screenshot iPad "sebelum" (dibikin di Task I0). Jadi kalau iPad ikut berubah, langsung ketahuan.
> - Bagian kamu: OK-in task yang bertanda ⚠︎, terus coba di iPhone/iPad asli di akhir (`Scripts/iphone/QA.md`). Yang paling penting dicoba: main lagu pakai jari beneran (keyboard iPhone jadi kecil) dan mode mic pianika.
> - Keputusan yang mungkin mau kamu ubah ada di §1.2, terutama **D6** (ukuran keyboard iPhone) dan **D11** (teks share "iPhone & iPad").

This document is written for an AI executor (Claude Sonnet 5.5) working **one task per session**, exactly like `GAME_PLAN.md` and `BACKSOUND_PLAN.md`. It adds **Phase 10 (tasks I0–I11)**.

**Session prompt for the user to paste:**
```
Read GAME_PLAN.md sections 3 and 4, then IPHONE_PLAN.md sections 1–5 fully, then Task I<N>.
Execute Task I<N> only, following the executor rules in both files (IPHONE_PLAN §4 wins where they differ).
For tasks marked ⚠︎, write a short plan first and wait for my OK before coding.
Finish with: build + tests passing, iPhone AND iPad screenshots checked, checkbox ticked, commit, and a list of things I should check by hand.
```

---

## Progress tracker

| Task | Title | Kind | Depends on |
|---|---|---|---|
| I0 | ⚠︎ Prep: commit the target change, QA launcher, screenshot scripts, iPad baseline | setup | — |
| I1 | ⚠︎ Launch delay (white screen ±20 s) | perf | I0 |
| I2 | Foundation: `Sizing`, `screenWidth/Height`, fonts, app icon, "iPad" wording | code | I0 |
| I3 | ⚠︎ Keyboard + Song Stage + Chart Recorder + Calibration (the play surface) | code | I2 |
| I4 | Battle + Echo | code | I3 |
| I5 | ⚠︎ First-run flow: Splash, FirstLaunch, Tutorial, Preplay/Postplay (+ score screens) | code | I3 |
| I6 | Home: Dashboard, Free Play, Learn hub, Achievements, Help, shared components | code | I2 |
| I7 | Campaign: map, nodes, stage sheet, story card, certificate | code | I2 |
| I8 | Stage setup, results, not angka sheet, boss badge | code | I3 |
| I9 | Settings + Shop | code | I3 |
| I10 | Legacy lessons: Notation learn/quiz menu, Song repository learn/quiz, Song learn | code | I3 |
| I11 | Final QA matrix, docs, executor notes | QA | all |

I1 and I2 are independent of each other. After I3, the tasks I4–I10 can run in any order.

- [x] I0  - [x] I1  - [ ] I2  - [ ] I3  - [ ] I4  - [ ] I5  - [ ] I6  - [ ] I7  - [ ] I8  - [ ] I9  - [ ] I10  - [ ] I11

---

## 1. Goal and decisions

### 1.1 Goal
The same app runs well on **every iPhone that runs iOS 16.6+, in landscape**, and still looks and behaves **exactly as it does today on iPad**.

"Runs well" on iPhone means all of the following, on every reachable screen:
- Nothing is clipped, overlapping, or pushed off-screen, and no text is truncated to "…" or "•••" or broken mid-word.
- Every tap target is at least **44×44 pt** (the piano keys are the one exception; see D6).
- Interactive content stays inside the **safe area**: the Dynamic Island/notch side and the home indicator. Backgrounds still fill the whole screen.
- The song stage leaves a usable note highway: **≥ 180 pt tall on iPhone SE**.
- Falling notes still line up with their keys, and the timing and judging are unchanged.
- The microphone (real pianika) mode works on an iPhone: the iPhone mic and loudspeaker, with `.defaultToSpeaker` already set.

### 1.2 Decisions (already made; don't re-litigate)

| # | Decision | Why |
|---|---|---|
| D1 | **One codebase, one target**, `TARGETED_DEVICE_FAMILY = "1,2"`. Landscape only (Left + Right) on both. No portrait. | The user chose this. The whole game (keyboard + highway) is a landscape design. |
| D2 | **iPad must not change.** Every sizing helper returns its input unchanged on iPad (`idiom == .pad`). iPhone-only restructuring is guarded by `Sizing.isPhone`. | The iPad app is finished and verified. This rule makes "iPad still works" checkable: iPad screenshots must match the I0 baseline. |
| D3 | iPhone sizing = **proportional scale** of the existing iPad numbers through `Sizing.s(_:)` (frames, paddings, spacings, corner radii, offsets) and `Sizing.f(_:)` (custom font sizes), plus `Sizing.tap(_:)` for button frames (never below 44 pt). Starting factors are in §3.2. Tune them only in I2 or I3, and record any change in §8. | One mechanical rule covers about 70% of the ~145 fixed numbers. Hand-tuning each screen would drift and be slow. |
| D4 | Screens that still don't fit after scaling get a **phone-only layout** (`if Sizing.isPhone { phoneBody } else { existing body unchanged }`). The existing iPad code path is moved **verbatim**, never rewritten. | Keeps D2 provable by reading the diff. |
| D5 | **Safe area:** backgrounds `.ignoresSafeArea()`, content respects it. On iPhone, top bars and back buttons sit inside the horizontal safe insets (Dynamic Island side ≈ 59 pt). | Content under the island or the rounded corners can't be tapped or read. |
| D6 | **Piano keyboard on iPhone:** all 32 keys always stay (it mirrors a real pianika). Width = the **safe-area width**. White-key width keeps the `0.048 × width` ratio, giving ≈ 32 pt on SE, ≈ 35 pt on 15 Pro and ≈ 40 pt on 17 Pro Max. Heights come from the phone metrics in §3.3. Keys may be narrower than 44 pt. | Fewer keys would break songs and chart lanes. Safe-area width keeps the outer keys out of the rounded corners and the island. |
| D7 | The `UIScreen.main`-based globals stay, but become orientation-proof: `screenWidth = max(bounds.w, bounds.h)` and a new `screenHeight = min(bounds.w, bounds.h)`. All 42 direct `UIScreen.main.bounds` uses in views move to these globals or to `GeometryReader`. | On iPhone, `UIScreen.main.bounds` can be read before the scene rotates and return portrait numbers. On a full-screen landscape iPad, max/min gives the same values as today. |
| D8 | Patterns like `.frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, …)` become `.frame(maxWidth: .infinity, maxHeight: .infinity, …)`. | The two are equal on a full-screen iPad, so the change is safe there. On iPhone the old form overflows past the safe area. |
| D9 | Images used as backgrounds (`bgMusic`, `dashboard`, `splashscreen`, `map_ocean`, `stage_bg_*`) must be `.resizable().scaledToFill()` inside a frame that is clipped. Character art (`alpanica*`, monsters, boss art) is `.resizable().scaledToFit()` with a `Sizing.s` height. **Never an un-sized `Image("…")`.** | The empty first screen on iPhone is caused by an un-sized `Image("bgMusic")` and `Image("alpanica")`. |
| D10 | **Sheets:** on iPhone landscape, detents are ignored and sheets are almost full-height. Every sheet's content must fit 340 pt or scroll. Keep `.presentationDetents([.height(480)])` for iPad only. | `CampaignMapView` uses a 480 pt detent, which is taller than the iPhone screen. |
| D11 | User-facing text stops saying "iPad". Use device-neutral wording ("this device", "your device"), and **update the Indonesian translation of every changed string**. The share text becomes "…on the App Store (iPhone & iPad)". | 5 strings mention the iPad. Localization keys are the English strings themselves, so changing the English also changes the key. |
| D12 | **The certificate image stays a fixed size** (`ImageRenderer` output is identical on every device). Only the on-screen preview is scaled to fit. | A shared certificate should look the same everywhere. |
| D13 | No haptics work in this phase (iPhones have haptics, but adding them is a feature, not a port). Record it as a follow-up idea in §8. | Stay in scope. |
| D14 | **DEBUG-only** QA hooks (§3.5) are allowed in app code. They must compile out of Release (`#if DEBUG`). | Without them, each screenshot needs ~20 s of launch plus taps. |

---

## 2. What we measured (baseline facts, 14 Oct 2026)

Build: `xcodebuild … -destination 'id=<iPhone 15 Pro>' build` → **BUILD SUCCEEDED**, one new warning: `AppIcon.appiconset: A 60x60@2x app icon is required for iPhone apps`.

Seen in the **iPhone 15 Pro** simulator (852 × 393 pt landscape, safe insets ≈ 59 pt left/right, 21 pt bottom):

| Screen | Problem |
|---|---|
| Splash | `splashscreen` is `scaledToFill` from a 4:3 image, so the left and right parts are cropped heavily. Mostly acceptable, but check the logo isn't cut. |
| FirstLaunchView | **Blank.** Only the background and half of the llama are visible. `Image("bgMusic")` and `Image("alpanica")` have no `.resizable()`, the text box is 300 pt tall, the "Next" button is 100 pt, and "?" is 80 pt. Total ≫ 393. **New players are stuck here.** |
| DashboardView | Tour card: the island name and "Up next" collapse to "•••", the leaf badge text is cut ("1a"), "0 / 147" wraps outside the card, and the bottom row of hub cards (Daily / Free Play / Learn) is off-screen. The top bar fits. |
| SettingsView | The content is wider than the screen and clipped on both sides. The caption says "The iPad listens…". |
| StoryCardView (after Start) | The text column is a few characters wide, so words break mid-word ("Merauk-e") and the text runs off the bottom. |
| Launch | **15–25 s of white screen** before the splash, on every launch (cold and warm). The iPad simulator has not been measured yet; that is Task I1. |

From the code:
- **~145 fixed point sizes ≥ 30 pt** across ~40 view files. Most hits: Dashboard 17, ChartRecorder 16, Shop 15, SongStage 12, StageSetup 11, Settings 11, Certificate 11, StageResult 10, CampaignMap 10, Calibration 9, StoryCard 9, Battle 9, Echo 8.
- **42 `UIScreen.main` uses**, mostly in legacy screens (Song/, Notation/, Preplay/, Postplay/, Onboarding/, Help, Dashboard).
- `Data/Extensions/FontExtension.swift` **overrides the system text styles** with fixed BalooDa sizes: `.largeTitle` 50, `.title` 40, `.headline` 30, `.subheadline` 20, `.body` 15. Scaling these 5 numbers fixes most text at once.
- `PianoMetrics` (in `Views/Component/TilesComponentView.swift`): `.full` 450 pt tall (Battle, Echo), `.mini` 300, `.stage` 290 (SongStage, ChartRecorder, both calibrations). Key widths come from the global `screenWidth`. `SongStageView` stacks HUD (72/92) + highway + `.stage` keyboard (290), which leaves **~30 pt of highway on a 393 pt iPhone**.
- `NoteHighwayView` draws lanes from the keyboard's reported `keyFrames` (global coordinates). If the keyboard changes size, the lanes follow automatically. Don't hard-code lanes.
- `CampaignMapView` sheet: `.presentationDetents([.height(480)])`.
- `MapLayout` is normalized (0…1), so the map itself scales. Only node, avatar and label sizes need `Sizing.s`.
- `WhiteTilesStyle` / `BlackTilesStyle` (+ `Mini`) in `ButtonExtension.swift` are **not used anywhere**. Leave them; Task 7.4 cleanup owns them. Don't spend time scaling them.
- Legacy screens are **still reachable**: onboarding → Tutorial → Preplay → PreplayScore → Dashboard. Learn hub → `.notationLearn`, `.songRepositoryLearn` → `.songLearn`, and Skill Test `.postplay`. Plus `.notationLevelMenu` and `.songRepositoryQuiz` (classic levels/songs from Free Play). They must work on iPhone too.
- Audio: `MicrophoneInput` already uses `.playAndRecord` + `.defaultToSpeaker`, which is correct for iPhone.

---

## 3. Technical design

### 3.1 Constraints (override GAME_PLAN §3.1 where they differ)

- Deployment target stays **iOS 16.6**. Forbidden iOS 17+ APIs from GAME_PLAN §3.1 stay forbidden; in particular `.containerRelativeFrame` is **not** available. `ViewThatFits`, `GeometryReader` and SwiftUI's `Layout` protocol are iOS 16 and allowed. **Don't name anything `Layout`** — it would shadow that protocol; the helper is `Sizing`.
- **Platforms: iPhone + iPad, landscape only.** In I0, update GAME_PLAN §3.1's first bullet to: *"Deployment target iOS 16.6, iPhone + iPad, landscape only. On iPad, layouts must stay identical to v2 (see IPHONE_PLAN D2)."*
- No new dependencies.
- `Models/` stays free of SwiftUI/UIKit (GAME_PLAN rule 6). The pure scale math lives in `Models/Layout/LayoutScale.swift` and imports only `CoreGraphics`. The UIKit-reading part lives in `Views/Common/Sizing.swift`.

### 3.2 The `Sizing` helper (Task I2)

`Melodissimo/Models/Layout/LayoutScale.swift` (pure, unit-tested):

```swift
import CoreGraphics

/// Sizing factors for one device class. The views were drawn for an iPad (landscape height ≈ 820 pt);
/// on iPhone every fixed size is scaled down from that, and on iPad every helper returns its input untouched.
struct LayoutScale: Equatable {
    let isPhone: Bool
    /// Multiplies fixed frame sizes, paddings, spacings, corner radii and offsets.
    let size: CGFloat
    /// Multiplies custom font point sizes.
    let font: CGFloat

    static let pad = LayoutScale(isPhone: false, size: 1, font: 1)

    /// `shortSide` is the screen's shorter edge in points (landscape height).
    static func make(isPhone: Bool, shortSide: CGFloat) -> LayoutScale {
        guard isPhone else { return .pad }
        let size = min(max(shortSide / 820, 0.44), 0.56)
        return LayoutScale(isPhone: true, size: size, font: 0.65)
    }

    /// A fixed iPad size, scaled for this device.
    func s(_ value: CGFloat) -> CGFloat { isPhone ? (value * size).rounded() : value }
    /// A custom font size, scaled for this device; never below 13 pt on iPhone.
    func f(_ value: CGFloat) -> CGFloat { isPhone ? max(13, (value * font).rounded()) : value }
    /// A tappable control's side, scaled but never below Apple's 44 pt minimum on iPhone.
    func tap(_ value: CGFloat) -> CGFloat { isPhone ? max(44, s(value)) : value }
}
```

Starting values per device: SE (short side 375) → size 0.457; 15 Pro (393) → 0.479; 17 Pro Max (440) → 0.537; fonts × 0.65 (title 40 → 26, headline 30 → 20, subheadline 20 → 13, body 15 → 13).

`Melodissimo/Views/Common/Sizing.swift`:

```swift
import UIKit

/// The running device's `LayoutScale`. Views call `Sizing.s(220)` where they used to write `220`.
enum Sizing {
    static let current = LayoutScale.make(isPhone: UIDevice.current.userInterfaceIdiom == .phone,
                                          shortSide: screenHeight)
    static var isPhone: Bool { current.isPhone }
    static func s(_ value: CGFloat) -> CGFloat { current.s(value) }
    static func f(_ value: CGFloat) -> CGFloat { current.f(value) }
    static func tap(_ value: CGFloat) -> CGFloat { current.tap(value) }
}
```

`Data/Extensions/ViewExtension.swift` (D7):

```swift
/// The screen's long edge. The app is landscape-only, so this is the landscape width on every device,
/// even if it is read before the window has rotated.
let screenWidth = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
/// The screen's short edge: the landscape height.
let screenHeight = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
```
Also fix the stale comment ("The game runs in portrait") to say landscape.

**How to apply `Sizing` in a view (the mechanical pass):**

| Before | After |
|---|---|
| `.frame(width: 220, height: 18)` | `.frame(width: Sizing.s(220), height: Sizing.s(18))` |
| Button label `.frame(width: 80, height: 80)` | `.frame(width: Sizing.tap(80), height: Sizing.tap(80))` |
| `.padding(40)`, `spacing: 30`, `cornerRadius: 40`, `.offset(y: -120)` | wrap the number in `Sizing.s(…)` |
| `.font(.custom("BalooDa-Regular", size: 64))` | `.font(.custom("BalooDa-Regular", size: Sizing.f(64)))` |
| `.font(.title)` etc. (already custom in FontExtension) | no change; FontExtension scales them |
| `.padding()` (default 16), numbers < 12, line widths, `opacity`, durations | **leave as is** |
| `UIScreen.main.bounds.width * 0.5` | `screenWidth * 0.5`, or better a `GeometryReader` width × 0.5 |
| `UIScreen.main.bounds.height` | `screenHeight` |

Rules of thumb:
- Wrap the number, not the expression. `Sizing.s(150) * fraction` is fine.
- Text that can be long gets `.lineLimit(n)` + `.minimumScaleFactor(0.7)` on iPhone. Add these unconditionally only if they cannot change iPad rendering. A `minimumScaleFactor` only kicks in when text doesn't fit, so on iPad it is a no-op wherever the iPad text fits today, which it does (it's the verified baseline).
- Prefer `.frame(maxWidth: …)` over `.frame(width: …)` for text containers.
- `ScrollView` is the safety net: a phone layout that still overflows 393 pt may scroll vertically, **except** the play screens (Stage, Battle, Echo, Calibration, ChartRecorder), which must fit without scrolling.

### 3.3 Piano keyboard on iPhone (Task I3)

Today `PianoMetrics` reads the global `screenWidth`. Change it so the width is an input:

```swift
struct PianoMetrics {
    let width: CGFloat            // the keyboard's full width
    var whiteWidth: CGFloat { width * 0.048 }
    var blackWidth: CGFloat { width * 0.042 }
    let whiteHeight: CGFloat
    …
}
```
- On **iPad**, `width` is always `screenWidth` and the heights are today's numbers. `.full`, `.mini` and `.stage` must produce **identical** values to today.
- On **iPhone**, `PianoKeyboard` measures its proposed width with a `GeometryReader` (inside the safe area) and builds the metrics with that width. Use the phone heights below. Every `screenWidth` inside `PianoKeyboard` (body frame, `whiteRow`, `blackRow`'s `0.88` and `0.06` factors) must use `metrics.width` instead.

| Variant | Used by | iPad (unchanged) white / black / container | **iPhone** white / black / container |
|---|---|---|---|
| `.full` | Battle, Echo | 350 / 220 / 450 | **150 / 95 / 170** |
| `.mini` | `PianikaStackLearningMini` | 200 / 120 / 300 | **110 / 68 / 125** |
| `.stage` | SongStage, ChartRecorder, Calibration, MicCalibration | 230 / 145 / 290 | **120 / 76 / 136** |

`whiteRowHeight` / `blackRowHeight` follow the same ratios as today (iPad full: row 450/350 for keys 350/220). On phone, use container height for the white row and `blackHeight + (container − whiteHeight)` for the black row. Verify visually that the black keys sit at the top edge of the white keys, as on iPad.

The highway on an iPhone stage then gets: 393 − 21 (home indicator) − HUD 48 − keyboard 136 ≈ **188 pt** on 15 Pro, and ≈ 170 pt on SE. On SE, shrink the HUD to 44 pt to reach ≥ 180 pt.

Check: `HighwayGeometryTests`, `HighwayPerformanceTests` and any test touching `PianoMetrics` must still pass. Add a test asserting that `PianoMetrics.full/.mini/.stage` on the iPad path equal today's numbers with `width = 1366` (literal values).

### 3.4 Sizes to know

| Device (simulator name) | Landscape pt | Safe insets L/R/bottom | `Sizing` size factor |
|---|---|---|---|
| iPhone SE (3rd generation) | 667 × 375 | 0 / 0 / 0 | 0.457 |
| iPhone 15 Pro | 852 × 393 | 59 / 59 / 21 | 0.479 |
| iPhone 17 Pro Max | 956 × 440 | 62 / 62 / 21 | 0.537 |
| iPad mini (A17 Pro) | 1133 × 744 | 0 / 0 / 20 | 1 |
| iPad Air 11-inch (M3) | 1180 × 820 | 0 / 0 / 20 | 1 |
| iPad Pro 13-inch (M5) | 1376 × 1032 | 0 / 0 / 20 | 1 |

Inset values are approximate. Read the real ones from a screenshot before relying on them.

### 3.5 DEBUG QA hooks (Task I0)

`UserDefaults` reads launch arguments as a volatile domain: `-key value` on the command line overrides `UserDefaults.standard` for that launch only and is **never written to disk**. Use this:

- **Skip onboarding:** `-isPreplayDone YES` (the existing key, read by `CoordinatorView`).
- **Skip the splash:** `-qaSkipSplash YES`. In `SplashscreenView`, under `#if DEBUG`, flip `isActive` immediately.
- **Open a screen:** `-qaRoute <name>`. In the view that owns the `NavigationStack` / `AppRouter` (find it from `DashboardView`), under `#if DEBUG`, `.onAppear` reads `UserDefaults.standard.string(forKey: "qaRoute")` once and pushes the matching route(s). Put the name → route mapping in `Views/Common/QARoutes.swift` (whole file `#if DEBUG`):

| name | pushes |
|---|---|
| `freePlay`, `learnHub`, `campaignMap`, `shop`, `settings`, `achievements`, `help`, `notationLearn`, `songRepositoryLearn`, `songRepositoryQuiz`, `notationLevelMenu`, `postplay`, `chartRecorder` | the plain `Route` case |
| `songLearn` | `.songLearn(songTitle:)` with the first song of the library |
| `stageSetup` | `.stageSetup(songId:)` with the first song |
| `stageListen`, `stagePractice`, `stagePerform`, `stageBoss` | `.play(PlayRequest)` for the first song in that mode (boss: a campaign boss stage id) |
| `battle`, `echo`, `rush` | `.play(…)` for that mode (read `PlayRequest`/`StageMode` for the exact cases) |
| `result3`, `result0` | `.result(…)` with a synthetic `PlayResult` (3 stars / 0 stars) and a `RewardSummary` |

- **Open an onboarding screen:** `-qaOnboarding first|tutorial|preplay|preplayScore|onboardPostplay|postplayScore`. `CoordinatorView` shows that view directly (DEBUG only).
- **Seed progress for realistic screens:** progress keys can be passed the same way (e.g. `-coins_earnedTotal 500`). This works only where `ProgressStore` reads `UserDefaults.standard` live. If it caches, add `-qaSeed YES`: under DEBUG, when set, `ProgressStore` uses an **in-memory** `UserDefaults(suiteName: "qa")` pre-filled with a mid-game profile (chapter 3, 40 stars, 500 coins, a few shop items owned). Never touch the real profile.
- **Story card / certificate:** `-qaOverlay story|certificate` makes `CampaignMapView` show that overlay on appear.

### 3.6 Screenshot tooling (Task I0)

`Scripts/iphone/devices.txt`: the 6 simulators from §3.4 with their **UDIDs** (`xcrun simctl list devices available`; several runtimes have the same name, so prefer iOS 18.6/26.1 runtimes and write down the UDID you used).

`Scripts/iphone/shot.sh <udid> <out.png>`: `xcrun simctl io <udid> screenshot`. If the PNG is portrait, rotate it so the home indicator is at the bottom (on 14 Oct `sips -r 270` was right for the iPhone 15 Pro; detect it, don't assume). Then downscale to 1200 px wide.

`Scripts/iphone/capture.sh <udid> <outdir> [names…]`: for each screen name it terminates the app, launches it with `-isPreplayDone YES -qaSkipSplash YES -qaRoute <name>` (or `-qaOnboarding …`), waits until the app is ready, and runs `shot.sh`. **"Ready" means:** poll every 1 s until two consecutive screenshots are identical and not all-white, with a 40 s timeout, or use a fixed `WAIT` env var. Default screen list = every name in §3.5.

Build once per device class:
```bash
xcodebuild -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'id=<udid>' -derivedDataPath /tmp/melodissimo-dd build -quiet
```
```bash
xcrun simctl install <udid> /tmp/melodissimo-dd/Build/Products/Debug-iphonesimulator/Melodissimo.app
```

Output goes to `Scripts/iphone/shots/<device>/<name>.png`. **Add `Scripts/iphone/shots/` to `.gitignore`.** Screenshots are never committed.

**Tapping with the iOS Simulator tool:** its tap coordinates are in the **portrait** frame (e.g. 393 × 852) even when the app is landscape. For a point `(lx, ly)` measured on the rotated landscape screenshot (in pt), tap `(x: W − ly, y: lx)` where `W` is the portrait width (393 on 15 Pro). Verified on 14 Oct: Settings gear at landscape (554, 55) → tap (338, 554). Prefer `-qaRoute` over tapping whenever possible.

---

## 4. Executor rules (in addition to GAME_PLAN §4)

1. **The iPad rule (D2).** Before committing any task, capture the task's screens on **iPad Air 11-inch (M3)** and compare them with `Scripts/iphone/shots/ipad-baseline/`. They must look the same: same positions, sizes, line breaks and colours (animation frames may differ). If anything differs, it's a bug in your change. Fix it, don't explain it away. Also glance at **iPad mini** (smallest iPad) and **iPad Pro 13-inch** for the screens you touched.
2. **The iPhone rule.** Capture the task's screens on **iPhone SE (3rd gen)**, **iPhone 15 Pro** and **iPhone 17 Pro Max**. **Look at every screenshot** (Read the PNG) and check the §1.1 list. SE is the hardest case (smallest), and 15 Pro has the Dynamic Island.
3. Do the iPhone fix in this order: (a) mechanical `Sizing` pass (§3.2), (b) remove `UIScreen.main` and un-sized images, (c) only if it still doesn't fit, a phone-only layout (D4). Never edit the iPad branch's numbers.
4. **Interaction check**, not just screenshots. For each task's screens, tap the main buttons once on iPhone 15 Pro (use the coordinate mapping in §3.6) and make sure they respond and navigate. For play screens, play at least 10 s.
5. **Build + tests** as in GAME_PLAN §4 rule 8, plus an iPhone build:
   ```bash
   xcodebuild -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build -quiet
   ```
   Run the unit tests on **both** an iPad and an iPhone simulator in I2, I3 and I11. In the other tasks, running them on iPad is enough.
6. **Localization:** a changed English string is a new key. Update `Melodissimo/Data/id.lproj/Localizable.strings` (remove the stale line, add the new one) and keep `LocalizationTests` green.
7. **Stay in scope:** only touch the files listed under **Touches** (plus `Sizing`/QA files if needed). Don't redesign visuals, change colours or rename things. Legacy screens get the same treatment as new ones; don't delete them (that's Task 7.4).
8. **Commit:** `git add IPHONE_PLAN.md GAME_PLAN.md Melodissimo Melodissimo.xcodeproj/project.pbxproj MelodissimoTests Scripts/iphone .gitignore` (only what you touched). **Never** stage `xcuserdata` (the user's `xcschememanagement.plist` is modified locally; leave it). Commit message: `Task I<N>: <title>`.
9. Record decisions, deviations, tuned numbers and anything **not verified** in **§8 Executor notes**, in the same style as GAME_PLAN §8.

---

## 5. Screen inventory (who owns what)

| Screen / file | Reached from | Task |
|---|---|---|
| `Views/Component/TilesComponentView.swift` (`PianoKeyboard`, `PianoMetrics`, `PianikaStack*`) | every play screen | I3 |
| `Views/Stage/SongStageView.swift`, `NoteHighwayView.swift`, `ChartRecorderView.swift` | Stage setup → Play; DEBUG long-press on the streak | I3 |
| `Views/Settings/CalibrationView.swift`, `MicCalibrationView.swift` | Settings | I3 |
| `Views/Battle/BattleView.swift`, `MonsterSprite.swift`; `Views/Echo/EchoView.swift` | campaign/free play | I4 |
| `Views/Onboarding/SplashscreenView.swift`, `FirstLaunchView.swift`, `TutorialView.swift`, `CoordinatorView.swift` | first launch | I5 |
| `Views/Preplay/PreplayView.swift`, `PreplayScoreView.swift`; `Views/Postplay/PostplayView.swift`, `PostplayScoreView.swift`, `OnboardPostplayView.swift`; `Views/AfterQuiz/AfterQuizView.swift` | first launch, Learn → Skill Test | I5 |
| `Views/Dashboard/DashboardView.swift`, `Views/FreePlay/FreePlayView.swift`, `Views/Learn/LearnHubView.swift`, `Views/Achievement/AchievementsView.swift`, `Views/Help/*`, `Views/Common/*` (HubCard, PlayDestinationView, CoinBadge, HeartsView, AchievementBanner, CoachMarkOverlay, CharacterMotion, AssetImage, SoundButton) | Home | I6 |
| `Views/Campaign/*` (CampaignMapView, StageNodeView, StageSheetView, StoryCardView, CertificateView) | Home → Tour | I7 |
| `Views/Stage/StageSetupView.swift`, `StageResultView.swift`, `NotAngkaSheetView.swift`, `BossBadgeView.swift` | before/after a song | I8 |
| `Views/Settings/SettingsView.swift`, `Views/Shop/ShopView.swift`, `Skins.swift` | Home | I9 |
| `Views/Notation/*`, `Views/Song/Learn/*`, `Views/Song/Quiz/*` | Learn hub, Free Play classic | I10 |
| `Data/Extensions/FontExtension.swift`, `ViewExtension.swift`, `Assets.xcassets/AppIcon.appiconset` | global | I2 |

If you find a view that is not in this table, add it to the task that owns its parent screen and note it in §8.

---

## 6. Tasks

### Task I0 — ⚠︎ Prep: commit the target change, QA launcher, screenshot scripts, iPad baseline

**Goal:** a clean starting point, plus tools that make every later task's screenshots one command.

**Touches:** `Melodissimo.xcodeproj/project.pbxproj` (already changed by the user), `GAME_PLAN.md` §3.1, `.gitignore`, new `Scripts/iphone/{devices.txt,shot.sh,capture.sh,QA.md}`, new `Views/Common/QARoutes.swift`, small `#if DEBUG` hooks in `CoordinatorView.swift`, `SplashscreenView.swift`, the `NavigationStack` owner (from `DashboardView.swift`), `CampaignMapView.swift`, and maybe `ProgressStore` (only for `-qaSeed`).

Steps:
1. `git status`. The user changed `TARGETED_DEVICE_FAMILY` to `"1,2"` in the **target** build settings (Debug + Release). The project-level entries still say `2`, which is fine because the target overrides them. Also check that `INFOPLIST_KEY_UISupportedInterfaceOrientations` covers iPhone. It does today: one key, LandscapeLeft + LandscapeRight, with no `~ipad` suffix. Leave `UIRequiresFullScreen = YES`.
2. Update GAME_PLAN §3.1 (text in §3.1 above).
3. Write the QA hooks (§3.5) and scripts (§3.6). Add `Scripts/iphone/shots/` to `.gitignore`.
4. **Before any layout change**, capture the full screen list on **iPad Air 11-inch (M3)**, **iPad mini (A17 Pro)** and **iPad Pro 13-inch (M5)** into `Scripts/iphone/shots/ipad-baseline/<device>/`. This is the D2 reference. Also capture all screens on the 3 iPhones into `Scripts/iphone/shots/iphone-before/` (useful for the report).
5. Write `Scripts/iphone/QA.md`: a table with one row per screen in §3.5 and columns `SE | 15 Pro | 17 Pro Max | iPad mini | iPad Air | iPad Pro 13 | real iPhone | real iPad`, all unticked. Below it, a "hands-on" checklist (I11 fills it): play a song in Perform with real fingers, mic mode with a real pianika, VoiceOver not required.
6. Build for iPad + iPhone and run the tests on iPad. Nothing visual should have changed, because the hooks are DEBUG-only and inert without arguments.

**⚠︎ Plan to show the user first:** the route list you'll support and where the hook lives.

**Done when:** `capture.sh` produces correct, landscape, non-blank screenshots for every screen on one iPad and one iPhone; the baseline folder exists; commit `Task I0: …`.

---

### Task I1 — ⚠︎ Launch delay (white screen ±20 s)

**Goal:** find out why the app shows a white window for 15–25 s before the splash, and fix it if it's in our code.

**Touches:** `MelodissimoApp.swift`, `Models/Sound/SoundModel.swift`, `Services/SFX.swift`, `Services/CloudSync*.swift`, `Services/GameCenter*.swift` (read first, edit only what's guilty).

Facts: `MelodissimoApp.init` runs `preloadAllSounds()` (already async on a global queue), `SFX.shared.preload()` (**synchronous on the main thread**, creating `AVAudioPlayer`s for every effect × `voicesPerEffect`), two `ProgressStore` migrations, `CloudSync.shared.start()` and `GameCenter.shared.authenticate()`.

Steps:
1. Measure on **iPad Air 11-inch** and **iPhone 15 Pro** simulators: time from `simctl launch` until the splash is visible (screenshot polling). Then add temporary `os_signpost` or `print(CACurrentMediaTime())` around each `init` step and read the console (`xcrun simctl spawn <udid> log stream --predicate 'process == "Melodissimo"'`).
2. Likely fix: move `SFX.shared.preload()` off the main thread, the same way `preloadAllSounds` does it (decode on a background queue, publish on main). Keep `SFX` usable before preload finishes, because it already lazily creates players. Defer `CloudSync.start()` and `GameCenter.authenticate()` to after the first frame (`.task` on the root view) if they block.
3. If the delay is only on the simulator (the simulator's audio server can be slow on first use) and none of our steps takes > 200 ms, write that down in §8 and change nothing.
4. Remove the temporary timing code.

**⚠︎ Plan to show the user first:** the measured numbers per step, before changing anything.

**Done when:** the splash appears in < 2 s after launch on both simulators (or §8 explains why it can't from our side); first tap on a key still plays instantly (`SoundModelTests`, `SFXTests` pass); the SFX still play on Dashboard buttons.

---

### Task I2 — Foundation: `Sizing`, screen globals, fonts, app icon, wording

**Touches:** new `Models/Layout/LayoutScale.swift`, new `Views/Common/Sizing.swift`, `Data/Extensions/ViewExtension.swift`, `Data/Extensions/FontExtension.swift`, `Assets.xcassets/AppIcon.appiconset/`, `Views/Settings/SettingsView.swift` (caption string only), `Views/Settings/MicCalibrationView.swift` (string only), `Views/Help/HelpPageView.swift` (strings only), `Views/Dashboard/DashboardView.swift` (share string only), `Data/id.lproj/Localizable.strings`, new `MelodissimoTests/LayoutScaleTests.swift`.

Steps:
1. Add `LayoutScale` + `Sizing` exactly as in §3.2. Register the files in the project if needed (GAME_PLAN §4 rule 7).
2. `LayoutScaleTests`: `.pad` returns its input for `s`, `f` and `tap` (e.g. 220 → 220, 0.5 → 0.5); `make(isPhone: false, shortSide: 393) == .pad`; phone 393 → `s(220) == 105`, `f(40) == 26`, `f(15) == 13`, `tap(80) == 44`; clamping at short sides 300 and 600.
3. Change `screenWidth` and add `screenHeight` (D7).
4. `FontExtension`: wrap the 5 fixed sizes in `Sizing.f(…)` (`.callout` and others that use `preferredFont` stay).
5. App icon: add the iPhone entries to `AppIcon.appiconset/Contents.json`: `iphone` 20@2x (40), 20@3x (60), 29@2x (58), 29@3x (87), 40@2x (80), 40@3x (120), 60@2x (120), 60@3x (180). Generate the missing PNGs from `appstore.png` (1024) with `sips -z <n> <n> appstore.png --out <n>.png`. Reuse existing files where the pixel size matches (40, 58, 80). Rebuild: **the "60x60@2x" warning must be gone**, and no new asset warnings may appear.
6. Wording (D11). The 5 strings:
   - Settings caption: "…The iPad listens through the microphone…" → "…Your device listens through the microphone…"
   - MicCalibration: "Turn it on in the iPad's Settings…" → "Turn it on in your device's Settings…"
   - Help: "Make sure the volume of your iPad is turned up…" → "Make sure your device's volume is turned up…"
   - Help: "If I move to another iPad, will my progress saved?" → "If I move to another device, will my progress be saved?" Then check the answer text under it for "iPad" too.
   - Dashboard share text: "(only available on iPad)" → "(iPhone & iPad)"
   - Update every Indonesian line (use "perangkat" for device) and grep the whole project for any other "iPad" shown to users (comments are fine).
7. Build both, test both (iPad + iPhone), then capture **all** screens on iPhone 15 Pro and the 3 iPads. iPad screens must equal the baseline. Fonts don't change there because `Sizing.f` returns its input on iPad. On iPhone, text gets smaller everywhere. That's expected: note how much better or worse each screen got in §8, as a list that later tasks can use.

**Done when:** tests green on both; iPad identical; no icon warning; strings updated in both languages; commit.

---

### Task I3 — ⚠︎ Keyboard + Song Stage + Chart Recorder + Calibration

**The most important task.** If the game itself doesn't play well on iPhone, nothing else matters.

**Touches:** `Views/Component/TilesComponentView.swift`, `Views/Stage/SongStageView.swift`, `Views/Stage/NoteHighwayView.swift` (read; edit only if needed), `Views/Stage/ChartRecorderView.swift`, `Views/Settings/CalibrationView.swift`, `Views/Settings/MicCalibrationView.swift`, tests touching `PianoMetrics`.

Steps:
1. `PianoMetrics` → width-as-input + phone heights (§3.3). Add the iPad-equality unit test.
2. `PianoKeyboard` on iPhone: a `GeometryReader` gives the safe-area width. All `screenWidth` uses inside it go through `metrics.width`. Keep the outer `.frame(maxWidth: .infinity, minHeight: containerHeight)`. Check that the `MultiTouchKeySurface` hit-testing still matches the drawn keys: **tap the first, a middle and the last white key and black key on iPhone 15 Pro and SE**, and confirm the right note sounds and lights (labels on).
3. `SongStageView` on iPhone:
   - HUD height 72/92 → `Sizing.isPhone ? (isBoss ? 56 : 48) : (isBoss ? 92 : 72)`, and 44 on SE if needed for the ≥ 180 pt highway. Scale everything inside the HUD with `Sizing.s`/`Sizing.f`/`Sizing.tap`. Make sure the pause button and boss badge stay inside the safe area.
   - Overlays (`countInOverlay`, `pauseOverlay`, `finishedOverlay`): the fixed 240×64 and 180×64 buttons → `Sizing.tap`. The pause menu must fit in 393 pt (stack buttons horizontally on phone if vertical doesn't fit).
   - Background art (`stage_bg_ceremony`, `stage_bg_concert`) follows D9.
   - `.ignoresSafeArea(edges: .bottom)` on the VStack: keep it on iPad. On iPhone, keep the keyboard **above** the home indicator, so remove the bottom ignore on phone only.
4. **Lane alignment check:** in Listen mode (autoplay) on iPhone 15 Pro and SE, capture 3 screenshots a second apart. Every falling note must land centred on its key, and the pressed key must light at the moment the note reaches the hit line. Then do the same on the iPad Air and compare with baseline behaviour.
5. Play **Perform** for ≥ 30 s on iPhone 15 Pro, tapping along via the simulator tool (approximate is fine). Judging popups ("Perfect", "Great"…) must be readable and inside the highway. No frame-rate drop (`HighwayPerformanceTests` green).
6. `ChartRecorderView` (DEBUG tool): mechanical pass only. It must not crash or overflow on iPhone, but it doesn't need to be pretty.
7. `CalibrationView` / `MicCalibrationView`: mechanical pass. The big circle (130/190) and the 220×70 buttons scale. With the `.stage` keyboard, everything must fit in 375 pt (SE). Mic calibration: on the simulator, the mic permission prompt appears and the screen layout holds. Real-mic testing goes on the user's list.

**⚠︎ Plan to show the user first:** the phone HUD and keyboard heights you'll use, and an iPhone 15 Pro "before" screenshot of the stage with the numbers marked.

**Manual QA:** stageListen / stagePractice / stagePerform / stageBoss / chartRecorder / settings → Calibration / Mic calibration, on all 6 devices.

**Done when:** highway ≥ 180 pt on SE, notes aligned, all keys hittable on SE, iPad identical to baseline (stage screens), tests green on both; commit.

---

### Task I4 — Battle + Echo

**Touches:** `Views/Battle/BattleView.swift`, `Views/Battle/MonsterSprite.swift`, `Views/Echo/EchoView.swift`.

- Both use `PianoKeyboard(metrics: .full)`, which on iPhone is 170 pt after I3. The remaining ±200 pt holds the monster/prompt area. Use `Sizing.s` on the monster (`MonsterSprite`'s 220 health bar and the sprite size), on the HP bars (150×12), and on the 120×64 buttons (→ `Sizing.tap`).
- `bgMusic` in both is un-sized (D9).
- The existing `GeometryReader`s (Battle lines ~63 and ~151, Echo ~138 and ~200) are fine. Check what they size, because the available height is now much smaller.
- Play 20 s of each on iPhone 15 Pro and SE: hearts, combo and the monster's hit animation all stay visible, and the game-over/won overlay fits.

**Manual QA:** battle, echo, rush (if rush shares a view, include it) on all 6 devices. **Done when:** fits on SE, iPad identical, commit.

---

### Task I5 — ⚠︎ First-run flow (Splash → FirstLaunch → Tutorial → Preplay → PreplayScore; Postplay family)

**Touches:** `Views/Onboarding/*`, `Views/Preplay/*`, `Views/Postplay/*`, `Views/AfterQuiz/AfterQuizView.swift`.

These are old screens built on `UIScreen.main` and `NavigationView`. They all share one pattern: a background image, a white rounded text box at `screenWidth * 0.5 × 300`, a yellow 100 pt "Next" button, and `alpanica` art on the right.

- `SplashscreenView`: keep `scaledToFill`, but make sure the logo/title in `splashscreen` stays visible on a 2.17:1 screen. If the art gets cut, use `scaledToFit` over a `Color.softBlue` fill on phone only.
- `FirstLaunchView` (**currently unusable on iPhone**): D9 for `bgMusic` and `alpanica`, `Sizing.s(300)` text box height (or `maxHeight` + `minimumScaleFactor`), `Sizing.tap(100)` button, `Sizing.tap(80)` "?" button, D8 frame fix. Text box width `screenWidth * 0.5` stays a ratio.
- `TutorialView`: it has a `GeometryReader { proxy -> AnyView }` and `let width = UIScreen.main.bounds.width`. Switch to `proxy.size.width`, and make sure each tutorial page fits.
- `PreplayView` / `PostplayView`: quiz screens with `PianikaStackQuiz`. Check which `PianoMetrics` the stack uses. If it's `.full`, the I3 phone metrics apply. The question box `screenWidth * 0.5 × screenHeight * 0.15` is OK once it reads `screenHeight`.
- Score screens (`PreplayScoreView`, `PostplayScoreView`, `OnboardPostplayView`): text box 300 tall, button 100, `alpanicaGlasses` / `alpanica` un-sized.
- `CoordinatorView`: no layout; just the DEBUG `-qaOnboarding` hook from I0.

**⚠︎ Plan to show the user first:** a phone sketch (text) for FirstLaunch: what goes left and right, and the sizes.

**Manual QA:** walk the **real** first-run flow on iPhone SE and 15 Pro with a fresh install (`xcrun simctl uninstall` then install, no launch args): Splash → FirstLaunch → Next → Tutorial (all pages) → Preplay (answer all questions) → PreplayScore → Dashboard. Then Learn → Skill Test (Postplay) → score. Do the same flow once on iPad Air and compare with baseline. **Done when:** the flow completes on all three without anything clipped; commit.

---

### Task I6 — Home: Dashboard, Free Play, Learn hub, Achievements, Help, shared components

**Touches:** `Views/Dashboard/DashboardView.swift`, `Views/FreePlay/FreePlayView.swift`, `Views/Learn/LearnHubView.swift`, `Views/Achievement/AchievementsView.swift`, `Views/Help/HelpPageView.swift`, `Views/Help/ExpandableSectionView.swift`, `Views/Common/{HubCard,PlayDestinationView,CoinBadge,HeartsView,AchievementBanner,CoachMarkOverlay,CharacterMotion,AssetImage,SoundButton}.swift`.

- Dashboard (17 fixed sizes): the top bar fits already. The **tour card** must show the island name, "Up next: <stage>", the stars and Start, without "•••". Apply `Sizing.s` to the card's fixed sizes, add `lineLimit(1)` + `minimumScaleFactor(0.6)` on the names, and make the llama `scaledToFit` with a `Sizing.s` height. The **three hub cards** (Daily / Free Play / Learn) must be fully visible below the tour card on SE. If the vertical space isn't enough, the phone layout may put the tour card and the hub cards in a horizontal split (tour left ~55%, hub cards stacked right) — D4. Replace `.frame(height: UIScreen.main.bounds.height, …)` with D8. The share popover's `sourceRect` uses `screenWidth/2, screenHeight/2`; on iPhone the activity sheet ignores it, which is fine.
- `CoachMarkOverlay` (7 sizes): the coach bubbles must point at the right control on iPhone. Check the first-visit coach marks with a fresh profile.
- `AchievementBanner`: slides in from the top, so it must stay inside the safe area on iPhone. Trigger one with a seeded profile, or with a DEBUG-only button if there's none (don't commit the button).
- Free Play / Learn hub: `HubCard` grids. Make sure 3 cards fit across on SE, or use 2 + scroll.
- Help: `.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height…)` → D8. Expandable sections must scroll on phone.
- Achievements: the 120×60 back button → `Sizing.tap`. The grid must scroll.

**Manual QA:** dashboard (fresh profile + seeded profile), freePlay, learnHub, achievements, help (expand 2 sections), share button, coach marks. **Done when:** nothing clipped on SE, iPad identical, commit.

---

### Task I7 — Campaign: map, nodes, stage sheet, story card, certificate

**Touches:** `Views/Campaign/*`, read `Models/Campaign/MapLayout.swift` (no change expected; fix its "any iPad" comment to "any screen" only if you edit it).

- `CampaignMapView`: `map_ocean` per D9. Node/avatar/island label sizes via `Sizing.s`. The horizontal `ScrollView` + `ScrollViewReader` must still scroll to the current node on appear. The back button and stars counter stay inside the safe area.
- **Stage sheet** (D10): on phone, drop the `.height(480)` detent (`Sizing.isPhone ? [.large] : [.height(480)]`), and make `StageSheetView` content fit 340 pt or scroll. The play buttons must be visible without scrolling.
- `StoryCardView` (**broken today**: the text column is a few characters wide). The phone layout puts Alpanica and the boss art smaller (`Sizing.s`) and gives the text at least 50% of the card width. The card must fit within the safe area; the Continue button must be visible.
- `CertificateView` (D12): the `ImageRenderer` content keeps fixed iPad sizes. The on-screen card is scaled to fit on phone (`scaleEffect` from a `GeometryReader`, or render the same view at a scale). Check that the shared image is byte-for-byte the same size on iPhone and iPad (log the rendered image size once in DEBUG).

**Manual QA:** campaignMap (fresh + seeded), tap a node → stage sheet, `-qaOverlay story`, `-qaOverlay certificate`, share sheet from the certificate. **Done when:** all fit on SE, iPad identical, commit.

---

### Task I8 — Stage setup, results, not angka sheet, boss badge

**Touches:** `Views/Stage/StageSetupView.swift`, `StageResultView.swift`, `NotAngkaSheetView.swift`, `BossBadgeView.swift`.

- `StageSetupView` (11 sizes): mode picker (Listen/Practice/Perform), speed picker, labels toggle, start. On phone, everything must fit without scrolling on SE. If not, move the not angka preview (if shown) to a horizontal split (D4).
- `StageResultView` (10 sizes): stars, score, accuracy, coins, Retry/Next/Map buttons, Alpanica, confetti. On SE, all three buttons must be visible. Check 0★ (`alpanicaSad`) and 3★ (confetti).
- `NotAngkaSheetView`: it draws from the chart (`NotAngkaLayoutTests`). Check the vertical scroll and that a line of not angka isn't clipped horizontally. If the layout uses a fixed width, compute it from the available width. Keep the tests green.
- `BossBadgeView`: `Sizing.s` (it sits in the HUD resized in I3).

**Manual QA:** stageSetup, result3, result0, and the not angka sheet for 2 songs (a short one and the longest). **Done when:** fits on SE, iPad identical, commit.

---

### Task I9 — Settings + Shop

**Touches:** `Views/Settings/SettingsView.swift`, `Views/Shop/ShopView.swift`, `Views/Shop/Skins.swift`.

- Settings (**overflowing horizontally today**): find the fixed widths. The rows use `.frame(width: 130, alignment: .leading)` labels and segmented buttons sized for iPad (note speed 1.5/2.0/2.5/3.0 s, input Touch / Real pianika, backing track, labels, offset, reset). The phone layout goes inside the safe-area width; the existing `ScrollView` handles height. The `fullScreenCover`s (calibrations) are covered by I3.
- Shop (15 sizes): item cards 190 wide, previews 130 tall, 120×80 tabs. The grid must adapt (2–3 columns on phone). Buy/equip buttons → `Sizing.tap`. The coin badge stays visible.

**Manual QA:** settings (scroll to the bottom, toggle each control once, open both calibrations, open and cancel reset), shop (each tab, buy one item with seeded coins, equip it, see the skin on the stage keyboard). **Done when:** no horizontal overflow on SE, iPad identical, commit.

---

### Task I10 — Legacy lessons

**Touches:** `Views/Notation/NotationLearnView.swift`, `Views/Notation/Quiz/*`, `Views/Song/Learn/*`, `Views/Song/Quiz/*`.

- Mostly `UIScreen.main` (D7, D8) and `bgMusic` (D9). Grids use `GridItem(.adaptive(minimum: UIScreen.main.bounds.width * 0.4))` → `screenWidth * 0.4` (unchanged on iPad). Card heights 250 → `Sizing.s(250)`.
- `NotationQuizLevelMenuView`: `.frame(width: screenWidth, height: screenHeight * 0.8)` and the level grid (`0.2` width items, 250 tall) — make sure the 100 levels scroll and the locked/unlocked state is readable.
- `SongLearnView`: the song image `width × height*0.5` + `PianikaStackLearningMini` (`.mini` phone metrics from I3) must fit together on SE.
- `NotationLearnView`: `PianikaStackLearning` — check which metrics it uses.
- Classic level play (from `notationLevelMenu` → a level) uses the battle or quiz flow. Play one level to the end on 15 Pro.

**Manual QA:** notationLearn, notationLevelMenu (scroll to level 100), play level 1, songRepositoryLearn, songLearn, songRepositoryQuiz. **Done when:** fits on SE, iPad identical, commit.

---

### Task I11 — Final QA matrix, docs, executor notes

1. `grep -rn "UIScreen.main" Melodissimo` → only the two globals in `ViewExtension.swift` remain. Then `grep -rnE 'Image\("[^"]+"\)$' Melodissimo/Views` (followed by no `.resizable()` on the next line) → none left that are backgrounds or character art.
2. Fresh install on each of the 6 simulators, then capture every screen into `Scripts/iphone/shots/final/<device>/`. Compare the iPads against `ipad-baseline` screen by screen. Tick `Scripts/iphone/QA.md` for every simulator column.
3. Full tests on iPad Pro 13-inch (M5) **and** iPhone 15 Pro.
4. Release build for both (`-configuration Release`), to prove the DEBUG hooks compile out: `grep -c qaRoute` on the built binary's strings should be 0.
5. Update GAME_PLAN §3.1 if anything changed since I0, and fill §8 with: final scale factors, phone keyboard metrics, each phone-only layout (D4) and where it lives, and what is **not verified** (real devices).
6. Hand the user the **real-device checklist** in `Scripts/iphone/QA.md`:
   - Install on a real iPhone (Xcode → the iPhone as run destination; free provisioning is fine) and a real iPad.
   - Play 2 songs in Perform with fingers. Are the keys big enough for a child? Is the timing OK? (Adjust the audio offset in Settings if needed.)
   - Real-pianika mode near the iPhone's bottom mic, in a quiet room.
   - Backing track volume through the iPhone loudspeaker, and with headphones.
   - Rotate the phone both ways (Landscape Left/Right). The Dynamic Island side must never cover a button.
   - First-run flow on a fresh install.
   - Indonesian language (Settings → General → Language): check that long Indonesian strings fit on iPhone. They are usually longer than the English, so this is the most likely place for leftover clipping.

**Done when:** QA.md simulator columns all ticked, both builds clean, tests green on both, §8 filled; commit `Task I11: iPhone QA and docs`.

---

## 7. Risks and how to catch them

| Risk | Where | Catch |
|---|---|---|
| iPad layout changes by accident | any view | D2 + executor rule 1 (baseline compare every task) |
| Notes no longer line up with keys | I3 | lane alignment screenshots in Listen mode, both device classes |
| Keys too small for children's fingers on SE (≈ 32 pt) | I3 | real-device test (I11). If it's bad, a follow-up could add a "zoom keyboard" (show 1.5 octaves around the song's range). **Not in this phase**, so log it in §8. |
| Indonesian strings longer than English, clipping on phone | all | I11 language check; `minimumScaleFactor` on long labels |
| `UIScreen.main` read before rotation returns portrait on iPhone | globals | D7 (max/min) |
| Sheets/covers behave differently on iPhone (no form sheet) | I7, I9 | D10, test each sheet on phone |
| DEBUG hooks leak into Release | I0 | I11 step 4 |
| Simulator launch delay hides real issues | I1 | measured on both classes |
| `minimumScaleFactor` making iPad text smaller | all | only effective when text doesn't fit; baseline compare would show it |

---

## 8. Executor notes

*(Executors append one bullet per task here: decisions, tuned numbers, deviations, and "Not verified, please check by hand".)*

- **I0 (14 Oct 2026).** Plan-first step skipped on purpose: the user's instruction was "execute it all", so the ⚠︎ plans are recorded here instead of waiting for an OK. Route list = §3.5 plus extras: `dashboard`, `battleBoss`, `classic` (classic level 1), `songLearn`/`stage*`/`result*` honour `-qaSong <slug>`, onboarding adds `postplay` (PostplayView), overlay adds `storyBoss`. The hook lives in `DashboardView` (`.onAppear { QARoutes.applyLaunchRoute(to: router) }`), the rest is in `Views/Common/QARoutes.swift`.
  - Deviations from §3.5/§3.6: (1) `-qaSeed YES` writes the mid-game profile into the simulator's own `UserDefaults.standard` instead of an in-memory suite, because `AchievementStore` and `CloudSync` also read `.standard` and would not see a private suite; `simctl uninstall` clears it, and it only runs with the argument in a DEBUG build. (2) `shot.sh` cannot guess the rotation: the simulator may be in either landscape orientation, so the DEBUG app writes `Documents/qa-orientation.txt` and the script reads it (`landscapeLeft` → rotate 90°, `landscapeRight` → 270°; the plan's "270° on 14 Oct" was the other orientation). (3) "Ready" is not guessed from pixels: the app writes `Documents/qa-ready.txt` once the route is pushed and `capture.sh` waits for it. The first baseline run guessed from pixels and caught two blank screens under load. (4) Captures force English (`-AppleLanguages (en)`); the iPad simulators are set to Indonesian. `LANG_ID=1` renders Indonesian. (5) Extra scripts: `capture_all.sh` (all devices in parallel), `build_install.sh`, `sheet.swift` (contact sheets for reviewing many screenshots at once).
  - Simulators used (UDIDs in `Scripts/iphone/devices.txt`): SE 3rd gen, iPhone 15 Pro (both iOS 17.5; SE 3rd gen does not exist on 18/26), iPhone 17 Pro Max (26.1), iPad mini A17 Pro and iPad Air M3 (18.6), iPad Pro 13" M5 (26.1). The baseline was built from a copy of the tree without any I2 change, so it is a true "before".
  - Test device note: the iPad Air and iPad mini simulators are set to Indonesian, so the English-title tests (`AchievementTests`, `LocalizationTests`) fail there for that reason alone. Run the unit tests on **iPad Pro 13-inch (M5)** and **iPhone 15 Pro**, which are English (iPad Pro passes at the I0 state). Screens use `stageSolemn` (Indonesia Raya) for the calm stage; every other stage route uses the first non-solemn song (Bagimu Negeri). The iPad Pro (iOS 26.1) simulator does not rotate its framebuffer: it shows the landscape app upright and letterboxed, so `devices.txt` marks it `letterbox` and `shot.sh` crops the black bars instead of rotating (its screenshots are 4:3 at 1200×900).
  - Machine note: six simulators at once on this 16 GB Mac is slow (about 15 min for 37 screens × 6 devices) and the iPad Pro (iOS 26.1) once hung under load; it was shut down and re-run.
- **I1 (14 Oct 2026).** Measured with temporary `NSLog` timing (removed) on iPhone 15 Pro (iOS 17.5) and iPad Air M3 (iOS 18.6), quiet machine, Debug build, two to three launches each. Milliseconds since process start unless noted:
  - **Before:** pre-main to `init` 270–870 ms; `preloadAllSounds()` call 5–32 ms (async); **`SFX.shared.preload()` 750 ms (iPhone) / 1030–1100 ms (iPad)**, synchronous on the main thread; both migrations ≤ 1 ms; `CloudSync.start` 10–27 ms; `GameCenter.authenticate` 11–49 ms; splash on screen at 1.2–1.8 s (iPhone) / 1.6–2.3 s (iPad).
  - **Fix:** `SFX.preload(completion:)` now decodes on a background queue and hands the players to the shared pools on the main thread, the same pattern as `preloadAllSounds`. An effect played before it finishes builds its own players, as before. `CloudSync` and `GameCenter` take < 50 ms, so they stay where they were.
  - **After:** `SFX.preload` call 0 ms; splash on screen at 0.48–0.92 s (iPhone) / 0.61–1.3 s (iPad) after process start, i.e. 1.3–1.4 s after `simctl launch` on both (the script's own overhead is about 0.8 s).
  - **The ±20 s white screen did not reproduce.** It happened when many simulators were booted at once and the Mac was saturated (load average in the hundreds): cold launches then took 20 s or more regardless of what our code does. On a quiet machine the launch was already under 2.5 s before the fix. So the "20 s" was the machine, not the app; the real finding is the 0.75–1.1 s of audio decoding that blocked the first frame, which is fixed. New test: `SFXTests.testPreloadDecodesOffTheMainThreadAndHandsTheEffectsOverOnMain`; `SFXTests` and `SoundModelTests` pass on iPhone 15 Pro.
  - Not verified: launch time and the first key tap on a real device; the SFX clicks can't be heard in the simulator (the test proves `play` succeeds after preload).
