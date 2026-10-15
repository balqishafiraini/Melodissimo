# Melodissimo — Stability & Performance Plan (real-device bugs)

> **Ringkasan (buat Balqis)**
> - Di HP asli: tekan tuts **telat bunyi**, lagu **berhenti di tengah**, app terasa **berat**. Log terminal nunjukin 3 hal:
>   1. **Game Center + iCloud jalan tanpa entitlement.** App nyoba login Game Center selama ±23 detik dan gagal, dan iCloud KVS ngasih error `BUG IN CLIENT OF KVS`. Itu buang CPU/jaringan di awal app dan selama main.
>   2. **`System gesture gate timed out`** artinya sentuhan di dekat pinggir layar (keyboard pianika ada di bawah, deket garis home) **ditahan sistem** dulu buat ngecek "ini swipe home/Control Center bukan?". Itu bikin tuts telat, dan kalau ke-detect jadi swipe, app jadi *inactive* → lagu **otomatis pause** (kelihatannya "berhenti di tengah").
>   3. **`SwiftUI encountered an issue when pushing a NavigationLink`**: masih ada `NavigationLink(isActive:)` model lama di dalam `NavigationStack`.
> - Dari baca kode, penyebab lain yang paling mungkin:
>   - Tiap tuts dimainkan pakai `AVAudioPlayer`, dan **dilepas pakai `stop()`**. Di iOS, `stop()` ngebatalin `prepareToPlay`, jadi tekan berikutnya harus nyiapin ulang file audio → **delay**. Setiap pindah layar juga `stop()` ke 32 player sekaligus.
>   - **Layar nggak dikunci dari auto-lock** pas main. Di mode Listen / mic pianika (nggak ada sentuhan) layar bisa redup/terkunci → lagu berhenti.
>   - **Gangguan audio** (telepon, Siri, alarm, colok/cabut headset Bluetooth) nggak ditangani. Musik latar bisa mati sendiri, dan setelah telepon bunyi nggak balik lagi.
>   - Musik latar **lompat-lompat**: tiap 1 detik dicek, kalau melenceng >50 ms langsung di-*seek*. Di HP yang sibuk itu sering kejadian.
>   - Gambar Alpanica ukurannya **2000×2924 px** (±23 MB RAM per gambar setelah di-decode), padahal tampilnya cuma ±170 pt.
>   - Animasi `repeatForever` di Home/peta **tetap jalan di belakang** layar main lagu.
>   - Deteksi nada mic (YIN) dihitung manual. Di build Debug di HP itu berat, dan antriannya bisa numpuk.
> - Plan ini: **S0–S9**, dikerjakan berurutan oleh Sonnet 5.5. Tiap task: build + test + commit sendiri.
> - Hapus **ConfettiSwiftUI** → diganti confetti buatan sendiri (S7).
> - Tombol **"?"** di iPhone terlalu mepet atas → semua top bar iPhone dibikin satu ukuran dan satu jarak yang sama (S8).
> - **Bagian kamu**: akhir S9 ada checklist buat dicoba di HP asli. Penting: **test di HP pakai build Release** (S0 bikin scheme-nya). Build Debug di HP bisa 3–10× lebih lambat buat kode Swift yang berat (deteksi nada, Canvas), jadi "lag" di Debug belum tentu ada di versi App Store.

This document is written for an AI executor (**Claude Sonnet 5.5**). It adds **Phase 11 (tasks S0–S9)**. Unlike earlier plans, **one session executes all tasks in order**, committing after each. There are no ⚠︎ tasks: every decision is made in §2. Stop and report only if a build or test failure can't be fixed within the task's scope.

---

## Progress tracker

| Task | Title | Kind |
|---|---|---|
| S0 | Prep: Release device scheme, perf/leak scripts, baseline numbers | setup |
| S1 | Game Center + iCloud only when switched on (no entitlement → no calls) | fix |
| S2 | One audio session controller: interruptions, route changes, media reset | fix |
| S3 | Low-latency note engine (`AVAudioEngine` + PCM buffers), SFX on it too | perf |
| S4 | Play-screen lifecycle: auto-lock, system edge gestures, home indicator, pause rules | fix |
| S5 | Song stage hot path: HUD isolation, SFX at judge time, highway & keyboard work per frame, backing track | perf |
| S6 | Microphone: vDSP pitch detection, bounded queue, lazy engine | perf |
| S7 | Remove ConfettiSwiftUI; in-house `ConfettiBurst` | dependency |
| S8 | iPhone top bar: "?" / Menu / Back buttons at one consistent inset | UI |
| S9 | Memory & leak sweep, soak test, docs, device checklist | QA |

- [x] S0  - [x] S1  - [x] S2  - [x] S3  - [x] S4  - [x] S5  - [x] S6  - [x] S7  - [ ] S8  - [ ] S9

---

## 1. Evidence

### 1.1 The device log (from Balqis, real iPhone, Debug build)

| Log line | Meaning | Task |
|---|---|---|
| `Unable to find entitlement for KVS store` / `BUG IN CLIENT OF KVS` | `NSUbiquitousKeyValueStore.default` is touched without the iCloud KVS entitlement. `CloudSync.shared`'s default argument `CloudSyncStore()` touches it at init, even before `start()`'s guard. | S1 |
| `The Game Center entitlement is required…`, `com.apple.gamed was invalidated`, `Authentication failed … in 22.8621 seconds` | `GameCenter.shared.authenticate()` runs at launch with no Game Center entitlement. It churns XPC for ~23 s during launch and the first screens. | S1 |
| `SwiftUI encountered an issue when pushing a NavigationLink` | A `NavigationLink(destination:isActive:)` inside Home's `NavigationStack`, from `PianikaStackQuiz` (`TilesComponentView.swift`) or the legacy onboarding pages pushed from the stack. | S9 (§6 S9.4) |
| `fopen failed for data file: errno = 2` | System framework noise (seen with audio/haptics), not from our code. Ignore. Record in §8 if it disappears. | — |
| `Received Song Title…` / `Song Title…` | Our own `print`s in `SongLearnView` / `TilesViewModel`. Harmless, but remove (S9). | S9 |
| `<0x…> Gesture: System gesture gate timed out.` | A touch near a screen edge was held while iOS decided whether it was a system gesture. In landscape the pianika keyboard sits on the home-indicator edge. This is **touch latency**, and when iOS decides it *is* a system gesture, the scene goes `.inactive` and `SongStageView` pauses the song. | S4 |

### 1.2 Findings from the code (ranked by likely user impact)

1. **Note release calls `AVAudioPlayer.stop()`** (`SoundModel.swift` `stopSound(key:)`, `stopAllSounds()`). `stop()` undoes `prepareToPlay()`, so the next `play()` of that note must re-acquire and re-prime → tens of ms of delay, worst on device. `AppRouter.path.didSet` calls `stopAllSounds()` on **every** navigation, so all 32 notes are un-prepared each time a screen changes. Compressed `.m4a` + `AVAudioPlayer` on the main thread is also the slowest route to a sound. → **S3**
2. **No auto-lock suppression.** `isIdleTimerDisabled` is never set. Listen mode and microphone mode have no touches, so the phone dims and locks mid-song → song pauses / "stops in the middle". → **S4**
3. **System edge gestures not deferred** (see the log). No `defersSystemGestures`, home indicator always visible. → **S4**
4. **No audio-session interruption / route-change / media-services-reset handling.** After a call, Siri or alarm, the session is deactivated, but `isAudioSessionConfigured` stays `true`, so it is never re-activated → silent app. The backing track stops while the song clock runs on. Unplugging Bluetooth changes `outputLatency` (and can pause playback). → **S2**
5. **Backing track drift correction seeks too eagerly**: `resyncTolerance = 0.05` s, checked every second, a single reading triggers `player.currentTime = expected` while playing. With rate ≠ 1 (time-pitch) and AAC seek granularity, that means audible skips and possible repeated re-seeks. `load()` also builds and prepares the `AVAudioPlayer` on the main thread inside `onAppear` → stutter at stage start. → **S5**
6. **Song stage re-renders too much per hit.** `SongStageView` owns the engine as `@StateObject`, so every `score/combo/counts` change re-evaluates the whole body, including the 32-key `PianoKeyboard` (32 `GeometryReader` preference writers). SFX for hits are fired from `.onChange(of: engine.counts.perfect)`, i.e. one render later than the judgment. → **S5**
7. **Three per-frame drivers on the stage**: `CADisplayLink` (engine), `TimelineView(.animation)` for the highway, another for the progress bar (which also runs `notes.reduce` every frame), plus one during the count-in. On ProMotion that is 120 Hz each. The highway loops **all** notes twice per frame. → **S5**
8. **Microphone YIN** is O(τmax × window) ≈ 500 k multiply-adds per hop, ~47 hops/s. Debug builds on device can fall behind; `window` then grows without bound and every hop queues another `DispatchQueue.main.async`. A `MicrophoneInput` (with its own `AVAudioEngine`) is also created for **every** stage, even when the mic isn't used. Also `.measurement` mode makes speaker output quieter. → **S6**
9. **Huge images**: `alpanicaCrown`, `alpanicaGIF3`, `alpanicaGlasses` are 2000×~2900 px (~23 MB each decoded); `tutorialSlider1/2` are 2.7k×2k. They are shown at ~170 pt tall. → **S9**
10. **`repeatForever` idle animations** (`CharacterMotion.swift`: `IdleBreathe`, `Wobble`, `GentleFloat`) keep running on screens hidden under the `NavigationStack` (Home, the map) while a song plays. → **S9**
11. **`Timer.publish(...).autoconnect()` stored as a `let` in view structs** (`BattleView`, `EchoView`, `ChartRecorderView`): a new timer publisher is made on every struct re-init. → **S9**
12. **`SongChart.load(for:)` decodes JSON from disk on every call**, including from view bodies (`SongLearnView.sheet`). → **S9**
13. **`CloudSync` observes `UserDefaults.didChangeNotification`** and merges the *whole* defaults dictionary on the main thread 1 s after any write. Results screens write many keys. → **S1**

---

## 2. Decisions (made; do not re-ask)

- **D1 Online services off by default.** Game Center and iCloud KVS run only when the Info.plist key `MelodissimoOnlineServices` is `YES`. Default **NO** (key added with value NO). Reason: the team `AZQ73MXTBD` profile has neither capability. Adding an entitlement the profile lacks breaks device signing, so **do not add `.entitlements` files**. The README section (S1) tells Balqis how to turn it on later (paid team → add capabilities in Xcode → set the key YES).
- **D2 Note audio = `AVAudioEngine`**, one engine for notes + SFX, PCM buffers decoded once at launch (off-main), a fixed pool of `AVAudioPlayerNode` voices. Public free functions in `SoundModel.swift` keep their names and signatures (`playSound(key:)`, `stopSound(key:)`, `stopSound()`, `stopAllSounds()`, `preloadAllSounds(completion:)`, `preloadedSoundCount`, `configureAudioSessionIfNeeded()`), so no caller changes. `SFX`'s public API (`SFX.play`, `SFX.shared.play(_:)`, `canPlay`, `preload`) also stays the same.
- **D3 Note release** is a 15 ms linear fade then stop (no click), not an instant cut. Retrigger of the same note cuts the previous voice of that note (same as today's behaviour).
- **D4 Pause rule unchanged**: the song still pauses when the scene leaves `.active` (that's correct for a call or the app switcher). S4 makes *accidental* edge swipes much rarer instead.
- **D5 Backing drift**: tolerance 0.12 s, a resync needs **two consecutive** readings over tolerance, and at most one resync per 3 s.
- **D6 Confetti**: replace with an in-house Canvas burst. Same trigger points (`confettiCounter` increments), ~30 pieces, ~2.5 s, then the view stops drawing. Reduce Motion → no confetti.
- **D7 Top bar on iPhone**: one shared inset for every screen with a top row of Menu/Back + title + "?": **12 pt** below the safe-area top, **16 pt** side inset inside the safe area, buttons `Sizing.tap(56)` high. iPad numbers untouched (iPad rule from IPHONE_PLAN §4.1 still applies).
- **D8** Do **not** change gameplay timing constants (`Judge` windows, `approachTime`), visuals, colours or copy beyond what each task lists.

---

## 3. Executor rules

Read `GAME_PLAN.md` §3–4 and `IPHONE_PLAN.md` §3–4 first; they still apply (iPad rule, iPhone screenshots, localization, `Sizing`). In addition:

1. **Order:** S0 → S9, one commit per task: `Task S<N>: <title>`. Tick the checkbox in the tracker in the same commit.
2. **Build + tests after every task**:
   ```bash
   xcodebuild -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build -quiet
   xcodebuild test -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -quiet
   ```
   S3, S5 and S9 also run the tests on `iPhone 15 Pro`.
3. **Play check** for S2–S6: launch on the iPhone 15 Pro simulator with `-qaRoute stagePerform` (and `stageListen`, `stagePractice`) via `Scripts/iphone/shot.sh` / `xcrun simctl launch … -qaRoute <name>`, let it play ≥ 20 s, tap keys with `xcrun simctl io` or the iOS Simulator tool, take a screenshot, and look at it. Hearing the audio is not possible; check with logs (S0 adds a DEBUG `AudioDiag` log line on engine start/restart and on interruption).
4. **Never stage** `xcuserdata`. Stage only what the task touched.
5. **Leaks:** S0 creates `Scripts/perf/leaks.sh`. Run it at the end of S3, S5, S6 and S9 and paste the summary line into §8.
6. Every new type gets a doc comment in the house style (see `RhythmEngine.swift`): plain sentences, explain *why*.
7. **Tests:** pure logic gets unit tests in `MelodissimoTests` (existing naming, e.g. `BackingScheduleTests`). Don't unit-test AVFoundation itself.
8. Record numbers, deviations and anything **not verified** in **§8 Executor notes**.

---

## 4. Tasks

### S0 — Prep: Release device scheme, perf/leak scripts, baseline

**Why:** Balqis tests on device from Xcode → Debug (`-Onone`). We need (a) a one-click way to run Release on the device and (b) repeatable leak/footprint numbers before and after.

1. Add a shared scheme `Melodissimo (Release run)`: copy `Melodissimo.xcodeproj/xcshareddata/xcschemes/Melodissimo.xcscheme` (create the shared scheme from the user scheme if only a user scheme exists; check `xcuserdata/…/xcschemes`, but **don't modify** that folder) and set `LaunchAction buildConfiguration="Release"`. Keep `Melodissimo` as is.
2. Make the deployment targets consistent: the project-level `IPHONEOS_DEPLOYMENT_TARGET` is 16.4, the targets 16.6. Set the project level to 16.6 (targets already are). Nothing else in build settings.
3. `Scripts/perf/leaks.sh <simulator-udid> <qaRoute> [cycles=10]`: boots (if needed) and installs the Debug build, launches with `-qaRoute <route>` plus a new DEBUG argument `-qaCycle <n>` (step 4), waits for the app to print `QA cycle done`, then runs `leaks <pid>` and `footprint <pid>` (find the pid with `xcrun simctl spawn <udid> launchctl list | grep Melodissimo` or `pgrep -f Melodissimo.app/Melodissimo`). Writes `Scripts/perf/out/<route>-<date>.txt` and prints one summary line: `leaks: N (B bytes), footprint: X MB`.
4. `QARoutes`: DEBUG-only `-qaCycle <n>`: after the launch route is applied, pop to root and push the same route again `n` times, 4 s apart (song routes then actually play 4 s each), then `print("QA cycle done")`. Use the existing `applyLaunchRoute` machinery. Nothing in Release.
5. `AudioDiag` (DEBUG only, `Services/AudioDiag.swift`): `static func log(_ message: @autoclosure () -> String)` → `os_log` with subsystem `melodissimo.audio`. No-op in Release.
6. Baseline: run `leaks.sh` for `stagePerform`, `battle`, `result3`, `campaignMap` on iPhone 15 Pro, 10 cycles. Record in §8.
7. Add `Scripts/perf/out/` to `.gitignore`.

**Done when:** new scheme builds in Release for `generic/platform=iOS` (`xcodebuild -scheme "Melodissimo (Release run)" -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO -quiet`), baseline numbers in §8.

### S1 — Game Center + iCloud only when switched on

**Touches:** `Services/GameCenter.swift`, `Services/CloudSync.swift`, `MelodissimoApp.swift`, `Data/Info.plist`, `Views/Dashboard/DashboardView.swift` (one line), `README`-style note in this file §7, tests.

1. `enum OnlineServices { static var isEnabled: Bool }` reads `Bundle.main.object(forInfoDictionaryKey: "MelodissimoOnlineServices") as? Bool ?? false`. Add the key to `Melodissimo/Data/Info.plist` as `<false/>`.
2. `CloudSync`: the cloud store must not be created until it is needed. Change `cloud: SyncStore = CloudSyncStore()` to a lazily created store (e.g. `init(local:cloud: (() -> SyncStore)? = nil, …)` with a `lazy var cloud`), so `CloudSync.shared` never touches `NSUbiquitousKeyValueStore` unless `start()` passes its guard. `start()` guard becomes `OnlineServices.isEnabled && FileManager.default.ubiquityIdentityToken != nil`. Keep tests working by injecting a dictionary store (existing tests construct `CloudSync(local:cloud:)`; keep a compatible initializer).
3. `CloudSync.scheduleSync`: debounce 1 s → **5 s**, and skip scheduling while `PlaySession.isActive` (S4 creates `PlaySession`; in S1 add a minimal `enum PlaySession { static var isActive = false }` in `Services/PlaySession.swift`, which S4 fills in). When a play ends, S4 calls `CloudSync.shared.syncSoon()`, which schedules one.
4. `GameCenter.authenticate()`: return immediately unless `OnlineServices.isEnabled`. Call it **not** from `MelodissimoApp.init` but from `DashboardView`'s first `onAppear` (guard with a static `didAuthenticate` flag), so launch is not competing with GameKit. `submit` already guards `isAuthenticated`.
5. Tests: `OnlineServicesTests` can't flip Info.plist; instead test that `CloudSync(local:cloud:)` with an injected store still merges (existing tests) and that a `CloudSync` built with the lazy factory doesn't call the factory before `start()` (count calls).
6. Write §7 "Turning on Game Center and iCloud" (Indonesian + English, short): paid Apple Developer team → Signing & Capabilities → + Game Center, + iCloud (Key-value storage) → set `MelodissimoOnlineServices` YES in `Data/Info.plist` → create the 3 leaderboards (ids in `GameCenter.swift`).

**Done when:** launching on the simulator prints none of the GameKit/KVS lines (check `xcrun simctl spawn <udid> log stream --predicate 'process == "Melodissimo"'` for 20 s after launch; record in §8).

### S2 — One audio session controller

**Touches:** new `Services/AudioSessionController.swift`, `Models/Sound/SoundModel.swift`, `Services/MicrophoneInput.swift`, `Services/BackingTrackPlayer.swift`, `Views/Stage/SongStageView.swift`, tests for the pure parts.

`final class AudioSessionController` (singleton `shared`, main-thread only):

1. `enum Mode { case playback, record }`. `activate(_ mode:)` sets the category once per change:
   - playback: `.playback`, mode `.default`, options `[]`.
   - record: `.playAndRecord`, mode **`.default`** (not `.measurement`, which makes the speaker quiet), options `[.defaultToSpeaker, .allowBluetoothA2DP]`.
   - Both: `setPreferredIOBufferDuration(0.005)` (ignore failure), `setActive(true)`.
   - Remember the current mode; calling with the same mode while active is a no-op.
2. Observers (added once, in `init`, removed never; it's a singleton):
   - `AVAudioSession.interruptionNotification`: on `.began` → set `isInterrupted = true`, post `AudioSessionController.didInterrupt` (a `Notification.Name`). On `.ended` → re-activate the current mode, post `.didResume` (always, ignore `shouldResume`; the game shows its pause overlay and the player resumes by hand).
   - `AVAudioSession.routeChangeNotification`: post `.routeChanged` (reason `oldDeviceUnavailable` included). Main queue.
   - `AVAudioSession.mediaServicesWereResetNotification`: mark inactive, re-activate, post `.mediaReset` (S3's engine rebuilds itself on this).
   - `UIApplication.didBecomeActiveNotification`: if the session isn't active (e.g. after an interruption whose `.ended` never came), re-activate.
3. `configureAudioSessionIfNeeded()` (in `SoundModel.swift`) becomes a thin call to `AudioSessionController.shared.activate(.playback)` **only if no mode is active yet**. Keep the `willResignActive → stopAllSounds()` behaviour (move that observer into the controller).
4. `MicrophoneInput.begin()` → `AudioSessionController.shared.activate(.record)`; `stop()` → `activate(.playback)`. Remove its own `setCategory` calls.
5. `SongStageView`: `.onReceive(NotificationCenter.default.publisher(for: AudioSessionController.didInterrupt))` → `engine.pause(now:)`. On `.routeChanged` with reason `.oldDeviceUnavailable` (headphones unplugged) → also pause. (The pause overlay already lets the player resume.) Do the same pause in `BattleView`, `EchoView` and Melody Rush's view if they have a pause concept; if they don't, just stop sounds.
6. `BackingTrackPlayer.handle(.running)` uses `AudioSessionController.shared.outputLatency` (a computed pass-through), so route changes are picked up on the next start/resume.
7. `AudioDiag.log` every activation, interruption begin/end, route change, reset.

**Done when:** build + tests green; on the simulator, triggering an interruption isn't possible. Verify by code review plus a DEBUG-only hidden hook: `QARoutes` argument `-qaFakeInterruption 5` posts a fake `.began` after 5 s and `.ended` 2 s later (post the notification with the right `userInfo`). Check the stage shows the pause overlay (screenshot) and `AudioDiag` logs the re-activation.

### S3 — Low-latency note engine (`AVAudioEngine`) with SFX on it

**Touches:** new `Services/NoteAudioEngine.swift`, `Models/Sound/SoundModel.swift`, `Services/SFX.swift`, `MelodissimoApp.swift` (preload calls unchanged), tests.

Design (`final class NoteAudioEngine`, singleton, main-thread API):

1. **Buffers:** at preload, on a background queue, read each note's `.m4a` (`NoteCatalog.all[].sound`) and each SFX `.caf` with `AVAudioFile` into an `AVAudioPCMBuffer` in the engine's `mainMixerNode.outputFormat(forBus: 0)` processing format. Use `AVAudioConverter` when the file's format differs (sample rate / channel count). Hand the dictionary to the main thread. Memory: 32 notes × ~1–2 s × 48 kHz × 2 ch × 4 B ≈ 25 MB worst case → **trim**: if a note sample is longer than 3.0 s, keep only the first 3.0 s (note the real lengths in §8; if total buffer memory > 20 MB use mono buffers, since the pianika samples are effectively mono).
2. **Graph:** one `AVAudioEngine`. Note voices: **12** `AVAudioPlayerNode`s → a `notesMixer` (`AVAudioMixerNode`) → main mixer. SFX voices: **6** player nodes → `sfxMixer` (volume `SFX.volume` = 0.6) → main mixer. Attach and connect everything once. `engine.prepare()`, `engine.start()` after the session is active.
3. **play(note):** if this note already has a voice sounding, stop that voice (cut, as today). Otherwise take the least-recently-started free voice; if none is free, steal the oldest. `node.stop(); node.volume = 1; node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil); node.play()`. Keep `voiceForNote[key]` and `noteForVoice[index]`.
4. **stop(note):** 15 ms fade: set `node.volume` stepping to 0 over 3 steps with `DispatchQueue.main.asyncAfter` (5 ms apart) and then `node.stop()`, **only if the voice still belongs to that note and hasn't been retriggered** (use a per-voice generation counter). Pure helper `VoiceAllocator` (struct) for steps 3–4's bookkeeping, unit-tested: pick free voice, steal oldest, retrigger same note, stale-stop ignored after retrigger.
5. **stopAll:** stop every note voice immediately (used on navigation; that's fine with an engine, nothing gets un-prepared).
6. **SFX:** `SFX.play` → `NoteAudioEngine.shared.playEffect(resource:)` round-robin over the 6 SFX voices; keep `isEnabled` check and the "missing file → false" behaviour. `SFX.preload` → buffers via the same loader. Keep the `SFX` type and API; delete the `AVAudioPlayer` pools.
7. **Robustness:**
   - Observe `.AVAudioEngineConfigurationChange` (route/format change, session category change by the mic) → on main: `engine.stop()`, reconnect nodes with the new format **only if** the output format changed (re-convert buffers in background if the sample rate changed), `engine.start()`. Log via `AudioDiag`.
   - On `AudioSessionController.mediaReset` → rebuild the engine from scratch (new `AVAudioEngine`, re-attach, re-start; buffers keep if the format is the same).
   - On `didResume` → `engine.start()` if not running.
   - Every `play` checks `engine.isRunning`; if not, try `start()` once (catch → `AudioDiag` + return).
8. `SoundModel.swift`: the free functions forward to `NoteAudioEngine.shared`. `preloadedSoundCount` → number of note buffers. Delete `playerCache`, `player`, `makePlayer`, `cachedPlayer`.
9. The backing track stays on `AVAudioPlayer` (long compressed file, `rate` + `play(atTime:)` already work). Not in this task.
10. **Callers:** `RhythmEngine`'s default `soundPlayer`/`soundStopper` keep working unchanged. Grep for any other `AVAudioPlayer` use (Battle/Echo/Tiles) and route it through `playSound` if it plays note samples.

**Done when:** tests (incl. new `VoiceAllocatorTests`) green on iPad + iPhone; `-qaRoute stageListen` plays through on the simulator with `AudioDiag` showing one engine start and no errors; `leaks.sh stagePerform` shows no new leaks vs S0.

### S4 — Play-screen lifecycle: auto-lock, edge gestures, home indicator

**Touches:** `Services/PlaySession.swift`, new `Views/Common/PlayScreenModifier.swift`, `SongStageView.swift`, `BattleView.swift`, `EchoView.swift`, the Melody Rush view, `ChartRecorderView.swift`, `MicCalibrationView.swift`, `CalibrationView.swift`, `CoordinatorView.swift` or the app root, `CloudSync.swift` (one call).

1. `PlaySession` (main-thread enum with static state): `begin()` / `end()` with a counter (screens can overlap during a push/replace animation). `begin` → `UIApplication.shared.isIdleTimerDisabled = true`, `isActive = true`. `end` → when the counter hits 0: `isIdleTimerDisabled = false`, `isActive = false`, `CloudSync.shared.syncSoon()`.
2. `.playScreen()` view modifier: `onAppear { PlaySession.begin() }`, `onDisappear { PlaySession.end() }`, plus `.defersSystemGestures(on: .all)`, `.persistentSystemOverlays(.hidden)`, `.statusBarHidden(true)`. Apply to every play screen in **Touches**.
3. **Edge deferral needs to reach UIKit.** `defersSystemGestures` only works when the hosting controller asks its children; SwiftUI's root `UIHostingController` does that on iOS 16+. Verify on the simulator: with the stage open, a single swipe up from the bottom edge must show only the home-indicator grabber, not go home; record the result in §8. If it does **not** work, add a small `UIViewControllerRepresentable`-free fallback: a `UIHostingController` subclass is not possible with `WindowGroup`, so instead set `preferredScreenEdgesDeferringSystemGestures` via a `UIViewController` found from the key window's `rootViewController` and call `setNeedsUpdateOfScreenEdgesDeferringSystemGestures()`; only if the modifier alone fails.
4. `SongStageView` keeps `scenePhase != .active → pause` (D4).
5. `MicCalibrationView` and `CalibrationView` also get `.playScreen()` (they run without touches).

**Done when:** build + tests green; screenshot of `stagePerform` on iPhone 15 Pro shows no home indicator; `isIdleTimerDisabled` is true during the stage and false after popping (log it with `AudioDiag`-style DEBUG log, then verify in the log stream).

### S5 — Song stage hot path

**Touches:** `RhythmEngine.swift`, `SongStageView.swift`, `NoteHighwayView.swift`, `TilesComponentView.swift`, `BackingTrackPlayer.swift`, `BackingSchedule.swift`, tests.

1. **Scoreboard split.** Move `score`, `combo`, `maxCombo`, `counts`, `wrongPresses` publishing into a new `final class StageScoreboard: ObservableObject` owned by the engine (`let scoreboard = StageScoreboard()`), with `@Published private(set)` fields and internal mutators the engine calls. The engine keeps read-only computed pass-throughs (`engine.score` → `scoreboard.score`, etc.) so tests and `finish()` keep compiling. The engine's own `@Published` stays only for `phase` and `hintKeyId`.
2. **HUD isolation.** Extract the score area and boss badge into `private struct StageHUDScore: View { @ObservedObject var scoreboard: StageScoreboard … }`. `SongStageView` no longer re-renders on each hit. The combo pulse moves into that subview (`onChange(of: scoreboard.combo)`).
3. **SFX at judge time.** Add `var onJudgment: ((Judgment?) -> Void)?` to the engine, called synchronously in `registerHit`, the auto-miss loop, `pressPerform`'s wrong branch and `pressPractice`'s wrong branch. `SongStageView` sets it in `onAppear` and removes the three `.onChange(of: counts…/wrongPresses)` sound handlers. The closure lives on the engine, so it captures only plain values (`isSolemn`, `mode`) and calls the static `SFX.play`. It must never capture the engine, the scoreboard or view `@State`. The practice wrong-key flash does **not** go through this closure: publish `lastWrongPress: WrongPress?` (`keyId` + an increasing `serial`) on the scoreboard and let a small subview (or the keyboard's highlight computation) observe it and run the 0.3 s flash. Set `onJudgment = nil` in `onDisappear`.
4. **Progress bar without a timeline.** Add `@Published private(set) var judgedCount` to the scoreboard, updated where judgments are set (incl. Listen's silent marking). The bar observes it; delete its `TimelineView` and the per-frame `reduce`.
5. **Highway per frame.**
   - Precompute in `NoteHighwayView.init` an array of `RenderNote { index, keyId, isBlack, time, duration, fill: Color }` sorted by time (skin colours resolved once). Draw white then black by iterating precomputed index arrays.
   - Only iterate the visible window: binary-search the first note with `time + duration >= songTime - 0.5` and stop at the first with `time > songTime + approachTime`. Read judgments from `engine.notes[i].judgment`.
   - `drawLanes`: build the lanes `Path` once per `keyFrames` change (store in a small reference-type cache keyed by the frames' hash) instead of every frame.
   - Keep `TimelineView(.animation)`; keep the `CADisplayLink`. Do **not** cap the frame rate.
6. **Keyboard.** In `PianoKeyboard.onPreferenceChange`: `guard newTiles != tiles else { return }` before assigning and before calling `onKeyFrames`. Make `KeyTile` `Equatable` (all stored properties are equatable; `Color` is) and use `.equatable()` so a press re-renders only the pressed key.
7. **Backing track.**
   - `BackingSchedule.resyncTolerance` 0.05 → **0.12** (D5). New pure `DriftGate` struct: `mutating func shouldResync(drift: Double, now: Double) -> Bool` returning true only on the 2nd consecutive over-tolerance reading and ≥ 3 s after the previous resync. Unit-test it.
   - `load` is done off-main: `func load(...) async` creates and prepares the `AVAudioPlayer` on a detached task, then publishes it on the main actor. `SongStageView` starts the engine **after** the load returns (in a `.task` that replaces the current `onAppear` start). Show nothing new; the count-in just begins ~100 ms later. If the view disappeared meanwhile, don't start.
   - On `.halted`, keep `player.pause()`; on `.finished` the fade-out stays.
8. **Tests:** update `RhythmEngineTests` for the scoreboard pass-throughs (should mostly compile as-is), add `DriftGateTests`, add a test that `onJudgment` fires exactly once per hit/miss/wrong.

**Done when:** build + tests green on iPad + iPhone; `stagePerform`, `stagePractice`, `stageListen`, `stageBoss`, `stageSolemn` screenshots unchanged vs `Scripts/iphone/shots/final/15pro/` (positions/sizes); `leaks.sh stagePerform` no new leaks. Optional (do it if `xctrace` works headless): `xcrun xctrace record --template 'Time Profiler' --time-limit 15s --launch …` on the simulator and note the main-thread % before/after in §8.

### S6 — Microphone

**Touches:** `Services/MicrophoneInput.swift`, `Models/Audio/PitchDetector.swift`, `SongStageView.swift` (+ any other view that owns a `MicrophoneInput`), tests.

1. **Lazy engine:** `MicrophoneInput` creates its `AVAudioEngine` in `begin()` (an optional `var engine: AVAudioEngine?`), not at init, and releases it in `stop()`. In `SongStageView`, keep the `@StateObject` (it's cheap now).
2. **vDSP YIN:** rewrite the difference function with Accelerate: for each τ, `vDSP_vsub` + `vDSP_svesq` (or `vDSP_distancesq`) over the window. Keep the exact same algorithm, threshold and range so results match. Pre-allocate the scratch buffers once per `MicrophoneInput` (pass a reusable `PitchDetector.Workspace` class), no per-hop `Array` allocations. Existing `PitchDetectorTests` must stay green; add a test that the vDSP version matches the old scalar version within 0.5 Hz on synthetic sines at 175, 440, 1000 Hz (keep the old scalar code as `detectReference` in the test target or as `internal` in the app).
3. **Bounded backlog:** if `window.count > 4 × bufferSize`, drop the oldest samples down to `bufferSize` (and advance `windowStart` accordingly) and `AudioDiag.log("mic backlog dropped")`.
4. **Main-thread coalescing:** only dispatch to main when `currentKeyId` actually changes or an onset fired (track the last sent key on the analysis queue).
5. Session via `AudioSessionController` (done in S2): verify `.record` mode uses `.default`, not `.measurement`. If detection worsens audibly that's for Balqis to check on device; note it in §9 checklist.

**Done when:** build + tests green; `leaks.sh` with `-qaRoute stagePerform` and the input mode set to pianika (add a DEBUG `-qaInputMode pianika` argument that sets `ProgressStore.shared.inputMode` for the run, without persisting it after) shows no leaks (the simulator mic may be silent; that's fine).

### S7 — Remove ConfettiSwiftUI

**Touches:** `Melodissimo.xcodeproj/project.pbxproj`, `Melodissimo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `Views/Stage/StageResultView.swift`, new `Views/Common/ConfettiBurst.swift`, tests.

1. **`ConfettiBurst`**: `.confettiBurst(trigger: Int)` modifier. When `trigger` changes (and Reduce Motion is off), overlay a `TimelineView(.animation)` + `Canvas` that draws 30 pieces (rectangles and circles, colours from the app palette: `.yellow`, `.softGreen`, `.softBlue`, `.red`, `.darkGreen`), launched from the bottom-centre upward in a ±60° fan with gravity, rotation, and fade over the last 0.6 s; **total 2.5 s**. Three "repetitions" like today = three launches 0.25 s apart. After the last piece finishes, remove the overlay (state flag), so no timeline runs afterwards. `allowsHitTesting(false)`. Physics is a pure `ConfettiPhysics.position(of piece:, at t:)` → unit-tested (deterministic seeds, the piece is off-screen or fully faded at t = 2.5).
2. `StageResultView`: replace both `.confettiCannon(counter: $confettiCounter, …)` with `.confettiBurst(trigger: confettiCounter)`; remove `import ConfettiSwiftUI`.
3. **Remove the package** from `project.pbxproj`: the `PBXBuildFile` line (`FAB6CE78…`), the `Frameworks` build-phase entry, the target's `packageProductDependencies` entry, the project's `packageReferences` entry (`FAB6CE76…`), the `XCRemoteSwiftPackageReference` section, and the `XCSwiftPackageProductDependency` section (`FAB6CE77…`). Leave empty `packageProductDependencies = ( );` lists valid. Delete the ConfettiSwiftUI pin from `Package.resolved`; if no pins remain, delete the file.
4. Verify: `grep -rni confetti Melodissimo.xcodeproj` returns nothing; `grep -rn "ConfettiSwiftUI" .` returns only this plan; clean build (`-derivedDataPath /tmp/melodissimo-s7` fresh) succeeds; `xcodebuild -resolvePackageDependencies` resolves nothing.
5. Screenshot `result3` on iPhone 15 Pro and iPad Air at ~1.2 s after appear (confetti visible) and at 4 s (gone).

### S8 — iPhone top bar: "?" / Menu / Back at one consistent inset

**Why:** On iPhone the "?" (and Menu/Back) buttons sit at different heights per screen, some nearly touching the top edge (compare `Scripts/iphone/shots/final/15pro/songLearn.png`, `learnHub.png`, `freePlay.png`, `campaignMap.png`, `notationLevelMenu.png`).

**Touches:** new `Views/Common/PhoneTopBar.swift` (or extend `Sizing`), and the 18 screens with `Text("?")` or the Home help icon:
`LearnHubView`, `SongLearnView`, `SongRepositoryLearnView`, `FreePlayView`, `DashboardView` (help icon row), `SongRepositoryQuizView`, `PhoneStoryPage`, `PreplayView`, `PreplayScoreView`, `NotationLearnView`, `CampaignMapView`, `NotationQuizLevelMenuView` (both), `PhoneSkillTestView`, `PostplayView`, `PostplayScoreView`, `OnboardPostplayView`, `FirstLaunchView`.

1. Add `Sizing.topBarInset` (iPhone 12, iPad: return the value each screen uses today, i.e. don't apply on iPad), `Sizing.topBarSide` (iPhone 16), `Sizing.topBarButton` (`Sizing.tap(56)` on iPhone).
2. A reusable `PhoneTopBar(leading:title:trailing:)` view for iPhone **only**, used by the screens above inside their existing `if Sizing.isPhone` branches (or a `.phoneTopBarInsets()` modifier where restructuring is too invasive). The "?" button: square `topBarButton`, `Font.title2`, same `darkGreen` fill and corner radius `Sizing.s(20)`, vertically centred with the Menu/Back button and the title's centre line.
3. On iPhone the whole row sits `topBarInset` below the safe-area top, and the content below starts 8 pt under it. Remove ad-hoc `.padding(.all, Sizing.isPhone ? 4 : nil)` on those buttons.
4. **iPad rule:** iPad screenshots of every touched screen must equal `Scripts/iphone/shots/ipad-baseline/` (or `shots/final/ipad-air`).
5. Capture all touched screens on SE, 15 Pro, 17 Pro Max; read each PNG; the "?" top edge must be at the same y on every screen (±1 pt), and never closer than 12 pt to the top of the safe area. Put a before/after pair for `songLearn` and `campaignMap` in `Scripts/iphone/shots/s8/`.

### S9 — Memory & leak sweep, soak, docs, device checklist

**Touches:** `CharacterMotion.swift`, `BattleView.swift`, `EchoView.swift`, `ChartRecorderView.swift`, `SongChart.swift`, `SongLearnView.swift`, `TilesViewModel.swift`, `TilesComponentView.swift` (`PianikaStackQuiz`), `Assets.xcassets` (the five images), this file.

1. **Idle animations stop when hidden.** In `IdleBreathe`, `Wobble`, `GentleFloat` add `.onDisappear { var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { flag = false } }` so the repeat-forever animation is replaced by a non-animated state change and stops; `onAppear` restarts it (already does). Check any other `repeatForever` in the project the same way.
2. **Timers:** replace `private let ticker = Timer.publish(...).autoconnect()` in `BattleView`, `EchoView`, `ChartRecorderView` with a `@State private var ticker = Timer.publish(...).autoconnect()` **or** better: `.task { while !Task.isCancelled { tick(); try? await Task.sleep(nanoseconds: 50_000_000) } }` (cancelled automatically on disappear). Keep the same interval and tick logic.
3. **Chart cache:** `SongChart.load(for:)` memoizes by `song.id` in a static `[String: SongChart]` (main-thread only; add `dispatchPrecondition` in DEBUG). The Chart Recorder's preview passes its own chart, so it's unaffected.
4. **`PianikaStackQuiz`'s `NavigationLink(isActive:)`** → `.navigationDestination(isPresented: $viewModel.canNavigateToAfterQuizPage) { AfterQuizView(…).navigationBarBackButtonHidden(true) }` when it's inside Home's `NavigationStack`. Find who embeds `PianikaStackQuiz` and make sure the modifier is attached inside the stack (not in a `NavigationView`). The onboarding pages' `NavigationLink(isActive:)` live in their own `NavigationView` before Home exists; leave them, **unless** a page is reachable from Home's stack (`PhoneSkillTestView` / Learn → Skill Test already avoid it per its doc comment; verify, note in §8). Goal: the "SwiftUI encountered an issue when pushing a NavigationLink" line no longer appears when going Home → Free Play → Classic Levels → Level 1 → finish, and Home → Learn → Songs → a song.
5. **Images:** downscale `alpanicaCrown`, `alpanicaGIF3` (`alpanicaCrownGlasses`), `alpanicaGlasses` to a max height of **900 px** (aspect kept) and `tutorialSlider1/2` to max width **1600 px**, with `sips -Z`. Compare a screenshot of `result3`, `shop` and `onboard-tutorial` before/after on iPad Pro 13 (the largest display) to be sure nothing looks soft. If any looks soft, use 1200 px for that one. Record before/after file sizes in §8.
6. **Remove debug prints**: `SongLearnView` "Received Song Title", `TilesViewModel` "Song Title" / "Answer correct!" / "Answer incorrect!" (delete), `SoundModel` error prints → `AudioDiag`.
7. **Soak test:** `leaks.sh` 30 cycles for `stagePerform`, `battle`, `echo`, `rush`, `result3`, `campaignMap`, `songLearn` on iPhone 15 Pro. Pass = 0 leaks attributed to Melodissimo symbols, and footprint after cycle 30 within +15 MB of after cycle 5 (run twice: 5 and 30 cycles). Fix anything that fails, then record the table in §8.
8. **Docs:** fill §8 and update the progress tracker. Make sure §9 is accurate after everything changed.

---

## 5. Out of scope

- Backing track engine rewrite (stays on `AVAudioPlayer`, only made gentler).
- Chart content, judging windows, gameplay rules, visual redesign.
- Adding entitlements (D1).
- The legacy onboarding `NavigationView` flow beyond S9.4.

## 6. Risk notes for the executor

- `AVAudioEngine` + `AVAudioSession` category changes (mic on/off) fire `AVAudioEngineConfigurationChange`; the engine **stops itself**. That's why S3.7 must restart it, otherwise notes go silent after a microphone stage.
- `scheduleBuffer` completion handlers run on an audio thread; don't use them to touch state (S3 doesn't need them).
- `defersSystemGestures` has no visible effect in screenshots; verify by behaviour (S4.3).
- Changing `RhythmEngine`'s published properties can break `RhythmEngineTests`; keep pass-throughs with the same names.
- `project.pbxproj` edits: after S7, open nothing in Xcode; build with `xcodebuild` to validate the file.

## 7. Turning on Game Center and iCloud (for Balqis, later)

**Sekarang mati.** Game Center dan iCloud sengaja dimatikan karena profil signing tim `AZQ73MXTBD` belum punya kapabilitasnya. Menyalakan kapabilitas yang tidak ada di profil bikin app gagal ter-install di HP. Jadi **jangan** tambah file `.entitlements` dengan tangan.

Cara menyalakannya nanti:
1. Pakai akun **Apple Developer berbayar**; pilih team-nya di Xcode.
2. Target Melodissimo → **Signing & Capabilities** → **+ Capability** → **Game Center**, lalu **+ Capability** → **iCloud** → centang **Key-value storage**. Xcode membuat file `.entitlements` dan memperbarui profil.
3. Di `Melodissimo/Data/Info.plist` ubah `MelodissimoOnlineServices` dari `<false/>` jadi `<true/>`.
4. Di App Store Connect buat 3 leaderboard **Classic** (skor angka bulat, makin tinggi makin bagus) dengan id persis seperti di `Services/GameCenter.swift`: `melodissimo.rush`, `melodissimo.echo`, `melodissimo.stars`.

**Currently off.** Game Center and iCloud are switched off on purpose: the `AZQ73MXTBD` signing profile doesn't have those capabilities, and adding an entitlement the profile lacks breaks device signing. Don't add a `.entitlements` file by hand.

To switch them on later:
1. Use a **paid Apple Developer** team and pick it in Xcode.
2. Melodissimo target → **Signing & Capabilities** → **+ Capability** → **Game Center**, then **+ Capability** → **iCloud** → tick **Key-value storage**. Xcode creates the `.entitlements` file and updates the profile.
3. In `Melodissimo/Data/Info.plist` change `MelodissimoOnlineServices` from `<false/>` to `<true/>`.
4. In App Store Connect create the 3 **Classic** leaderboards (integer score, higher is better) with the ids in `Services/GameCenter.swift`: `melodissimo.rush`, `melodissimo.echo`, `melodissimo.stars`.

## 8. Executor notes

### Leak / footprint table (iPhone 15 Pro simulator, iOS 17.5, Debug, 10 cycles of 4 s)

`Scripts/perf/leaks.sh 82912AB1-0987-41D0-B945-AC8F57DC62EC <route> 10`. Footprint is the `footprint` total after the last cycle.

| Route | S0 baseline leaks | S0 footprint | S3 | S5 | S6 | S9 (10 cycles) |
|---|---|---|---|---|---|---|
| stagePerform | 1 (16 B) | 69 MB | 735 (29 KB)¹, 77 MB | 751 (30 KB)¹, 77 MB | 725 (29 KB)¹, 77 MB² | |
| battle | 1 (16 B) | 67 MB | | | | |
| result3 | 1 (16 B) | 76 MB | | | | |
| campaignMap | 1 (16 B) | 80 MB | | | | |

¹ **Framework records, not growth.** From S3 on every run shows a few hundred small leaks (735 at 10 cycles, 369 at 20, 755 at 10 on another run; STACKS=1 shows every root is AudioToolbox's `ListenerMap::InsertEvent`, called from `AVAudioMixerNode` attach inside `NoteAudioEngine.buildGraph()` at launch). The count does not grow with the number of cycles. S9's pass criterion is therefore "no leak count growth between 5 and 30 cycles, none rooted in our own allocations".

² Run with `-qaInputMode pianika` (the microphone open on every cycle).

The single 16-byte "ROOT LEAK" is in every route including the plain campaign map, so it is a system allocation, not ours.

### Deviations and notes

- **S0 simulators by UDID.** `-destination 'platform=iOS Simulator,name=iPhone 15 Pro'` is ambiguous here (iOS 17.5 and 18.x runtimes both have it), so the checks use `id=` of the devices in `Scripts/iphone/devices.txt`. `Scripts/perf/verify.sh [phone-tests]` runs the §3.2 build + tests that way.
- **S0 schemes.** No shared scheme existed (Xcode generated `Melodissimo` on the fly), so S0 adds shared `Melodissimo` (Debug launch, includes `MelodissimoTests`) and `Melodissimo (Release run)` (Release launch).
- **S0 leaks.sh** finds the app's pid by the simulator UDID in its path (other booted simulators also run the app). `STACKS=1` turns on malloc stack logging; it is off by default because it inflates the footprint. The app writes `Documents/qa-cycle-done.txt` as well as printing `QA cycle done`, because `simctl launch` without `--console` doesn't show stdout.
- **S1 verification.** Launching Debug on the iPhone 15 Pro simulator (iOS 17.5) and streaming `log stream --predicate 'process == "Melodissimo"'` for 22 s after launch gave 950 lines and **zero** matching `kvs|gamed|gamekit|game center|entitlement`. (The old build's lines can't be reproduced on a simulator, which has no gamed entitlement check, so this proves only that nothing we call touches them; the device check is §9 item 1.)
- **S1 API shape.** `CloudSync` has a designated `init(local:cloudFactory:isEnabled:songTitles:)` and a convenience `init(local:cloud:songTitles:)` (always enabled) for tests. `sync()`, `forgetProgress()` and `syncSoon()` are no-ops while disabled. `GameCenter.authenticate()` is called from Home's `onAppear` and guards itself (once per launch).

- **S2 verification.** `-qaFakeInterruption 5` with `-qaRoute stagePerform` on the iPhone 15 Pro simulator: `AudioDiag` logged `session active: playback` at launch, `interruption began` at 5 s, then (2 s later) `interruption ended, session restored: true` with a fresh `session active: playback` line. The screenshot after it shows the "Paused" overlay. A real call/Siri/Bluetooth change is **not verified** (§9 items 5 and 6).
- **S2 scope.** Battle (which also runs Melody Rush) and Echo have no pause concept, so an interruption just silences their sounds (`stopAllSounds()` / `viewModel.silence()`). The `willResignActive → stopAllSounds()` observer moved into `AudioSessionController`.
- **Concurrent Xcode edits (found during S1).** While S0/S1 ran, the working tree gained edits that aren't part of this plan: `Melodissimo/Melodissimo.entitlements` (Game Center + iCloud), `CODE_SIGN_ENTITLEMENTS` and `INFOPLIST_KEY_NSMicrophoneUsageDescription`/`INFOPLIST_KEY_UIUserInterfaceStyle` in `project.pbxproj`, and the matching removal of those keys from `Data/Info.plist` (Xcode's Signing & Capabilities UI does this). My first S0/S1 commits swept the entitlements file and the Info.plist removal in by mistake, so I rewrote the two local commits (nothing was pushed) to hold only my changes. Those edits stay **uncommitted** in the working tree and no task stages them (`git add` is by explicit path). Note: if the entitlements file is committed later, `MelodissimoOnlineServices` must be flipped to YES together with it (§7); and committing the Info.plist removal without the pbxproj hunks would drop the microphone usage text and Light style.
- **S3 design deviations.** (a) Buffers are all **mono float 48 kHz** (the mixers resample to the hardware rate), so nothing is ever re-converted on a route change, and the "reconnect if the output format changed" step of §S3.7 is unnecessary: a configuration change just restarts the engine. (b) Note samples are 3.4–5.8 s on disk (32 files, 152 s in all, mono 48 kHz AAC); trimmed to 3.0 s with a 50 ms fade, the 32 buffers total about 17 MB, under the 20 MB limit. SFX files (0.05–0.54 s) are downmixed from stereo/44.1 kHz. (c) `SFX` keeps its API but owns its buffers; `NoteAudioEngine.playEffect(_ buffer:)` takes a buffer instead of a resource name. `SFX.play` returns true when the file exists and the setting is on (the engine's own failure is only logged), matching its old doc comment. (d) `SoundModel.swift` now only forwards to the engine; `stopSound()` releases the last played note.
- **S3 verification.** `-qaRoute stageListen` for 22 s on the iPhone 15 Pro simulator: `AudioDiag` shows one `session active: playback` and one `note engine started` (the simulator's output is 96 kHz), no errors; the stage screenshot shows the song advancing. The sound itself can't be heard in this environment: **not verified by ear**. Footprint is 8 MB higher than the S0 baseline (the decoded buffers).
- **S4 deviation: edge deferral and the home indicator live at the stack root.** `.defersSystemGestures` / `.persistentSystemOverlays(.hidden)` applied inside the pushed play screens did **nothing** (the screenshot still showed the home indicator); applied on Home's `NavigationStack` they work. So `.playScreen()` (per screen) only counts `PlaySession` and hides the status bar on iPhone, and `playSessionSystemUI()` (applied once in `DashboardView`) reads `PlaySessionState.shared.isActive` to switch both requests on. `AudioDiag` (DEBUG) logs what UIKit's root view controller then asks: `deferred edges = 15, home indicator hidden = true` during a stage. `.statusBarHidden` is limited to iPhone (iPhone landscape has no status bar anyway) so iPad layouts can't shift.
- **S4 verification.** `isIdleTimerDisabled` is true at `play session begin` and false at `play session end` in the log stream (`-qaCycle` pops and re-pushes). The iPhone 15 Pro screenshot of `stagePerform` has no home indicator. iPad Air captures of stageListen/stagePractice/battle/echo/both calibrations match `shots/final/ipad-air` in layout (differences are the animation phase; stageListen 4.7 %, others < 1 %) apart from the home indicator now being hidden. **Not verified:** the actual behaviour of a swipe from the bottom edge. The simulator tool's edge swipe went straight home, which a simulator can't tell apart from a deferred gesture (§9 item 3).
- **Online services in the working tree.** At S4 the user's working copy of `Info.plist` has `MelodissimoOnlineServices` set to `<true/>` (their edit, uncommitted; the committed value is `false`). With it on, the simulator shows Game Center's sign-in sheet over the app. QA runs therefore pass `-qaOnlineServices NO` (a DEBUG-only override in `OnlineServices`; `leaks.sh` and `capture.sh` pass it).
- **S5 notes.** (a) `StageScoreboard` holds score/combo/maxCombo/counts/wrongPresses/judgedCount/lastWrongPress; the engine keeps read-only pass-throughs (`RhythmEngineTests` compiled unchanged). (b) `StageHUDScore` and `StageProgressBar` (private, in `SongStageView.swift`) observe it; the combo pulse moved into `StageHUDScore`. The progress bar's `TimelineView` and per-frame `reduce` are gone. (c) SFX are fired from `engine.onJudgment`, set in `onAppear` from two captured plain values (`mode`, `isSolemn`) and cleared in `onDisappear`; the practice wrong-key flash subscribes to `scoreboard.$lastWrongPress` with `.onReceive` (a subscription, not an observation, so the stage still doesn't re-render for score changes). Behaviour change: several misses in one frame now play one miss sound each (the old `onChange` collapsed them). (d) Highway: precomputed `RenderNote` lists (white/black, sorted by time) with a binary search for the first visible note (looking back by the longest note's length), skin colours resolved once, the lane `Path` cached until the highway's origin or height changes. (e) Keyboard: `onPreferenceChange` ignores identical frames; `KeyTile` is `Equatable` + `.equatable()`. (f) Backing track: tolerance 0.12 s, `DriftGate` (2 readings in a row, 3 s apart), `load` is `async` (file opened and primed on a detached task) and the stage starts the engine in `.task` after it returns (skipped if the view is gone or the engine is past `.ready`).
- **S5 verification.** Build + tests green on iPad Pro 13 and iPhone 15 Pro. Screenshots of `stagePerform/Practice/Listen/Boss/Solemn` on the iPhone 15 Pro match `shots/final/15pro` in every position and size (the 3–7 % pixel differences are note positions, the Dynamic Island on the other side, and the hidden home indicator from S4). A Practice stage driven by simulator taps advances on the correct key. `leaks.sh stagePerform`: same framework-only leaks as S3 (¹). **Not done:** the optional `xctrace` Time Profiler before/after, so there is no main-thread % to report; the backing track's resync behaviour and SFX timing aren't audible here (§9 items 2 and 7).
- **S6 notes.** (a) `PitchDetector` uses `vDSP_distancesq` (one call per lag, no scratch arrays) and `vDSP_rmsqv`; the algorithm, threshold and range are unchanged. The old scalar version lives in the test file as `detectReference`; `PitchDetectorTests` checks 175/440/1000 Hz at 44.1 and 48 kHz (and a tone with overtones plus noise) agree within 0.5 Hz. `PitchDetector.Workspace` is reused by `MicrophoneInput`. (b) **Backlog is bounded by the queue, not by the window.** `analyse` already drains its window on every call, so the window never grows; what piles up is the queue of pending chunks. The audio thread therefore counts pending samples under a lock and drops a new chunk (with `AudioDiag` "mic backlog dropped", and a fresh window afterwards) when more than `max(4 × 2048, 2 × chunk)` are waiting. (My first version dropped old samples out of the window and on this simulator, whose input taps arrive as ~9600-sample chunks, it dropped on every callback; the log showed it.) (c) The engine is created in `begin()` and released in `stop()`; the main thread is woken only when the heard key changes or an onset fires; a frame queued before `stop()` can't light a key afterwards. (d) `-qaInputMode pianika` (DEBUG) forces `ProgressStore.inputMode` for the launch, nothing stored. (e) The session in record mode uses `.default`, not `.measurement` (S2).
- **S6 verification.** Simulator microphone (granted with `simctl privacy`): `leaks.sh stagePerform 10` with the mic mode shows the same framework-only leaks and footprint as without it; `AudioDiag` shows `session active: record` / `playback` switching on every cycle, no backlog drops, and a single note-engine start (the note engine stayed running across the category switches on the simulator). Detection quality with a real pianika, and whether `.default` mode detects as well as `.measurement` did, are **not verified** (§9 item 8).
- **S7 notes.** `ConfettiBurst` = pure `ConfettiPhysics` (`Models/Game`, 3 launches × 30 pieces 0.25 s apart, ±60° fan, gravity, spin, each piece lives 2.5 s and fades over its last 0.6 s, so the whole burst is 3.0 s and the overlay is then removed) + a `Canvas` view modifier; Reduce Motion skips it. `pbxproj` edits were made on top of the user's uncommitted Xcode changes (see the concurrent-edits note): only the confetti removal is committed, staged from the committed blob, and the user's hunks stay in the working tree. `Package.resolved` was deleted (its only pin was ConfettiSwiftUI). Verified: fresh `-derivedDataPath /tmp/melodissimo-s7` build succeeds, `xcodebuild -resolvePackageDependencies` resolves nothing, `-list` no longer shows a ConfettiSwiftUI scheme, `grep -rni confetti Melodissimo.xcodeproj` is empty; the remaining mentions of the package name are in the plan files and in `ConfettiBurst.swift`'s doc comment. Simulator frames of `result3` on the iPhone 15 Pro: confetti in the air about 1 s after the third star, a few stragglers about 1.5 s later, nothing after that. The iPad Air frames I took missed the window (the third star lands ~1.8 s after appear and my capture was too early); the same code path draws both, but iPad confetti was **not seen** on screen.

## 9. Device checklist for Balqis (after S9)

Run with the **`Melodissimo (Release run)`** scheme on the iPhone.

1. Launch: no long wait before Home; the Xcode console shows **no** GameKit / KVS lines.
2. Free Play → Songs → any song → **Perform**: tap fast runs on the lowest row of keys near the bottom edge. Every tap sounds immediately; no "System gesture gate timed out" in the console.
3. Swipe up from the bottom edge once during a song: only the grabber appears; the song keeps going. Swipe twice: goes home and the song is paused when you come back.
4. **Listen** a whole long song without touching the screen: the screen never dims or locks, and the song plays to the end.
5. During a song, have someone call you (or start Siri): the song pauses; after the call, press Resume: notes and backing track sound again.
6. With Bluetooth headphones: start a song, turn the headphones off: song pauses; resume on the speaker works.
7. Backing track at 0.75× speed: no audible jumps for a whole song.
8. Settings → Real pianika → play a song with a real pianika: notes are detected; the speaker is not too quiet.
9. Get 3 stars: confetti appears, then disappears; the results screen is smooth.
10. Check every screen with a "?" button: all at the same height, not touching the top.
11. Play 10 songs in a row, going back to Home between them: no slowdown, no crash.
