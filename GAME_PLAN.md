# Melodissimo → **Konser Nusantara** — Game Plan

> Replaces `PLAN.md`. Its ideas (Melody Rush, boss levels, coins, world map) are included below.
> This document is written for an AI executor (Claude Sonnet) working **one task per session**.
> Read §4 "Executor rules" before touching code.

---

## Progress tracker

| Phase | Theme | Ships as |
|---|---|---|
| 0 | Foundation (notes table, audio, multi-touch keyboard) | internal |
| 1 | Rhythm core logic (charts, clock, judge) | internal |
| 2 | **Song Stage**: falling-notes rhythm mode | **v2.0** |
| 3 | **Note Battle** vs the Fals monster + Melody Rush | v2.1 |
| 4 | **Echo**: ear-training mode | v2.1 |
| 5 | **Nusantara Tour** campaign map | **v3.0** |
| 6 | Coins, shop, daily challenge, settings | v3.0 |
| 7 | Polish, game feel, onboarding, cleanup | v3.x |
| 8 | Stretch: real pianika via mic, iCloud, Game Center | later |

Task checkboxes are in §5. Tick them as tasks land.

---

## 1. The idea

### 1.1 Pitch

**Konser Nusantara** (working title, English: *Alpanica's Nusantara Tour*): a rhythm-adventure game for Indonesian kids learning the **pianika**.

Fals, a mischievous off-key monster, has scrambled the songs of Nusantara. Alpanica the alpaca tours the archipelago **from Sabang to Merauke** to bring the songs back. On each island the player:

- **performs songs** as a falling-notes rhythm game on a real 32-key pianika layout (*Song Stage*),
- **duels Fals's minions** by reading *not angka* (numeral notation) fast (*Note Battle*),
- **trains their ear** by playing back melodies they hear (*Echo*).

Later, kids can play the same stages on their **real pianika** through the iPad microphone (Phase 8). That is the long-term hook: "Guitar Hero for the instrument you already use at school."

### 1.2 Why this fits the app

- It reuses every existing asset. The keyboard, the samples, the 100 note levels, the 18 songs, the score sheets, Alpanica's poses and the progress/achievement system all get a role.
- It matches how pianika is taught in Indonesian primary schools: *not angka* and these songs. That gives you a niche, and teachers have a reason to recommend it.
- "Dari Sabang Sampai Merauke" is already in the song list, so the journey theme comes from your own content.
- The skill chain is **read the number → find the key → play it in time → hear it**, and each link maps to one mode.

### 1.3 What exists today (inventory)

| Asset | Where | Notes |
|---|---|---|
| 32-key pianika (F3–C6) with samples, glide-across touch | `Views/Component/TilesComponentView.swift`, `Models/Sound/SoundModel.swift` | Single-touch only (`DragGesture`). Quiz answers register on **finger lift**. |
| 100 note-reading levels | `Models/Level/LevelFeederModel.swift` | Random questions persisted in `UserDefaults` as `Level1…Level100`. |
| 18 songs as pitch sequences | `LevelFeederModel.songLevel` | **No rhythm data.** All 18 validated: every label matches its key id. |
| Score-sheet images for all 18 songs | `Assets.xcassets/Notasi/*` | |
| Mascot Alpanica: `alpanica`, `alpanicaSad`, `alpanicaGlasses`, `alpanicaCrown`, `alpanicaCrownGlasses` | `Assets.xcassets/Clipart` | |
| Stars, unlocks, combo, 3 lives, daily streak | `Models/Progress/ProgressStore.swift`, `ViewModels/Tiles/TilesViewModel.swift` | |
| 7 achievements | `Models/Achievement/AchievementStore.swift` | |
| One `NavigationStack` router (`Route`, `AppRouter`) | `Views/Dashboard/DashboardView.swift` | |
| Pre-play / post-play skill test | `Views/Preplay`, `Views/Postplay` | Keep: it measures learning. |
| en / id localization | `Data/en.lproj`, `Data/id.lproj` | English keys, Indonesian translations. |
| ConfettiSwiftUI package | SPM | Used in `NotationQuizFiveLevelPassedView`. |

**Missing for a "real game":** timing and rhythm, tension, a world or meta-progression, a reward loop, reasons to return daily beyond the streak counter, and multi-touch.

---

## 2. Game design

### 2.1 Core loop

```
Home ─► Nusantara map ─► pick stage ─► play (Song / Battle / Echo / Boss)
  ▲                                         │
  │                                         ▼
  └── shop (spend coins) ◄── results: stars + coins + achievements ─► next stage unlocks
Daily challenge ─► coins + streak
```

### 2.2 Modes

#### A. Song Stage (rhythm): the headline mode
Numbered notes fall in lanes aligned with the keys and reach a hit line just above the keyboard. Each note shows its *not angka* label, so kids keep practising reading.

| Sub-mode | Rules | Purpose |
|---|---|---|
| **Listen** (Dengar) | Autoplay. Notes fall, keys light up and play. No input. | Learn how the song goes. |
| **Practice** (Latihan) | The song **waits** at the hit line until the correct key is pressed (Synthesia "wait mode"). Wrong key: red flash. After 2 wrong presses or 3 s of waiting, the correct key glows. Key labels on. No score. | Learn the fingering. Completing it once unlocks Perform. |
| **Perform** (Tampil) | Real time. Judged hits, combo, score, accuracy → stars. | The game. |

- **Speed:** 0.5× / 0.75× / 1×. Stars are capped at **1★** at 0.5× and **2★** at 0.75×.
- **Judgment windows** (kid-friendly): Perfect ≤ 70 ms, Great ≤ 130 ms, Good ≤ 200 ms, otherwise Miss. A note that passes the hit line by more than 200 ms is a Miss.
- **Wrong press** (no matching note inside the window): combo resets and the press counts toward an accuracy penalty.
- **Accuracy** = `max(0, P×1.0 + G×0.75 + Good×0.4 − wrong×0.25) / totalNotes × 100`.
- **Stars:** ≥ 60 % 1★, ≥ 80 % 2★, ≥ 95 % 3★ (then the speed cap applies).
- **Score:** P 300 / G 200 / Good 100, × combo multiplier `1 + min(combo / 10, 3)` (integer division, so ×1 to ×4).
- **Full Combo** (0 misses, 0 wrong presses) gets a badge on the results screen.
- **Trophy shelf compatibility:** a 3★ Perform sets the existing trophy flag (`UserDefaults` bool keyed by song title).

#### B. Note Battle (reworked notation quiz)
Alpanica (left) faces a Fals minion (right). The monster "shouts" a note in a speech bubble, for example `5˙`, and the player plays it.

- Correct: the monster loses 1 HP (HP = question count) and combo +1.
- Wrong or timeout: the player loses 1 heart. **The correct key glows for 0.8 s and its sound plays.** This teaching moment is required. Then **the same note is asked again**, so every win means every note was eventually played right.
- 3 hearts. Win when the monster reaches 0 HP. **Stars = hearts left.**
- Optional timer per note, shown as a draining bar.
- Answers still register on **finger lift**, as today, so kids can slide to aim.
- **Boss levels** (every 5th classic level, and campaign bosses): ×2 questions, a bigger monster, and the timer shrinks 5 % per correct answer.

#### C. Melody Rush (endless, from old PLAN.md)
Endless Note Battle. The first note interval is 2.5 s, it gets 8 % shorter every 10 correct answers, and the minimum is 0.8 s. 3 hearts. 10 points per note × combo multiplier (×1 to ×5). The high score is saved.

#### D. Echo (ear training)
The game plays a short phrase. The player plays it back.

- Phrases are 2 notes long at first, +1 every 2 rounds, up to 8.
- Phrases come from a melodic random walk over a note pool, with steps of at most ±2 pool positions. Later rounds can use snippets of real songs.
- **Easy:** keys glow during playback. **Hard:** no glow.
- Each correct note flashes green and shows its label (teaching).
- A wrong note costs a heart and replays the phrase.
- A stage is cleared after N rounds, and stars = hearts left. The endless variant saves a high score.

#### E. Daily Challenge
Seeded by date (`yyyyMMdd`), so it is the same for every player on the same day. It rotates on `dayOfYear % 3`:
- 0 → Echo, 5 rounds.
- 1 → Battle, 15 questions, 4 s timer.
- 2 → Song sprint: Perform the first 32 notes of a seeded random song at 1×.

The reward can be earned once per day.

### 2.3 Campaign: the Nusantara Tour

Six chapters. Each one introduces new notes, so the curriculum gets harder island by island. Songs were assigned **by computed note range and length**, so every chapter's songs use only notes taught so far.

Key ids are the existing ones: `1=4.  2=5.  3=6.  4=7.  5=1 … 11=7  12=1˙ … 18=7˙  19=1˙˙  20+=sharps` (full table in §3.3).

| # | Chapter | New notes (ids) | Songs (stage order) | Boss song | Timer |
|---|---|---|---|---|---|
| 1 | **Sumatra** (Sabang) | `1 2 3 4 5 6 7 1˙` (5–12) | Berkibarlah Benderaku | Terima Kasih Guru | none |
| 2 | **Jawa** | `7. 6. 5.` (4, 3, 2) | Merah Putih, Ibu Kita Kartini, Ibu Pertiwi | Garuda Pancasila | 6 s |
| 3 | **Kalimantan** | `4. 2˙ 3˙` (1, 13, 14) | Halo Halo Bandung, Indonesia Tetap Merdeka | Hari Merdeka | 5 s |
| 4 | **Sulawesi** | `4˙ 5˙ 6˙` (15, 16, 17) | Tanah Airku, Satu Nusa Satu Bangsa, Maju Tak Gentar | Rayuan Pulau Kelapa | 4.5 s |
| 5 | **Bali & Nusa Tenggara** | `4# 1# 5# 2# 6#` (25, 23, 26, 24, 27) | Mengheningkan Cipta *(solemn)*, Indonesia Pusaka | Hymne Guru | 4 s |
| 6 | **Maluku & Papua** (Merauke) | `7˙ 1˙˙` + all remaining sharps (18, 19, 20, 21, 22, 28–32) | — | Dari Sabang Sampai Merauke | 3.5 s |
| — | **Finale: Upacara** | — | **Indonesia Raya** *(solemn ceremony)* | — | — |

**Stage generation rule.** This is deterministic, so implement it as code and don't hand-write 53 stages. `new` = the chapter's new notes; `review` = all earlier chapters' notes.

```
B1  battle  pool = new.prefix(3)                         q=6   timer=none          "Meet the notes"
B2  battle  pool = review.isEmpty ? new.prefix(5)
                 : 70% new / 30% review                   q=8   timer=chapter
E1  echo    pool = new + ≤5 review notes nearest in pitch rounds=3  startLen=2  glow=on
for song in chapter.songs:
    S   song stage (Practice required once → Perform gives stars)
    B   battle  pool = 70% new / 30% review              q=10  timer=chapter
E2  echo    pool = new + review (≤8 nearest)             rounds=5  startLen=3  glow=off
BOSS        song stage = chapter.bossSong, with the Fals boss skin (HP bar = accuracy)
FINALE      (chapter 6 only) ceremony stage = Indonesia Raya
```

That gives 7 + 11 + 9 + 11 + 9 + 6 = **53 stages**. Stage ids are `c{chapter}-{index:02}`, for example `c2-05`.

**Unlocks:**
- Stage *i* unlocks when stage *i−1* has ≥ 1★.
- A chapter's first stage unlocks when the previous chapter's last stage has ≥ 1★.
- **Migration for existing players** (run once): classic levels cleared ≥ 20 / 40 / 60 / 80 / 95 unlocks chapter 2 / 3 / 4 / 5 / 6.

**Solemn songs** (`Indonesia Raya`, `Mengheningkan Cipta`) have **no monster, no combo flames, no screen shake, and a calm flag background.** Indonesia's national-symbols law (UU 24/2009) restricts how the national anthem may be used, and fighting a monster to it would be disrespectful. Keep these songs dignified.

**Free Play stays fully open:** all 18 songs, the 100 classic levels, Echo endless and Rush. Teachers assign specific songs, so never lock content behind the campaign. The campaign adds structure and rewards.

### 2.4 Economy (coins, no real money)

**No in-app purchases.** This is a kids' app.

| Event | Coins |
|---|---|
| Each **new** star on a stage or song (above the previous best) | +10 |
| First clear of a stage | +20 |
| First clear of a boss | +100 |
| Replay clear with no new stars | +5 |
| First completion of a song in Practice | +15 |
| Rush | +1 per 5 correct |
| Echo endless | +2 per round |
| Daily challenge | +50, plus 10 × min(streak, 5) |

Store **`coinsEarnedTotal`** and **`coinsSpentTotal`**, both only ever increasing, and compute `balance = earned − spent`. This makes future iCloud sync conflict-free: merge with `max`.

**Shop** (about 2,000 coins in total, roughly what the full campaign pays out):

| Category | Items (price) | Art needed |
|---|---|---|
| Keyboard skin | Navy (default), Merah Batik 100, Hijau Hutan 150, Biru Laut 150, Emas 300 | No (colors) |
| Note skin | Default, Pelangi (rainbow by pitch class) 200, Neon 250 | No |
| Alpanica outfit | Default, Kacamata 150 (`alpanicaGlasses`), Mahkota 300 (`alpanicaCrown`), Raja Gaya 500 (`alpanicaCrownGlasses`) | **Already in assets** |

### 2.5 Screen map

```
Splash → (first launch: FirstLaunch → Preplay test) → HOME
HOME
├─ Nusantara Tour  (big card: current chapter + next stage)  → Map → Stage sheet → play → Results → Map
├─ Daily Challenge (card: today's type, done ✓, reward)        → play → Results
├─ Free Play       → Songs (18) → Stage setup (Listen/Practice/Perform, speed) → play → Results
│                  → Classic Levels (existing 100 grid → Note Battle)
│                  → Echo endless · Melody Rush
├─ Learn           → Notation Learn · Song Learn (score sheets) · Skill Test (post-play)
└─ top bar: streak 🔥 · coins · Achievements · Shop · Settings · Help · Share
```

---

## 3. Technical architecture

### 3.1 Constraints (do not violate)

- **Deployment target iOS 16.6, iPad only, landscape only.** Don't change any of these.
- **Forbidden APIs** (they need iOS 17+): `@Observable`, the `Observation` framework, SwiftData, `.onChange(of:initial:_:)` (the two-parameter form), `.sensoryFeedback`, `ContentUnavailableView`, `PhaseAnimator`, `KeyframeAnimator`, `.scrollPosition`, `.containerRelativeFrame`, `#Preview` with macro-only features. Use `ObservableObject` + `@Published`, `.onChange(of:) { newValue in }`, `withAnimation`, and `ScrollViewReader`.
- **Allowed and recommended:** `NavigationStack`, `TimelineView(.animation)`, `Canvas`, `Grid`, `ImageRenderer`, `ShareLink`, `CADisplayLink`, `Task.sleep(nanoseconds:)`.
- **Persistence stays `UserDefaults`.** Follow the `ProgressStore` / `AchievementStore` pattern: an `ObservableObject` singleton with `static let shared`.
- **Navigation:** one `NavigationStack` through `AppRouter`. New screens are new `Route` cases plus a `destination(for:)` mapping.
- iPads mostly have **no haptics**. Don't build features around them.

### 3.2 Target folder layout (new files only)

```
Melodissimo/
  Navigation/AppRouter.swift            (Route + AppRouter, moved out of DashboardView)
  Models/Music/Note.swift                (NoteCatalog: the single source of truth for 32 keys)
  Models/Music/SongLibrary.swift         (Song metadata, slug, solemn flag)
  Models/Music/SongChart.swift           (rhythm chart model + loader + default generator)
  Models/Game/PausableClock.swift
  Models/Game/Judge.swift
  Models/Game/SeededRandom.swift
  Models/Game/PlayModels.swift           (StageMode, PlayRequest, PlayResult, RewardSummary)
  Models/Game/BattleConfig.swift
  Models/Game/EchoConfig.swift
  Models/Campaign/Campaign.swift         (Chapter, Stage, CampaignCatalog)
  Models/Progress/ProgressStore+Game.swift  (new keys: songs, stages, coins, shop, settings)
  Models/Shop/ShopCatalog.swift
  Services/ResultRecorder.swift          (applies a PlayResult → progress, coins, achievements)
  Services/SFX.swift                     (no-op when a sound file is missing)
  ViewModels/Stage/RhythmEngine.swift
  ViewModels/Battle/BattleViewModel.swift
  ViewModels/Echo/EchoViewModel.swift
  Views/Stage/  SongStageView, NoteHighwayView, StageSetupView, StageResultView, ChartRecorderView
  Views/Battle/ BattleView, MonsterSprite
  Views/Echo/   EchoView
  Views/Campaign/ CampaignMapView, StageNodeView, StageSheetView, StoryCardView
  Views/FreePlay/ FreePlayView
  Views/Shop/   ShopView
  Views/Settings/ SettingsView
  Views/Common/ AssetImage (image with emoji/SF-Symbol fallback), CoinBadge, HeartsView
  Data/Charts/chart_<slug>.json
MelodissimoTests/  (unit tests; target created in Task 0.1)
```

### 3.3 The note table (NoteCatalog)

Use this exact table. `id` values are persisted and used by `LevelModel.answer`, so **never renumber them**. `semitone` 0 = F3. For MIDI (mic mode), use `53 + semitone`.

| id | label | sound | semitone | | id | label | sound | semitone |
|---|---|---|---|---|---|---|---|---|
| 1 | `4.` | f1 | 0 | | 20 | `4.#` | f1s | 1 |
| 2 | `5.` | g1 | 2 | | 21 | `5.#` | g1s | 3 |
| 3 | `6.` | a1 | 4 | | 22 | `6.#` | a1s | 5 |
| 4 | `7.` | b1 | 6 | | 23 | `1#` | c2s | 8 |
| 5 | `1` | c2 | 7 | | 24 | `2#` | d2s | 10 |
| 6 | `2` | d2 | 9 | | 25 | `4#` | f2s | 13 |
| 7 | `3` | e2 | 11 | | 26 | `5#` | g2s | 15 |
| 8 | `4` | f2 | 12 | | 27 | `6#` | a2s | 17 |
| 9 | `5` | g2 | 14 | | 28 | `1˙#` | c3s | 20 |
| 10 | `6` | a2 | 16 | | 29 | `2˙#` | d3s | 22 |
| 11 | `7` | b2 | 18 | | 30 | `4˙#` | f3s | 25 |
| 12 | `1˙` | c3 | 19 | | 31 | `5˙#` | g3s | 27 |
| 13 | `2˙` | d3 | 21 | | 32 | `6˙#` | a3s | 29 |
| 14 | `3˙` | e3 | 23 | | | | | |
| 15 | `4˙` | f3 | 24 | | | | | |
| 16 | `5˙` | g3 | 26 | | | | | |
| 17 | `6˙` | a3 | 28 | | | | | |
| 18 | `7˙` | b3 | 30 | | | | | |
| 19 | `1˙˙` | c4 | 31 | | | | | |

```swift
struct Note: Identifiable, Hashable {
    let id: Int          // 1...32 — persisted, never renumber
    let label: String    // not angka label, e.g. "5.", "1˙", "4#"
    let sound: String    // m4a resource name
    let semitone: Int    // 0 = F3 (pitch order; use for "nearest", random walks, MIDI = 53 + semitone)
    var isBlack: Bool { id >= 20 }
}
enum NoteCatalog {
    static let all: [Note]                       // the table above
    static func note(_ id: Int) -> Note          // precondition: valid id
    static func id(forLabel: String) -> Int?
    static let whiteKeyIDs = Array(1...19)
    static let blackKeyIDs = Array(20...32)
}
```

### 3.4 Persistence keys

**Existing keys. Never rename, remove or change their type:**
`currentLevel`, `Level1`…`Level100`, `bestScore_notation_<n>`, `bestCombo`, `currentStreak`, `longestStreak`, `lastPlayedDate`, `achievement_<id>`, `<songTitle>` (trophy bool, keyed by exact song title), `isPreplayDone`, `preplayScore`, `postplayScore`.

**New keys** (all accessed through `ProgressStore`):

| Key | Type | Meaning |
|---|---|---|
| `song_bestScore_<slug>` | Int | best Perform score |
| `song_bestAccuracy_<slug>` | Double | best Perform accuracy 0–100 |
| `song_stars_<slug>` | Int | best Perform stars (after the speed cap) |
| `song_practiced_<slug>` | Bool | Practice completed at least once |
| `song_fullCombo_<slug>` | Bool | |
| `stage_stars_<stageId>` | Int | campaign stage best stars |
| `campaign_grantedChapter` | Int | migration result (0 = not yet run) |
| `coins_earnedTotal`, `coins_spentTotal` | Int | balance = earned − spent |
| `shop_owned` | [String] | item ids |
| `equip_keyboard`, `equip_notes`, `equip_outfit` | String | item ids |
| `daily_done_<yyyyMMdd>` | Bool | |
| `rush_highScore`, `echo_highScore` | Int | |
| `stat_bossesDefeated`, `stat_fullCombos`, `stat_songsPerformed`, `stat_echoBestRounds` | Int | achievement stats |
| `settings_approachTime` | Double | seconds a note takes to fall (default 2.0) |
| `settings_audioOffsetMs` | Int | default 0, range −150…+150 |
| `settings_labelsInPerform` | Bool | default false |

Song **slug**: lowercase the title and replace every run of non-alphanumeric characters with `-`. Example: `"Halo Halo Bandung"` → `halo-halo-bandung`.

### 3.5 Shared play models

```swift
enum StageMode: String, Hashable, Codable { case listen, practice, perform }

/// What to play. One route (.play) launches any mode; campaignStageId routes the result back to the map.
struct PlayRequest: Hashable {
    enum Kind: Hashable {
        case song(songId: String, mode: StageMode, speed: Double, isBoss: Bool, isSolemn: Bool, noteLimit: Int?)
        case battle(BattleConfig)
        case classic(levelNo: Int)        // old 100-level grid, rendered by BattleView
        case echo(EchoConfig)
        case rush
        case daily(dateKey: String)
    }
    let kind: Kind
    var campaignStageId: String? = nil
}

struct PlayResult: Hashable {
    let request: PlayRequest
    let didWin: Bool
    let stars: Int                 // 0...3, already speed-capped
    let score: Int
    let accuracy: Double?          // songs only
    let maxCombo: Int
    let perfect, great, good, miss, wrong: Int   // zeros for non-song modes
}

struct RewardSummary: Hashable {
    var coins = 0
    var newStars = 0
    var isNewBest = false
    var newAchievements: [String] = []   // titles
}
```

`ResultRecorder.record(_ result: PlayResult) -> RewardSummary` is the **only** place that writes progress after a play. It is called once, before pushing `.result(PlayResult, RewardSummary)`. It also calls `ProgressStore.shared.recordCombo`, `registerPlayToday()` and `AchievementStore.shared.evaluate()`.

### 3.6 Rhythm engine design (Phase 1–2)

- **Chart format** (`Data/Charts/chart_<slug>.json`), with beats as Doubles:
  ```json
  { "id": "berkibarlah-benderaku", "title": "Berkibarlah Benderaku", "bpm": 96,
    "notes": [ { "k": 9, "b": 0, "d": 1 }, { "k": 9, "b": 1, "d": 0.5 } ] }
  ```
  `k` = key id, `b` = start beat, `d` = duration in beats. If no JSON exists, `SongChart.defaultChart(for:)` generates one from the song's `answer` array with `b = index`, `d = 1`, `bpm = 90`. Practice mode works perfectly with default charts. Perform is playable but not musical until a real chart exists (Task 2.5/2.6).
- **Time:** `noteTime = b × 60 / (bpm × speed)`. Use the host clock `CACurrentMediaTime()`. The song clock starts at `−countIn` (3 beats), so the countdown is just `songTime < 0`.
- **Engine loop:** a `CADisplayLink` calls `engine.step(now:)` at 60–120 Hz. `step` handles auto-misses, wait-mode freezing, Listen autoplay and finish detection. It **publishes only when something happens**: a judgment, a combo change or a phase change. `songTime` is **not** `@Published`.
- **Rendering:** `TimelineView(.animation) { Canvas { … } }` reads `engine.songTime(now:)` and `engine.notes` each frame and draws every note in one `Canvas`. **Never one SwiftUI view per note.**
- **Lanes:** the keyboard reports each key's **global** frame. The highway converts them with its own global `minX`, so `laneX = keyFrame.minX − highwayGlobalMinX`.
- **Note y:** `hitY − (note.time − t) / approachTime × hitY`, where `hitY` is the hit line's y inside the highway. Note length = `max(24, duration / approachTime × hitY × 0.9)`.
- **Input:** `engine.press(keyId:, now:)` is called on key **down**, including sliding into a key. Audio offset: `t − offsetMs/1000`.
- **Lifecycle:** stop the display link in `onDisappear`, because `CADisplayLink` retains its target. Auto-pause when `scenePhase != .active`.

```swift
struct PausableClock {
    private(set) var banked: Double = 0          // song-seconds accumulated while paused/frozen
    private var runningSince: CFTimeInterval?    // host time of last start/resume
    var isRunning: Bool { runningSince != nil }
    func time(at now: CFTimeInterval) -> Double { runningSince.map { banked + (now - $0) } ?? banked }
    mutating func start(at now: CFTimeInterval, from t: Double) { banked = t; runningSince = now }
    mutating func pause(at now: CFTimeInterval) { banked = time(at: now); runningSince = nil }
    mutating func freeze(at t: Double) { banked = t; runningSince = nil }   // practice wait
    mutating func resume(at now: CFTimeInterval) { if runningSince == nil { runningSince = now } }
}

enum Judgment: String, Codable, CaseIterable { case perfect, great, good, miss }
enum Judge {
    static let perfect = 0.070, great = 0.130, good = 0.200
    static func judge(delta: Double) -> Judgment? {
        switch abs(delta) {
        case ...perfect: return .perfect
        case ...great: return .great
        case ...good: return .good
        default: return nil
        }
    }
}
```

**Press matching (Perform):** take the unjudged notes with `|note.time − t| ≤ Judge.good`. Choose the earliest one whose `keyId` matches and judge it by `t − note.time`. If none matches, it is a **wrong press**.

**Practice:** when the next unjudged note reaches the hit line (`t ≥ note.time`), `clock.freeze(at: note.time)`. A correct press marks the note hit and resumes the clock. A wrong press increments `wrongPresses`. Set `hintKeyId` after 2 wrong presses or 3 s.

**Listen:** when `t ≥ note.time` for the next note, call `playSound(key:)`, set `hintKeyId` for the note's duration, and stop the previous note's sound.

---

## 4. Executor rules (for Sonnet)

1. **One task per session.** Read §3 and the task in full. Read every file listed under **Touches** before editing.
2. **Don't break persistence.** See §3.4. Never rename or remove existing keys or change note ids.
3. **Respect §3.1** (iOS 16.6, landscape iPad, forbidden APIs).
4. **Match the codebase style:** `Color.darkGreen` / `.yellow` / `.navy`, `.font(.custom("BalooDa-Regular", size:))` for big numbers and titles, rounded buttons styled like the existing "< Back" and "?" buttons, `router.push` / `router.pop`, and singletons for stores. Short `///` doc comments on new types, like the existing code.
5. **Localization:** write UI strings in English (`Text("Perfect!")`). Add an Indonesian line for **every** new user-facing string to `Melodissimo/Data/id.lproj/Localizable.strings`. Outside `Text`, use `NSLocalizedString("…", comment: "")`.
6. **Testable logic:** anything under `Models/` must not import SwiftUI or UIKit, except `Foundation` and `QuartzCore` for `CACurrentMediaTime`. Add unit tests in `MelodissimoTests/` for every logic file listed in the task.
7. **Adding files:** if Task 0.1 converted the project to folders, creating a file on disk is enough. If not, register each new file in `project.pbxproj` (PBXFileReference + PBXBuildFile + group child + Sources/Resources phase entry, copying an existing entry's pattern) and confirm it builds.
8. **Verify before finishing:**
   ```bash
   xcodebuild -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'generic/platform=iOS Simulator' build -quiet
   ```
   ```bash
   xcodebuild test -project Melodissimo.xcodeproj -scheme Melodissimo -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -quiet
   ```
   If that simulator name doesn't exist, run `xcrun simctl list devices available | grep iPad` and pick one. Zero errors. Add no new warnings.
   If you have the iOS Simulator tool, launch the app and screenshot the screens from the task's **Manual QA** list. Otherwise list those checks for the user.
9. **Finish:** tick the task's checkbox in this file, then `git add -A && git commit -m "Task X.Y: <title>"`.
10. **When the plan conflicts with the code,** don't improvise a redesign. Make the smallest reasonable choice and record it under **§8 Executor notes**.
11. **Stay in scope.** Don't refactor unrelated files. Old screens being replaced stay in place until Task 7.4 removes them.

**Session prompt for the user to paste:**
```
Read GAME_PLAN.md: sections 3 and 4 fully, then Task <X.Y>.
Execute Task <X.Y> only, following the Executor rules.
For tasks marked ⚠︎, write a short plan first and wait for my OK before coding.
Finish with: build + tests passing, checkbox ticked, commit, and a list of things I should check by hand.
```

---

## 5. Phases & tasks

### Phase 0 — Foundation

#### Task 0.1 — [USER, manual in Xcode] Project prep (~10 min)
- [x] done (executed by Claude by editing `project.pbxproj`; see §8)
1. Commit the pending version bump: `git add -A && git commit -m "Bump version to 1.3"`.
2. Create a branch: `git checkout -b game/konser-nusantara`.
3. In Xcode's navigator, right-click the yellow **Melodissimo** group → **Convert to Folder**. Accept the conversion of subgroups. Build with ⌘B.
   - If the build fails with *"Multiple commands produce …/Info.plist"*: select `Data/Info.plist` → File Inspector → uncheck Target Membership.
   - If Xcode refuses because a group doesn't match a folder, skip this step. Sonnet will then follow rule 7's fallback.
4. **File → New → Target → iOS → Unit Testing Bundle.** Name: `MelodissimoTests`, Testing System: **XCTest**, Target to be Tested: Melodissimo. Make sure it is in the Melodissimo scheme's Test action, which is the default.
5. Run the test command from §4.8 once and confirm the template test passes.
6. Commit: `"Task 0.1: folders + test target"`.

#### Task 0.2 — NoteCatalog + move router
- [x] done

**Touches:** new `Models/Music/Note.swift`, new `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`, `Models/Level/LevelFeederModel.swift`, `ViewModels/Tiles/TilesViewModel.swift`, `Views/Component/TilesComponentView.swift`.

1. Create `NoteCatalog` exactly as in §3.3.
2. Replace the three duplicated `idMappings` dictionaries in `LevelFeederModel` with `NoteCatalog`. **Keep identical behaviour.** Note pools: the notation and postplay levels use ids 1–32; preplay uses 1–19. Keep using `UserDefaults` keys `LevelN`.
3. Replace `TilesViewModel.getStringRepresentation`'s switch with `NoteCatalog.note(id).label`, keeping the method signature.
4. Build the keyboard's `whiteRow` / `blackRow` key lists from `NoteCatalog`. **Keep the black-key grouping and spacing exactly as they are.**
5. Move `Route` and `AppRouter` unchanged into `Navigation/AppRouter.swift`.

**Tests (`NoteCatalogTests`):**
- 32 unique ids, labels and sounds.
- Every sound resource exists in the bundle (`Bundle.main.url(forResource:withExtension:"m4a")`).
- `semitone` values form 0…31 with no duplicates.
- For each of the 18 songs, `question.map(NoteCatalog.id(forLabel:)) == answer`.

**Done when:** the app looks and behaves exactly as before, and all tests pass.

#### Task 0.3 — Audio upgrade
- [x] done

**Touches:** `Models/Sound/SoundModel.swift`, `MelodissimoApp.swift`.

1. Add `preloadAllSounds()`, which warms `playerCache` for all 32 notes. Call it once at launch on a background queue, then hop to main to store the players.
2. In `configureAudioSessionIfNeeded()`, add `try? session.setPreferredIOBufferDuration(0.005)` for lower latency.
3. Add `stopSound(key:)`, which stops that note's player only. Keep `playSound(key:)` and `stopSound()` working for existing callers.

**Done when:** the first tap on any key plays instantly, and two different keys can sound at once when triggered back-to-back from code.

#### Task 0.4 — ⚠︎ Multi-touch keyboard + public keyboard API
- [ ] done

**Touches:** `Views/Component/TilesComponentView.swift`, `Data/id.lproj/Localizable.strings`, `Data/en.lproj/Localizable.strings`, `Views/Help/HelpPageView.swift`.

The current `DragGesture` tracks one finger. In fast passages kids overlap fingers, so the second key is lost. That breaks a rhythm game.

1. Add `MultiTouchKeySurface: UIViewRepresentable` as an `.overlay` on the keyboard `ZStack`, which already has `.coordinateSpace(name: "keyboard")`. That makes the UIView's local coordinates equal "keyboard" space.
   - The `UIView` has `isMultipleTouchEnabled = true` and a clear background.
   - It tracks `[ObjectIdentifier(UITouch): Int]`, mapping each touch to the key it is on.
   - **Hit-test black keys first.**
   - On `touchesBegan` and on sliding into a new key: `onKeyDown(id)`.
   - On sliding out: `onKeyUp(oldId, isRelease: false)`.
   - On `touchesEnded`: `onKeyUp(id, isRelease: true)`.
   - On `touchesCancelled`: `onKeyUp(id, isRelease: false)`.
   - Remove the old `DragGesture`.
2. Replace `activeTileID: Int?` with `activeTileIDs: Set<Int>`. Sound: down → `playSound(key:)`, up → `stopSound(key:)`.
3. Extract an internal, reusable `PianoKeyboard` view:
   ```swift
   struct PianoKeyboard: View {
       var metrics: PianoMetrics
       var showLabels: Bool
       var highlights: [Int: Color] = [:]          // key id → tint (hint glow / correct / wrong flash)
       var playsSound = true                        // false for mic mode / autoplay-driven visuals
       var onNoteOn: ((Int) -> Void)? = nil         // key down (touch begin or slide in)
       var onNoteOff: ((_ id: Int, _ isRelease: Bool) -> Void)? = nil
       var onKeyFrames: (([Int: CGRect]) -> Void)? = nil   // GLOBAL frames, reported on layout change
       var pressedFromOutside: Set<Int> = []        // keys shown pressed by autoplay
   }
   ```
4. Add `PianoMetrics.stage`: `whiteHeight 230, blackHeight 145, containerHeight 290, whiteRowHeight 290, blackRowHeight 230`.
5. Re-implement `PianikaStackLearning`, `PianikaStackLearningMini`, `PianikaStackQuiz` and `PianikaStackQuizMini` on top of `PianoKeyboard`. Quiz wrappers call `viewModel.addAnswer(id)` on `onNoteOff(id, isRelease: true)`, so the answer still registers on lift.
6. In Help, update the "press at least 2 seconds" and "can't press more than one tile" FAQ answers in **both** `.strings` files and in `HelpPageView`.

**Manual QA:**
- Two fingers held on two keys both sound and both look pressed.
- Gliding still switches notes.
- Notation quiz, song quiz, preplay and postplay still work and answer on lift.

### Phase 1 — Rhythm core (logic only)

#### Task 1.1 — SongLibrary + SongChart
- [x] done

**Touches:** new `Models/Music/SongLibrary.swift`, new `Models/Music/SongChart.swift`, new `Data/Charts/` folder (empty plus a `.gitkeep`, or one sample chart).

1. Define `Song { id (slug), title, notationImage, keyIds: [Int], isSolemn }` and `SongLibrary.all`, built from `LevelFeederModel.shared.songLevel`. `isSolemn` is true for `Indonesia Raya` and `Mengheningkan Cipta`. Add `SongLibrary.song(id:)` and `song(title:)`.
2. `SongChart: Codable` uses the format in §3.6. Add `SongChart.load(for song:) -> SongChart`: use the bundle JSON `chart_<slug>.json` if present, otherwise `defaultChart(for:)`.
3. Add `func timedNotes(speed: Double) -> [TimedNote]`, where `TimedNote { index, keyId, time, duration }` is in seconds.

**Tests:** slug examples; all 18 songs load; the default chart has `notes.count == answer.count` with increasing beats; `timedNotes(speed: 0.5)` doubles the times; a hand-written JSON chart round-trips through decoding.

#### Task 1.2 — Clock, Judge, RhythmEngine (no UI)
- [x] done

**Touches:** new `Models/Game/PausableClock.swift`, new `Models/Game/Judge.swift`, new `ViewModels/Stage/RhythmEngine.swift`.

1. Implement `PausableClock` and `Judge` from §3.6.
2. Implement `RhythmEngine: ObservableObject` with:
   - `init(chart:mode:speed:approachTime:audioOffsetMs:)`
   - `phase` (`.ready / .countIn / .playing / .paused / .finished`)
   - `start(now:)`, `pause(now:)`, `resume(now:)`, `restart(now:)`
   - `songTime(now:)`, `press(keyId:now:)`, `step(now:)`
   - published `score, combo, maxCombo, counts, wrongPresses, hintKeyId, phase`
   - non-published `notes: [EngineNote]` (TimedNote + `judgment: Judgment?`)
   - `recentEvents: [(keyId, Judgment?, hostTime)]` for popups, keeping the last 8
   - computed `accuracy` and `stars(speedCapped:)` from the §2.2 formulas
   - a small `DisplayLinkTicker` class (`CADisplayLink`, target/selector, `.common` run-loop mode) that calls `step(now: link.timestamp)`, plus `attachTicker()` / `detachTicker()`
   - every time-based method takes `now: CFTimeInterval`, so tests can drive time without a display link
3. Implement Perform, Practice and Listen exactly as described in §3.6. Listen calls `playSound` through an injectable closure `soundPlayer: (String) -> Void`, so tests don't play audio.

**Tests (`RhythmEngineTests`), driven by fake `now` values:**
- perfect / great / good / miss boundaries
- a wrong key gives a wrong press and resets combo
- an untouched note becomes a Miss after `time + 0.2`
- practice freezes at the note time and resumes after a correct press
- finishes after the last note
- accuracy, star and speed-cap math
- combo multiplier steps at 10, 20 and 30

### Phase 2 — Song Stage (ships as v2.0)

#### Task 2.1 — ⚠︎ Note highway + minimal Perform stage
- [ ] done

**Touches:** new `Views/Stage/NoteHighwayView.swift`, new `Views/Stage/SongStageView.swift`, new `Models/Game/PlayModels.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

1. Add `PlayModels.swift` (§3.5) and `Route.play(PlayRequest)`. Map `.song` to `SongStageView`. Add a **temporary** DEBUG-only button on Home that plays "Berkibarlah Benderaku" in Perform mode.
2. `NoteHighwayView(engine:, keyFrames:, labelsOnNotes: true)` is built from `TimelineView(.animation)` and one `Canvas`. It draws:
   - faint lane separators
   - the hit line
   - visible notes (time window `[t − 0.3, t + approachTime]`): white-key notes in yellow, black-key notes in navy, label text inside
   - hit notes vanish
   - missed notes turn grey and keep falling
3. `SongStageView` layout: HUD row (72 pt, placeholder) / highway (flexible) / `PianoKeyboard(metrics: .stage, showLabels: false)`. Feed `onKeyFrames` to the highway. Feed `onNoteOn` to `engine.press`. Start the engine in `onAppear` and detach the ticker in `onDisappear`.

**Manual QA:**
- Notes line up exactly with their keys on iPad mini **and** iPad Pro 13".
- Hitting on time removes notes.
- Smooth 60 fps (Xcode's FPS gauge, or no visible stutter).

#### Task 2.2 — HUD, count-in, pause
- [ ] done

**Touches:** `Views/Stage/SongStageView.swift`, `Data/id.lproj/Localizable.strings`.

- **HUD:** pause button, song title, score (`.contentTransition(.numericText())`), combo (shown when ≥ 2), and a thin progress bar (judged / total).
- **Count-in:** a big 3-2-1 overlay while `songTime < 0`.
- **Judgment popups:** drawn in the Canvas from `recentEvents` ("Perfect!" / "Great" / "Good" / "Miss"), rising and fading over 0.5 s at the lane's x. Use **both** text and colour.
- **Pause overlay:** Resume / Restart / Quit (`router.pop()`).
- Auto-pause on `scenePhase` change.

#### Task 2.3 — Practice + Listen + speed + Stage setup
- [ ] done

**Touches:** new `Views/Stage/StageSetupView.swift`, `Views/Stage/SongStageView.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

1. `StageSetupView(song:)` shows the title, a thumbnail of the notation image, best stars, best accuracy and a ✓ when Practice is done. It has three big buttons:
   - **Listen**
   - **Practice**
   - **Perform**, locked with a 🔒 hint until `song_practiced_<slug>`
   
   It also has a speed segmented picker (0.5× / 0.75× / 1×) and a "Show key labels" toggle, which defaults to on for Practice and to the setting for Perform. Add `Route.stageSetup(songId:)`.
2. In SongStageView:
   - Practice shows key labels and `highlights[hintKeyId] = .yellow`, and flashes the pressed key red on a wrong press.
   - Listen drives `pressedFromOutside` from the engine's autoplay. At the end it offers "Try Practice →".
3. **Solemn songs:** no combo text, calm background (`Color.vanila` plus an `flag.fill` SF Symbol watermark) and no popups except a subtle ✓.

#### Task 2.4 — Results + persistence + menu integration
- [ ] done

**Touches:** new `Services/ResultRecorder.swift`, new `Models/Progress/ProgressStore+Game.swift`, new `Views/Stage/StageResultView.swift`, `Views/Song/Quiz/SongRepositoryQuizView.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

1. Add the song keys from §3.4 to `ProgressStore+Game.swift`.
2. `ResultRecorder.record`, songs only for now:
   - update bests and stars
   - set the practiced flag
   - set the full-combo flag and `stat_fullCombos`
   - increment `stat_songsPerformed`
   - **on 3★, also set the legacy trophy bool** (`UserDefaults.standard.set(true, forKey: song.title)`)
   - call `recordCombo`, `registerPlayToday()` and `AchievementStore.shared.evaluate()`
   - return a `RewardSummary` with coins = 0 for now
3. `StageResultView(result:, rewards:)` shows:
   - stars, popping in one by one
   - score, accuracy and max combo
   - the P/G/Good/Miss/Wrong breakdown
   - a "New best!" tag and a FULL COMBO badge
   - confetti on 3★ (ConfettiSwiftUI, already a dependency)
   - buttons: Retry, Song menu, and "Next" when launched from the campaign (no-op until Phase 5)
   
   Add `Route.result(PlayResult, RewardSummary)`.
4. `SongRepositoryQuizView`: tapping a song card pushes `.stageSetup(songId:)` instead of `.songQuiz`. Show stars under each card. **Keep the trophy shelf.** Rename the menu label "Song Quiz" to **"Song Stage"** in the UI and in `id.lproj`.
5. Remove the DEBUG button from Task 2.1.

**Done when:** the full loop works for all 18 songs (setup → practice → perform → results → back), and progress survives an app relaunch.

#### Task 2.5 — Chart Recorder (DEBUG-only tool)
- [ ] done

**Touches:** new `Views/Stage/ChartRecorderView.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

Use this tool to author real rhythm charts by playing along.

- It is reachable only in `#if DEBUG`, through a long-press on the Home title.
- Pick a song, set the BPM with a slider (60–160), and choose the grid (1/2 or 1/4 beat).
- A visual metronome (a flashing dot each beat) runs from a 4-beat count-in.
- The screen shows the **expected next note label** big. The user plays the melody on the keyboard (`PianoKeyboard`). Each key-down records `(hostTime, keyId)`. If the key doesn't match the expected id, flash red and ignore it.
- On Stop, quantize:
  - `b_i = round((t_i − t_0) / spb / grid) × grid`
  - force strictly increasing beats by pushing collisions +grid
  - `d_i = b_{i+1} − b_i`, and the last note gets 2
- Output pretty-printed JSON (sorted keys) in three ways:
  - `print` to the console
  - copy to `UIPasteboard`
  - write to `Documents/chart_<slug>.json`
- Show the path and add a **"Preview"** button that runs the new chart in Listen mode.
- Find the file with `xcrun simctl get_app_container booted com.balqishafiraini.Melodissimo data`, then look in `Documents/`.

#### Task 2.6 — [USER] Record charts for the 18 songs
- [ ] done

- For each song, record with the tool, preview it in Listen, and save it to `Melodissimo/Data/Charts/chart_<slug>.json`. Commit in batches.
- **Optional shortcut:** ask Sonnet to draft charts by reading the score-sheet PNGs in `Assets.xcassets/Notasi/`. In *not angka*, underlines mark eighth notes, dots extend a note and bar lines divide the measures. Treat these drafts as **unverified until you have checked every one in Listen mode**.

### Phase 3 — Note Battle + Melody Rush (v2.1)

#### Task 3.1 — Battle logic
- [ ] done

**Touches:** new `Models/Game/SeededRandom.swift`, new `Models/Game/BattleConfig.swift`, new `ViewModels/Battle/BattleViewModel.swift`.

```swift
struct SeededRandom: RandomNumberGenerator {   // SplitMix64
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

struct BattleConfig: Hashable {
    var newPool: [Int]            // key ids
    var reviewPool: [Int] = []
    var newWeight = 0.7           // probability of drawing from newPool when reviewPool not empty
    var questionCount: Int        // Int.max for endless (Rush)
    var timePerNote: Double?      // nil = no timer
    var hearts = 3
    var isBoss = false
    var fixedQuestions: [Int]? = nil   // classic levels: exact sequence from LevelModel.answer
    var seed: UInt64
}
```

`BattleViewModel` must:
- generate questions with **no immediate repeats**
- run a timer through `step(now:)` (`Timer` at 20 Hz in the view, injectable `now` for tests)
- handle `answer(keyId:)`; after a wrong answer, **re-ask the same question** (§2.2B)
- handle timeout as a wrong answer
- for boss battles, shrink the timer 5 % per correct answer
- track `monsterHP, hearts, combo, maxCombo, score, phase (.playing/.won/.lost)`
- expose `revealKeyId`, set for 0.8 s after a mistake

Rush mode is `BattleConfig.rush` with the interval rules from §2.2C, an infinite count, and score = correct × 10 × multiplier.

**Tests:** determinism with a seed; no immediate repeats; a wrong answer re-asks the same note; first-try correct count; the 70/30 weighting stays within ±10 % over 1,000 draws; win/lose transitions; stars = hearts; the Rush interval schedule.

#### Task 3.2 — ⚠︎ Battle UI
- [ ] done

**Touches:** new `Views/Battle/BattleView.swift`, new `Views/Battle/MonsterSprite.swift`, new `Views/Common/AssetImage.swift`, new `Views/Common/HeartsView.swift`.

- `AssetImage(name:, fallbackEmoji:)` shows the asset if `UIImage(named:)` exists, otherwise the emoji at the same size. Placeholders: minion `👾`, boss `🐲`.
- **Layout:**
  - top bar: back, hearts, combo, score
  - **arena:** Alpanica on the left (`alpanica`, or `alpanicaSad` for 0.8 s after a hit taken); the monster on the right with an HP bar and a speech bubble holding the question label in Baloo 70 pt; a timer bar under the bubble
  - bottom: `PianoKeyboard(metrics: .full, showLabels: false, highlights: reveal → .green)`
- **Animations** (`withAnimation`, offsets):
  - correct: Alpanica hops, the monster shakes and turns red, and a "−1" floats up
  - wrong: the monster lunges and the screen nudges 8 pt (skip when Reduce Motion is on)
- At the end, build a `PlayResult` → `ResultRecorder` → `.result`. `StageResultView` adapts: hearts instead of an accuracy breakdown.

#### Task 3.3 — Classic levels use Battle
- [ ] done

**Touches:** `Views/Notation/Quiz/NotationQuizLevelMenuView.swift`, `Services/ResultRecorder.swift`, `Views/Battle/BattleView.swift`.

- Level-grid buttons push `.play(PlayRequest(kind: .classic(levelNo:)))`. BattleView builds the config with `fixedQuestions = level.answer`, `timePerNote = nil` for levels ≤ 10 and `max(3, 6 − levelNo × 0.03)` above that, and `isBoss = levelNo % 5 == 0`.
- **ResultRecorder for `.classic` keeps the legacy storage.** Score% = first-try correct / total × 100 → `ProgressStore.recordScore(category: "notation", …)`, so grid stars still use 60/80/100. **A win → `unlock(upToLevel:)`.** This is deliberately more forgiving than today: `NotationQuizCorrectAnswerView` unlocks only on zero mistakes, while a win here allows up to 2. Existing achievements keep working because they read the same keys.
- Old `NotationQuizView` and the correct/incorrect/five-level views are no longer routed to. Leave the files in place for now.

#### Task 3.4 — Melody Rush entry + high score
- [ ] done

**Touches:** new `Views/FreePlay/FreePlayView.swift`, `Models/Progress/ProgressStore+Game.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

- Add `rush_highScore` and a "NEW HIGH SCORE" state on results.
- Create `FreePlayView`: Songs (→ song list) · Classic Levels (→ existing grid) · Echo (disabled until Phase 4) · Melody Rush.
- Add a Home button for it.

### Phase 4 — Echo (v2.1)

#### Task 4.1 — Echo logic
- [ ] done

**Touches:** new `Models/Game/EchoConfig.swift`, new `ViewModels/Echo/EchoViewModel.swift`.

```swift
struct EchoConfig: Hashable {
    var pool: [Int]              // key ids
    var roundsToClear: Int?      // nil = endless
    var startLength = 2
    var maxLength = 8
    var glowDuringPlayback = true
    var useSongSnippets = false  // later rounds take contiguous slices of SongLibrary songs fully inside pool
    var hearts = 3
    var seed: UInt64
}
```

- **Phrase generator:** sort the pool by `semitone`. Start at a random index. Each next note moves by a random step in −2…+2 (0 at most once in a row), clamped to the pool.
- **Length:** `startLength + round / 2`, capped at `maxLength`.
- **ViewModel phases:** `.listening(index)` → `.yourTurn(progress)` → `.roundCleared` / `.mistake` → (replay) … → `.won` / `.lost`.
- **Playback:** one note every 0.6 s through the injectable sound closure.

**Tests:** phrases stay in the pool; steps ≤ 2 positions; determinism; the length schedule; heart loss and replay; the win condition.

#### Task 4.2 — Echo UI
- [ ] done

**Touches:** new `Views/Echo/EchoView.swift`, `Views/FreePlay/FreePlayView.swift`, `Models/Progress/ProgressStore+Game.swift`.

- The top shows a big status: 👂 "Listen…" / 🎹 "Your turn!" plus dots for phrase progress.
- The keyboard has labels **off**. Played-back keys glow when `glowDuringPlayback` is on. Correct notes flash green and show the label briefly above the key.
- Enable Echo in Free Play as an endless mode with `echo_highScore` and `stat_echoBestRounds`.

### Phase 5 — Nusantara Tour campaign (v3.0)

#### Task 5.1 — Campaign catalog + progress
- [ ] done

**Touches:** new `Models/Campaign/Campaign.swift`, `Models/Progress/ProgressStore+Game.swift`.

- Model `Chapter { number, name, newNotes, songTitles, bossSongTitle, finaleSongTitle?, timer, symbol (SF Symbol), tint }` from the §2.3 table.
- Model `Stage { id, chapter, index, kind: .battle(BattleConfig) | .echo(EchoConfig) | .song(songId) | .boss(songId) | .finale(songId) }`.
- `CampaignCatalog.chapters` and `stages(in:)` **generate** stages using the §2.3 rule. Use `seed = hash of stage id` so questions are stable.
- SF Symbols per chapter: Sumatra `leaf.fill`, Jawa `building.columns.fill`, Kalimantan `tree.fill`, Sulawesi `sailboat.fill`, Bali & NT `sun.max.fill`, Maluku & Papua `mountain.2.fill`.
- Progress functions: `stageStars(id)`, `isUnlocked(stage)`, `currentStage` (first unlocked stage with 0★) and `runMigrationIfNeeded()` (§2.3).

**Tests:**
- 53 stages with unique ids
- every song and boss stage's notes are ⊆ cumulative notes taught through that chapter (**this proves the curriculum**)
- unlock chain
- migration thresholds

#### Task 5.2 — ⚠︎ Map UI + stage routing
- [ ] done

**Touches:** new `Views/Campaign/CampaignMapView.swift`, new `Views/Campaign/StageNodeView.swift`, new `Views/Campaign/StageSheetView.swift`, `Services/ResultRecorder.swift`, `Views/Stage/StageResultView.swift`, `Navigation/AppRouter.swift`.

- **Map:** a horizontal `ScrollView` of 6 chapter panels, each about 90 % of the screen width, with an ocean-blue background.
  - Each panel shows the island name, its symbol, a stars total, and stage nodes on a zig-zag dashed `Path`.
  - Locked chapters are dimmed with a 🔒 and "Clear <prev boss> to sail here".
  - Use `ScrollViewReader` to auto-scroll to the current chapter.
- **Nodes:** a circle with a kind icon (battle `bolt.fill`, echo `ear.fill`, song `music.note`, boss `crown.fill`, finale `flag.fill`), stars underneath, and a lock state.
- **Alpanica avatar** (equipped outfit) sits on the current node and hops there with a spring animation when a new stage unlocks.
- **Stage sheet** (on node tap): title, kind, best stars, Play. Song, boss and finale stages open `StageSetupView` with `campaignStageId` set.
- **ResultRecorder:** when `campaignStageId != nil`, update `stage_stars_<id>` (max). Results "Next" → `router.pop(to: .campaignMap)`, and the map animates the avatar.

#### Task 5.3 — Boss skin, story cards, new Home
- [ ] done

**Touches:** `Views/Stage/SongStageView.swift`, new `Views/Campaign/StoryCardView.swift`, `Views/Dashboard/DashboardView.swift`, `Models/Progress/ProgressStore+Game.swift`.

- **Boss stage** (`isBoss` in `PlayRequest.song`): a Fals boss sprite top-right with an HP bar, where HP = 1 − (hits weighted by judgment / total). The monster shakes on hits. Defeat = ≥ 1★. Increment `stat_bossesDefeated` on first defeat.
- **Story cards** (2–3 lines, Alpanica plus the monster emoji, a "Continue" button) appear at the first entry to a chapter and after each boss. Write 13 short, kid-friendly lines in English and Indonesian. Track seen cards with `story_seen_<id>`.
- **Finale:** after Indonesia Raya reaches ≥ 1★, show a "Tour Complete" certificate: title, total stars, date, and outfit Alpanica. Offer `ShareLink` of an `ImageRenderer` image.
- **Home redesign** (keep the `dashboard` background):
  - a top bar with streak, coins (placeholder until 6.1), achievements, settings, help and share
  - a big **Nusantara Tour** card showing the current chapter and stage name
  - cards for **Daily** (placeholder until 6.3), **Free Play** and **Learn**
  - Learn is a small hub linking the existing `NotationMenuView` learn path, `SongRepositoryLearnView` and the post-play skill test

### Phase 6 — Meta systems (v3.0)

#### Task 6.1 — Coins
- [ ] done

**Touches:** `Models/Progress/ProgressStore+Game.swift`, `Services/ResultRecorder.swift`, new `Views/Common/CoinBadge.swift`, `Views/Stage/StageResultView.swift`, `Views/Dashboard/DashboardView.swift`.

- Add the earned/spent keys and `balance`, plus `earn(_:)` and `spend(_:) -> Bool`.
- Implement the full §2.4 reward table in `ResultRecorder`.
- Results show "+N 🪙" counting up. Home and the shop show `CoinBadge`.

**Tests:** the reward table, using fresh `UserDefaults(suiteName:)`. Allow `ProgressStore` to take an injected `UserDefaults`, keeping `.standard` as the default for `shared`.

#### Task 6.2 — Shop + skins applied
- [ ] done

**Touches:** new `Models/Shop/ShopCatalog.swift`, new `Views/Shop/ShopView.swift`, `Views/Component/TilesComponentView.swift`, `Views/Stage/NoteHighwayView.swift`, `Views/Battle/BattleView.swift`, `Views/Campaign/CampaignMapView.swift`.

- The catalog follows §2.4. Each item has an id, a category, a price, and a preview (colors or an image name).
- ShopView has tabs per category and a grid of cards with Buy / Equip / Equipped states and a confirm alert on buying.
- **Apply skins:**
  - keyboard body colour and key highlight in `PianoKeyboard`
  - note colours in `NoteHighwayView` (Pelangi = hue from `semitone % 12`)
  - outfit image for Alpanica in Battle, Map and Results

#### Task 6.3 — Daily Challenge
- [ ] done

**Touches:** `Views/Dashboard/DashboardView.swift`, `Services/ResultRecorder.swift`, `Models/Progress/ProgressStore+Game.swift`.

- `seed = UInt64(yyyyMMdd)`. The type rotates as in §2.2E. The note pool = all notes taught up to the player's current campaign chapter (at least chapter 1).
- The Home card shows today's type, the reward and done ✓.
- The reward can be claimed once per date key.

**Tests:** same date → same challenge; different dates → different seeds.

#### Task 6.4 — Settings
- [ ] done

**Touches:** new `Views/Settings/SettingsView.swift`, `Models/Progress/ProgressStore+Game.swift`.

- **Note speed:** approach time 1.5 / 2.0 / 2.5 / 3.0 s.
- **Show key labels in Perform** toggle.
- **Audio offset** slider (−150…+150 ms) with a "Tap to the beat" calibration: 8 metronome flashes, average tap offset, suggested value.
- **Reset progress** (destructive, double confirm): removes every key in §3.4 *except* `LevelN` question sets and `isPreplayDone`.
- About / version.

#### Task 6.5 — New achievements
- [ ] done

**Touches:** `Models/Achievement/AchievementStore.swift`, `Models/Progress/ProgressStore+Game.swift`.

Use Indonesian titles, matching the existing ones.

| Id | Title | Condition |
|---|---|---|
| `first_show` | "Panggung Pertama" | first Perform |
| `full_combo` | "Tanpa Cela" | 1 full combo |
| `golden_ear` | "Telinga Emas" | 10 rounds in Echo |
| `fals_hunter` | "Pemburu Fals" | 3 bosses |
| `sabang_merauke` | "Dari Sabang Sampai Merauke" | finale cleared |
| `rush_100` | "Kilat" | Rush score ≥ 100 |
| `collector` | "Kolektor" | own 3 shop items |

### Phase 7 — Polish (v3.x)

#### Task 7.1 — Game feel
- [ ] done

- Particle burst at the hit line on Perfect: 6–10 small circles in the Canvas, 0.3 s.
- Lane flash on key-down.
- The combo text pulses every 10 combo.
- Stars stamp in on results; the coins counter ticks up.
- Respect `@Environment(\.accessibilityReduceMotion)`: no shake, no particles, fades only.
- **Solemn songs stay calm.**

#### Task 7.2 — Sound effects
- [ ] done

- `SFX.play(_ name:)` loads from the bundle and **silently no-ops if the file is missing**.
- It mixes with note samples. Use separate cached players and a lower volume (0.6).
- Hook up the names from §6. Add an "SFX on/off" toggle to Settings.

#### Task 7.3 — Onboarding, help, localization pass
- [ ] done

- After the pre-play test, guide new players straight to stage `c1-01` with 3 coach-mark bubbles: "These numbers are notes", "Play the key under the falling note", "Stars unlock the next stage".
- Rewrite Help sections for each mode.
- Localize achievement titles (they are currently hardcoded Indonesian) and make sure every new string has an `id.lproj` entry.
- Verify the Indonesian UI on a simulator set to Bahasa Indonesia.

#### Task 7.4 — Cleanup & performance
- [ ] done

- Delete unrouted screens: `NotationQuizView`, the correct/incorrect/five-level views, `SongQuizView`, `SongQuizScoreView` (after moving the trophy write, done in 2.4), and `AfterQuizView` if the preplay/postplay flows no longer use it. **Check every reference with grep first.**
- Delete `TouchLocatingView` / `onTouchDownUp` if unused.
- Profile the Song Stage with Instruments (Time Profiler + Core Animation FPS) on the oldest available iPad simulator, then on a device if possible. It must hold 60 fps with 10+ visible notes.

### Phase 8 — Stretch

#### Task 8.1 — ⚠︎ Real pianika via microphone
- [ ] done

- Add `NSMicrophoneUsageDescription` (en + id).
- **Session:** `.playAndRecord`, mode `.measurement`, options `.defaultToSpeaker`.
- **Engine:** `AVAudioEngine` input tap, buffer 2048, hop 1024.
- **Pitch:** YIN pitch detection (threshold 0.15) limited to 165–1100 Hz. Frequency → MIDI → `semitone = midi − 53` → note id from `NoteCatalog`.
- **Onset:** RMS above a noise gate **and** the same pitch for 2 consecutive frames → `engine.press(keyId:, now: now − detectionLatency)`. A new onset needs a pitch change or silence in between.
- **Mic mode:** `PianoKeyboard(playsSound: false)` with the detected key shown pressed, and all judgment windows +50 ms.
- **Settings:** Input = Touch / Real pianika. Add a calibration screen ("play 1 (C)") that shows the detected note live.
- **Tests:** YIN on synthetic sine buffers at 5 note frequencies (±1 semitone accuracy).

#### Task 8.2 — iCloud sync
- [ ] done

- [USER] Enable the iCloud capability with Key-value storage.
- Mirror the §3.4 progress keys to `NSUbiquitousKeyValueStore`. Merge with `max` for scores, stars, coins totals and stats, and OR for booleans.
- Observe `didChangeExternallyNotification`.

#### Task 8.3 — Game Center
- [ ] done

- [USER] Configure the leaderboards in App Store Connect: Rush high score, Echo best rounds, total stars.
- Authenticate silently and submit on results.
- Check the App Store Kids Category rules before shipping.

---

## 6. Asset requests (for an artist or illustrator)

Everything has a placeholder, so **no task is blocked by art**. Drop files into `Assets.xcassets` with these exact names and they replace the placeholders automatically through `AssetImage`.

**Images** (PNG @2x/@3x or vector PDF/SVG, transparent background):

| Name | Size (pt) | Description |
|---|---|---|
| `fals_minion_1`, `fals_minion_2`, `fals_minion_3` | 300×300 | Cute off-key gremlins. Not scary. Wobbly music-note motifs. |
| `fals_boss_1` … `fals_boss_6` | 420×420 | Fals in a costume per island. Respectful, no sacred or religious items. |
| `alpanica_happy`, `alpanica_attack` | 300×300 | New mascot poses. |
| `map_ocean` | tileable 512×512 | Ocean background. |
| `map_island_1` … `map_island_6` | ~1000×600 | Stylised island silhouettes. |
| `stage_bg_concert`, `stage_bg_ceremony` | 1376×1032 | Stage backgrounds. Ceremony: calm, flag, no characters. |
| `icon_coin` | 64×64 | |

**Sounds** (m4a or caf, under 1 s, normalised; CC0 sources such as Kenney.nl "Interface Sounds" and "Impact Sounds"):
`sfx_perfect`, `sfx_miss`, `sfx_wrong`, `sfx_coin`, `sfx_star`, `sfx_unlock`, `sfx_monster_hit`, `sfx_player_hurt`, `sfx_tick`, `sfx_button`.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Rhythm feels laggy or unfair | Low IO buffer (0.3), key-down input (0.4), generous windows, audio offset calibration (6.4), Practice mode needs no timing. |
| Writing 18 charts is slow | Default uniform charts work on day 1. The recorder tool (2.5) takes minutes per song. Optional AI draft from score sheets plus mandatory checking in Listen. |
| SwiftUI frame drops | One `Canvas`, nothing `@Published` per frame, display-link stepping, profiled in 7.4. |
| Existing players lose progress | Frozen key list (§3.4), classic levels kept, migration grants chapters (5.1), tests. |
| National-song sensitivity | Solemn flag: no monster or comic effects on Indonesia Raya and Mengheningkan Cipta. Lyrics are never shown. Melody only, as today. |
| `project.pbxproj` conflicts | Folder conversion (0.1). One task per commit. |
| Scope creep | Each phase ships on its own. v2.0 = Phases 0–2. |

---

## 8. Executor notes

_(Sonnet: record deviations, decisions and follow-ups here, with the task number.)_

- **0.1** — Done without the Xcode GUI. There was no pending version bump to commit (`MARKETING_VERSION` is still 1.2), so the first commit is just `GAME_PLAN.md` plus an `xcuserdata` plist change that was already modified. The branch `game/konser-nusantara` was cut from `feature/refactor`. The folder conversion was done by rewriting `project.pbxproj` (`xcodebuild` then normalised it to `objectVersion = 70`) with `PBXFileSystemSynchronizedRootGroup` for `Melodissimo/` and `MelodissimoTests/`, with `Data/Info.plist` as a membership exception. **Consequence: the project now needs Xcode 16+, and creating a file on disk is enough (rule 7 does not apply).** Verified: the app target builds, the bundle still has all 32 `.m4a` files, both `.lproj` folders, `Assets.car` and the font, and the template test passes (`iPad Pro 13-inch (M5)`). Opening the project in Xcode and saving may reorder `project.pbxproj`; that is harmless. The simulator named in §4.8 exists, so the test command works as written.
- **0.2** — `NoteCatalog` lives in `Models/Music/Note.swift`; `Route` / `AppRouter` moved unchanged to `Navigation/AppRouter.swift`. In `LevelFeederModel` the notation and postplay pools draw uniformly from `NoteCatalog.all`, and preplay from the white keys (ids 1–19), which is the same distribution as the old dictionaries' `randomElement()`. `TilesViewModel.getStringRepresentation` still returns `""` for an unknown id (it does a lookup rather than calling the trapping `NoteCatalog.note(_:)`). The keyboard's black-key groups (3-2-3-2-3) are kept as a static array so the layout is untouched. Checked by hand on the iPad Air 11-inch simulator: the notation learn keyboard shows all 32 labelled keys with the same grouping. The simulator panel shows the landscape app rotated in the framebuffer, and taps use portrait device points.
- **0.3** — Each note already had its own cached `AVAudioPlayer`, so two different keys sound together without further work; `stopSound(key:)` stops just that note's player. `preloadAllSounds(completion:)` takes an optional completion closure (main thread) so the test can wait for the cache, and `preloadedSoundCount` is an internal read-only counter for the same reason. The audio session is configured in the main-thread hop after the samples decode, so launch isn't blocked by session activation. **Not verified by ear:** whether the first tap is audibly instant and the 5 ms IO buffer is honoured on a device (the simulator ignores it); please check on an iPad.
- **1.1** — Done before 0.4 (it is a ⚠︎ task that waits for a plan OK, and Phase 1 doesn't depend on it). `SongChart.load(for:bundle:)` falls back to the default chart when the JSON is missing, undecodable **or invalid**: `SongChart.isValid` requires bpm > 0, a non-empty note list, keys 1…32, durations > 0 and strictly increasing start beats, so a bad hand-made chart can't crash the highway via `NoteCatalog.note(_:)`. `SongChart.matchesMelody(of:)` plus a test that checks every bundled or default chart against its song's key sequence will catch typos when charts land in Task 2.6. The slug follows §3.4 literally (no trimming of leading or trailing `-`), which doesn't matter for the 18 current titles. `Data/Charts/.gitkeep` is listed as a membership exception in `project.pbxproj` so it stays out of the app bundle; **real chart JSON files dropped into that folder are bundled automatically, flat, at the bundle root.**
- **1.2** — Decisions where §3.6 is silent. (a) `StageMode` is defined now in `Models/Game/PlayModels.swift` because the engine's `init` needs it; Task 2.1 should extend that file, not recreate it. (b) The combo multiplier uses the combo **after** the hit is counted, so the 10th consecutive hit already scores ×2 (×3 at 20, ×4 at 30). (c) Auto-misses and presses are judged against `songTime − audioOffsetMs/1000`; Listen and Practice don't use the offset. (d) A press during the count-in that matches no note is **ignored**, not a wrong press (a kid tapping during "3-2-1" isn't penalised); an early press that does match a note in the first window still counts. (e) `PausableClock.time(at:)` clamps `now − runningSince` at 0 so a display-link timestamp that trails a touch timestamp can't move song time backwards. (f) `recentEvents` is an array of a small `JudgmentEvent` struct (`keyId`, `judgment?`, `hostTime`) instead of a tuple, same member names. (g) Practice: only presses aimed at the next note count (it is ≤ 0.2 s from the hit line); an early correct press marks the note hit without freezing, a press while the next note is still far away is ignored. Practice marks hit notes `.perfect` but never scores. (h) Listen marks notes `.perfect` at their time so they vanish at the hit line; `hintKeyId` is the key that is currently sounding and clears a little before the note ends (so repeated notes retrigger), and the previous sample is stopped through an injectable `soundStopper`. (i) `DisplayLinkTicker` points its `CADisplayLink` at a weak proxy so dropping the engine can't leak the link; `detachTicker()` is still the right thing to call in `onDisappear`. (j) `judgedCount`, `comboMultiplier`, `isFullCombo`, `totalNotes` are computed helpers for the HUD and results. Perform ends as soon as every note is judged, so the stage view should wait about a second before pushing the result to let the last popup show.
