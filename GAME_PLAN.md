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
| 9 | Backsound: real instrumentals for the 16 songs (see `BACKSOUND_PLAN.md`) | v3.x |

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
| 16 songs as pitch sequences, each with a chart and a backing track | `LevelFeederModel.songLevel`, `Data/Charts/chart_<slug>.json`, `Data/Sound/Backing/bgm_<slug>.m4a` | Phase 9 replaced the original 18 with the 16 songs of the backsound recording. Charts are format v2 (see `BACKSOUND_PLAN.md` §3.3). |
| Score-sheet images (old 18 songs) | `Assets.xcassets/Notasi/*` | Kept in the asset catalog but no longer shown: the sheet is drawn from the chart (`NotAngkaSheetView`). |
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
| 1 | **Sumatra** (Sabang) | `1 2 3 4 5 6 7 1˙` + `5. 7.` (5–12, 2, 4) | Bendera Merah Putih | Indonesia Tetap Merdeka | none |
| 2 | **Jawa** | `6. 4.` (3, 1) | Halo Halo Bandung, Bhinneka Tunggal Ika, Dari Sabang Sampai Merauke | Garuda Pancasila | 6 s |
| 3 | **Kalimantan** | `2˙ 3˙` (13, 14) | Bagimu Negeri, Mars Harapan Bangsa | Hari Merdeka | 5 s |
| 4 | **Sulawesi** | `4˙ 5˙ 6˙` (15, 16, 17) | Tanah Airku, Gugur Bunga *(solemn)* | Maju Tak Gentar | 4.5 s |
| 5 | **Bali & Nusa Tenggara** | `4# 1# 5# 2# 6#` (25, 23, 26, 24, 27) | Mengheningkan Cipta *(solemn)* | Api Kemerdekaan | 4 s |
| 6 | **Maluku & Papua** (Merauke) | `7˙ 1˙˙` + all remaining sharps (18, 19, 20, 21, 22, 28–32) | — | Bangun Pemudi Pemuda | 3.5 s |
| — | **Finale: Upacara** | — | **Indonesia Raya** *(solemn ceremony)* | — | — |

**Stage generation rule.** This is deterministic, so implement it as code and don't hand-write the stages. `new` = the chapter's new notes; `review` = all earlier chapters' notes.

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

That gives 7 + 11 + 9 + 9 + 7 + 6 = **49 stages** (Phase 9 moved two notes down a chapter and cut the song count from 18 to 16). Stage ids are `c{chapter}-{index:02}`, for example `c2-05`.

**Unlocks:**
- Stage *i* unlocks when stage *i−1* has ≥ 1★.
- A chapter's first stage unlocks when the previous chapter's last stage has ≥ 1★.
- **Migration for existing players** (run once): classic levels cleared ≥ 20 / 40 / 60 / 80 / 95 unlocks chapter 2 / 3 / 4 / 5 / 6.

**Solemn songs** (`Indonesia Raya`, `Mengheningkan Cipta`, and since Phase 9 `Gugur Bunga`, a song of mourning) have **no monster, no combo flames, no screen shake, and a calm flag background.** Indonesia's national-symbols law (UU 24/2009) restricts how the national anthem may be used, and fighting a monster to it would be disrespectful. Keep these songs dignified.

**Free Play stays fully open:** all 16 songs, the 100 classic levels, Echo endless and Rush. Teachers assign specific songs, so never lock content behind the campaign. The campaign adds structure and rewards.

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

- **Deployment target iOS 16.6, iPhone + iPad, landscape only.** On iPad, layouts must stay identical to v2 (see `IPHONE_PLAN.md` D2). Don't change any of these.
- **iPhone rules (since the iPhone port, `IPHONE_PLAN.md`):** fixed sizes in views go through `Sizing.s(_)` / `Sizing.f(_)` / `Sizing.tap(_)` (identity on iPad); never read `UIScreen.main` in a view (use `screenWidth` / `screenHeight` or a `GeometryReader`); background art is `.resizable().scaledToFill()` in a clipped frame (`ScreenBackdrop`), character art `.resizable().scaledToFit()`; a screen that doesn't fit 375 pt of height gets an iPhone-only layout behind `Sizing.isPhone`, with the iPad layout left as it was.
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
| `settings_backingTrack` | Bool | backing music on/off, default **true** (absent = true) — added in Phase 9 |
| `migration_songRenames_v1` | Bool | the "Merah Putih" → "Bendera Merah Putih" progress copy has run — added in Phase 9 |

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

- **Chart format** (`Data/Charts/chart_<slug>.json`), with beats as Doubles. *Since Phase 9 the chart also carries `beatsPerBar`, `offset` and an optional `beatTimes` tempo map for the backing track; see `BACKSOUND_PLAN.md` §3.3 for format v2.*
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
9. **Finish:** tick the task's checkbox in this file, then stage **only the paths you touched** (`git add GAME_PLAN.md Melodissimo Melodissimo.xcodeproj MelodissimoTests`) and `git commit -m "Task X.Y: <title>"`. Don't use `git add -A`: the user drops files (art, sound packs) into the repo root while sessions run, and `-A` commits them by accident.
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
- [x] done

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
- [x] done

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
- [x] done

**Touches:** `Views/Stage/SongStageView.swift`, `Data/id.lproj/Localizable.strings`.

- **HUD:** pause button, song title, score (`.contentTransition(.numericText())`), combo (shown when ≥ 2), and a thin progress bar (judged / total).
- **Count-in:** a big 3-2-1 overlay while `songTime < 0`.
- **Judgment popups:** drawn in the Canvas from `recentEvents` ("Perfect!" / "Great" / "Good" / "Miss"), rising and fading over 0.5 s at the lane's x. Use **both** text and colour.
- **Pause overlay:** Resume / Restart / Quit (`router.pop()`).
- Auto-pause on `scenePhase` change.

#### Task 2.3 — Practice + Listen + speed + Stage setup
- [x] done

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
- [x] done

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
- [x] done

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
- [x] done

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
- [x] done

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
- [x] done

**Touches:** `Views/Notation/Quiz/NotationQuizLevelMenuView.swift`, `Services/ResultRecorder.swift`, `Views/Battle/BattleView.swift`.

- Level-grid buttons push `.play(PlayRequest(kind: .classic(levelNo:)))`. BattleView builds the config with `fixedQuestions = level.answer`, `timePerNote = nil` for levels ≤ 10 and `max(3, 6 − levelNo × 0.03)` above that, and `isBoss = levelNo % 5 == 0`.
- **ResultRecorder for `.classic` keeps the legacy storage.** Score% = first-try correct / total × 100 → `ProgressStore.recordScore(category: "notation", …)`, so grid stars still use 60/80/100. **A win → `unlock(upToLevel:)`.** This is deliberately more forgiving than today: `NotationQuizCorrectAnswerView` unlocks only on zero mistakes, while a win here allows up to 2. Existing achievements keep working because they read the same keys.
- Old `NotationQuizView` and the correct/incorrect/five-level views are no longer routed to. Leave the files in place for now.

#### Task 3.4 — Melody Rush entry + high score
- [x] done

**Touches:** new `Views/FreePlay/FreePlayView.swift`, `Models/Progress/ProgressStore+Game.swift`, `Navigation/AppRouter.swift`, `Views/Dashboard/DashboardView.swift`.

- Add `rush_highScore` and a "NEW HIGH SCORE" state on results.
- Create `FreePlayView`: Songs (→ song list) · Classic Levels (→ existing grid) · Echo (disabled until Phase 4) · Melody Rush.
- Add a Home button for it.

### Phase 4 — Echo (v2.1)

#### Task 4.1 — Echo logic
- [x] done

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
- [x] done

**Touches:** new `Views/Echo/EchoView.swift`, `Views/FreePlay/FreePlayView.swift`, `Models/Progress/ProgressStore+Game.swift`.

- The top shows a big status: 👂 "Listen…" / 🎹 "Your turn!" plus dots for phrase progress.
- The keyboard has labels **off**. Played-back keys glow when `glowDuringPlayback` is on. Correct notes flash green and show the label briefly above the key.
- Enable Echo in Free Play as an endless mode with `echo_highScore` and `stat_echoBestRounds`.

### Phase 5 — Nusantara Tour campaign (v3.0)

#### Task 5.1 — Campaign catalog + progress
- [x] done

**Touches:** new `Models/Campaign/Campaign.swift`, `Models/Progress/ProgressStore+Game.swift`.

- Model `Chapter { number, name, newNotes, songTitles, bossSongTitle, finaleSongTitle?, timer, symbol (SF Symbol), tint }` from the §2.3 table.
- Model `Stage { id, chapter, index, kind: .battle(BattleConfig) | .echo(EchoConfig) | .song(songId) | .boss(songId) | .finale(songId) }`.
- `CampaignCatalog.chapters` and `stages(in:)` **generate** stages using the §2.3 rule. Use `seed = hash of stage id` so questions are stable.
- SF Symbols per chapter: Sumatra `leaf.fill`, Jawa `building.columns.fill`, Kalimantan `tree.fill`, Sulawesi `sailboat.fill`, Bali & NT `sun.max.fill`, Maluku & Papua `mountain.2.fill`.
- Progress functions: `stageStars(id)`, `isUnlocked(stage)`, `currentStage` (first unlocked stage with 0★) and `runMigrationIfNeeded()` (§2.3).

**Tests:**
- 49 stages with unique ids (53 before Phase 9)
- every song and boss stage's notes are ⊆ cumulative notes taught through that chapter (**this proves the curriculum**)
- unlock chain
- migration thresholds

#### Task 5.2 — ⚠︎ Map UI + stage routing
- [x] done

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
- [x] done

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
- [x] done

**Touches:** `Models/Progress/ProgressStore+Game.swift`, `Services/ResultRecorder.swift`, new `Views/Common/CoinBadge.swift`, `Views/Stage/StageResultView.swift`, `Views/Dashboard/DashboardView.swift`.

- Add the earned/spent keys and `balance`, plus `earn(_:)` and `spend(_:) -> Bool`.
- Implement the full §2.4 reward table in `ResultRecorder`.
- Results show "+N 🪙" counting up. Home and the shop show `CoinBadge`.

**Tests:** the reward table, using fresh `UserDefaults(suiteName:)`. Allow `ProgressStore` to take an injected `UserDefaults`, keeping `.standard` as the default for `shared`.

#### Task 6.2 — Shop + skins applied
- [x] done

**Touches:** new `Models/Shop/ShopCatalog.swift`, new `Views/Shop/ShopView.swift`, `Views/Component/TilesComponentView.swift`, `Views/Stage/NoteHighwayView.swift`, `Views/Battle/BattleView.swift`, `Views/Campaign/CampaignMapView.swift`.

- The catalog follows §2.4. Each item has an id, a category, a price, and a preview (colors or an image name).
- ShopView has tabs per category and a grid of cards with Buy / Equip / Equipped states and a confirm alert on buying.
- **Apply skins:**
  - keyboard body colour and key highlight in `PianoKeyboard`
  - note colours in `NoteHighwayView` (Pelangi = hue from `semitone % 12`)
  - outfit image for Alpanica in Battle, Map and Results

#### Task 6.3 — Daily Challenge
- [x] done

**Touches:** `Views/Dashboard/DashboardView.swift`, `Services/ResultRecorder.swift`, `Models/Progress/ProgressStore+Game.swift`.

- `seed = UInt64(yyyyMMdd)`. The type rotates as in §2.2E. The note pool = all notes taught up to the player's current campaign chapter (at least chapter 1).
- The Home card shows today's type, the reward and done ✓.
- The reward can be claimed once per date key.

**Tests:** same date → same challenge; different dates → different seeds.

#### Task 6.4 — Settings
- [x] done

**Touches:** new `Views/Settings/SettingsView.swift`, `Models/Progress/ProgressStore+Game.swift`.

- **Note speed:** approach time 1.5 / 2.0 / 2.5 / 3.0 s.
- **Show key labels in Perform** toggle.
- **Audio offset** slider (−150…+150 ms) with a "Tap to the beat" calibration: 8 metronome flashes, average tap offset, suggested value.
- **Reset progress** (destructive, double confirm): removes every key in §3.4 *except* `LevelN` question sets and `isPreplayDone`.
- About / version.

#### Task 6.5 — New achievements
- [x] done

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
- [x] done

- Particle burst at the hit line on Perfect: 6–10 small circles in the Canvas, 0.3 s.
- Lane flash on key-down.
- The combo text pulses every 10 combo.
- Stars stamp in on results; the coins counter ticks up.
- Respect `@Environment(\.accessibilityReduceMotion)`: no shake, no particles, fades only.
- **Solemn songs stay calm.**

#### Task 7.2 — Sound effects
- [x] done

- `SFX.play(_ name:)` loads from the bundle and **silently no-ops if the file is missing**.
- It mixes with note samples. Use separate cached players and a lower volume (0.6).
- Hook up the names from §6. Add an "SFX on/off" toggle to Settings.

#### Task 7.3 — Onboarding, help, localization pass
- [x] done

- After the pre-play test, guide new players straight to stage `c1-01` with 3 coach-mark bubbles: "These numbers are notes", "Play the key under the falling note", "Stars unlock the next stage".
- Rewrite Help sections for each mode.
- Localize achievement titles (they are currently hardcoded Indonesian) and make sure every new string has an `id.lproj` entry.
- Verify the Indonesian UI on a simulator set to Bahasa Indonesia.

#### Task 7.4 — Cleanup & performance
- [x] done

- Delete unrouted screens: `NotationQuizView`, the correct/incorrect/five-level views, `SongQuizView`, `SongQuizScoreView` (after moving the trophy write, done in 2.4), and `AfterQuizView` if the preplay/postplay flows no longer use it. **Check every reference with grep first.**
- Delete `TouchLocatingView` / `onTouchDownUp` if unused.
- Profile the Song Stage with Instruments (Time Profiler + Core Animation FPS) on the oldest available iPad simulator, then on a device if possible. It must hold 60 fps with 10+ visible notes.

### Phase 8 — Stretch

#### Task 8.1 — ⚠︎ Real pianika via microphone
- [x] done

- Add `NSMicrophoneUsageDescription` (en + id).
- **Session:** `.playAndRecord`, mode `.measurement`, options `.defaultToSpeaker`.
- **Engine:** `AVAudioEngine` input tap, buffer 2048, hop 1024.
- **Pitch:** YIN pitch detection (threshold 0.15) limited to 165–1100 Hz. Frequency → MIDI → `semitone = midi − 53` → note id from `NoteCatalog`.
- **Onset:** RMS above a noise gate **and** the same pitch for 2 consecutive frames → `engine.press(keyId:, now: now − detectionLatency)`. A new onset needs a pitch change or silence in between.
- **Mic mode:** `PianoKeyboard(playsSound: false)` with the detected key shown pressed, and all judgment windows +50 ms.
- **Settings:** Input = Touch / Real pianika. Add a calibration screen ("play 1 (C)") that shows the detected note live.
- **Tests:** YIN on synthetic sine buffers at 5 note frequencies (±1 semitone accuracy).

#### Task 8.2 — iCloud sync
- [x] done (code; the [USER] capability step is still open, see §8)

- [USER] Enable the iCloud capability with Key-value storage.
- Mirror the §3.4 progress keys to `NSUbiquitousKeyValueStore`. Merge with `max` for scores, stars, coins totals and stats, and OR for booleans.
- Observe `didChangeExternallyNotification`.

#### Task 8.3 — Game Center
- [x] done (code; the [USER] steps are still open, see §8)

- [USER] Configure the leaderboards in App Store Connect: Rush high score, Echo best rounds, total stars.
- Authenticate silently and submit on results.
- Check the App Store Kids Category rules before shipping.

---

## 6. Assets

**Status: the images below already exist** in `Melodissimo/Assets.xcassets/Game/` as vector SVGs. They are generated by `Design/generate_assets.py`; edit and re-run that script, don't hand-edit the imagesets. Use `Design/gallery.html` to view them all. Additional ones:
- `alpanica_happy`, `alpanica_attack` (poses), `alpanica_outfit_glasses`, `alpanica_outfit_crown`, `alpanica_outfit_royal` (shop outfits, **use these instead of the older PNG `alpanicaGlasses`/`alpanicaCrown`/`alpanicaCrownGlasses`** in §2.4).
- Stage icons: `icon_stage_battle`, `icon_stage_echo`, `icon_stage_song`, `icon_stage_boss`, `icon_stage_finale`. Use them in Task 5.2 instead of SF Symbols.
- **Animation code exists:** `Views/Common/CharacterMotion.swift` provides `AlpanicaView`, `FalsView`, `FloatingText` and the modifiers `.idleBreathe()`, `.wobble()`, `.gentleFloat()`, `.hop(on:)`, `.hitShake(on:)`, all Reduce-Motion aware. Tasks 3.2, 5.2 and 7.1 must use these instead of writing new animation code. `CharacterMotionPlayground` (DEBUG) demos them.
- Sounds are still missing (see below).

### Original asset requests

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
- **3.1** — Also done ahead of the ⚠︎ gate (no UI, no keyboard dependency). The timer rules live in `BattleConfig.timeLimit(afterCorrect:)` (a pure function in `Models/`) rather than in the view model: endless battles speed up 8 % every 10 correct answers (2.5 s floor 0.8 s) and boss battles shrink 5 % per correct answer, compounding, with a **floor of 0.8 s** I added so a boss timer can't become impossible. `isEndless` (questionCount == `Int.max` and no fixed questions) is what switches on the Rush rules, so no extra field was added to `BattleConfig`. Rush defaults to the **19 white keys** (`BattleConfig.rush(pool:seed:)` takes a pool if 3.4 wants another). The score is 10 × `1 + min(combo / 10, 4)` (×1…×5), counted after the hit like the song engine. Other decisions: after a mistake **answers are ignored for the 0.8 s reveal** and the note's timer restarts when the reveal ends; the timer does nothing until `start(now:)` is called; `lastOutcome` (kind + increasing token) tells the view which animation to play; `firstTryPercent` is the legacy classic-level score for Task 3.3; `SeededRandom.seed(from:)` is a stable FNV-1a hash for deriving a seed from a stage id in 5.1 (Swift's `hashValue` is different on every launch).
- **4.1** — Also done ahead of the ⚠︎ gate. The phrase generator is a pure `EchoPhraseGenerator` in `Models/Game/EchoConfig.swift` (random walk, song snippets, length schedule). Decisions: the walk **picks only steps that stay inside the pool** instead of clamping (clamping would create extra repeated notes at the edges), and "0 at most once in a row" means the same note can appear twice but never three times in a row. Song snippets are used only when `useSongSnippets` is on, from round 2 on, **on even rounds** (so the stage alternates between snippets and walks), must fit entirely inside the pool, and need at least two distinct notes; if no slice fits it falls back to the walk. The phrase length uses the number of **rounds cleared** (replays after a mistake don't change it). The view model adds a `ready` phase (before `start(now:)`) and a 0.5 s lead-in before the first note; the phase `listening(index:)` is `-1` during the lead-in. Clearing the last required round goes straight to `won` (no `roundCleared` state), and losing the last heart goes straight to `lost` (no `mistake` state). `lastOutcome` carries the kind, the key id and an increasing token so the view can flash the key green with its label or red. An empty pool falls back to the white keys. `glowKeyId` is `nil` on Hard even though the sample still plays.
- **5.1** — Done ahead of the UI tasks (it is pure logic). **The §2.3 chapter table is verified against the real song data**: every song is used exactly once, and no song, boss or finale uses a note its chapter hasn't taught (`testEverySongBossAndFinaleOnlyUsesNotesTaughtSoFar` is the proof). One thing worth knowing: "Dari Sabang Sampai Merauke", the chapter-6 boss, only uses keys 2–9, so it is an easy final boss; "Indonesia Raya" is the widest song (keys 6–17). Decisions: (a) I also changed `ProgressStore.swift` (not in the task's Touches) so `defaults` is an injectable `init(defaults:)`, which tests need and which Task 6.1 asks for anyway; `shared` still uses `.standard`. (b) `Chapter.tint` is stored as `tintHex: UInt32` because `Models/` can't import SwiftUI; views convert it. (c) Stage generation, unlocking and the migration thresholds are pure functions in `CampaignCatalog` taking a `stars:` closure, with thin wrappers in `ProgressStore+Game.swift`. (d) "Review notes nearest in pitch" is the distance in semitones to the nearest new note, ties broken by id. (e) The E2 echo has `useSongSnippets` off (the plan's rule doesn't say to turn it on); flip it in `CampaignCatalog.stages(in:)` if you want real-song snippets there. (f) `currentStage` scans from the first stage of the migrated chapter, so a migrated player's avatar starts at their chapter rather than at `c1-01`; earlier chapters stay playable through the normal chain. (g) A granted chapter opens only that chapter's first stage; the rest of it still follows the one-star chain. (h) **`runMigrationIfNeeded()` is not called anywhere yet**: Task 5.2 or 5.3 should call it once at launch, before the map or Home reads `currentStage`.
- **5.2** — Plan pre-approved. `CampaignMapView` is a horizontal `ScrollView` of six chapter panels (90 % of the screen width) over a tiled `map_ocean`, each with its island art (`map_island_N`), the chapter symbol, name and stars total, and the stage nodes on a dashed zig-zag path (`MapLayout.nodeFractions`, pure and tested). A locked chapter is dimmed with a lock and "Clear %@ to sail here". `ScrollViewReader` opens on the current chapter. `StageNodeView` uses the `icon_stage_*` art instead of SF Symbols (so `bolt.fill`, `ear.fill` and the others from the task text are not used), shows stars underneath and a lock when locked. Alpanica sits on the current stage and springs to the new one when it changes. Tapping a node opens `StageSheetView` (a 480 pt sheet: title, kind, best stars, Play); battle and echo go to `.play(PlayRequest(kind:, campaignStageId:))`, song, boss and finale to `.stageSetup(songId:, campaignStageId:, isBoss:)`. `ResultRecorder` writes the stage's stars with `recordStageStars` (max) and puts the **gain** in `RewardSummary.newStars`; Retry replays the same request, and the second results button becomes "Next" (won) or "Map" (lost) and does `router.pop(to: .campaignMap)`. Decisions: (a) stage titles and kind labels are derived in `Stage.title` / `kindTitle` rather than stored. (b) The avatar uses `AlpanicaOutfit.none` until the shop exists (6.2). (c) **`runMigrationIfNeeded()` now runs once in `MelodissimoApp.init()`** (the open item from 5.1), before anything reads `currentStage`. (d) A temporary **"Nusantara Tour"** button in Home's top bar opens the map; Task 5.3's Home redesign replaces it. (e) A song stage's `newStars` stays 0 because a song stage's results already show its own stars. (f) I changed one test: `testInjectedDefaultsDoNotTouchTheStandardStore` asserted the standard store held 0, which fails as soon as someone has played c1-01 in the simulator app (tests run inside it), so it now checks the value did not change. **Verified in the iPad Air simulator:** the map opening on Sumatra with the lock states, the stage sheet, c1-01 played to a win (3 stars and 3 hearts on the results), then "Next" back to the map with 3 stars on node 1, node 2 unlocked, Alpanica moved onto it, and the totals reading 3/21 and 3/159. **Not verified, please check by hand:** the loss path back to the map ("Map" button), a song, boss or finale stage from the map, scrolling to the other five chapters and the locked overlay on a fresh install, the avatar's hop on a real device, and the layout on an iPad mini.
- **5.3** — **v2.2 (the campaign) is complete.** *Boss:* a boss stage's HUD grows to 92 pt and gets `BossBadgeView` at its right end: the chapter's `fals_boss_N` art (N = the stage's chapter) that wobbles and flashes on every hit, plus, **in Perform only**, a health bar. `BossHealth.fraction` (pure, tested) is `1 − weighted hits / total notes` with the accuracy's weights (Perfect 1, Great 0.75, Good 0.4); misses and wrong presses never heal or hurt it. Because that only reaches 0 at 100 %, **a white notch on the bar marks the defeat line** (40 % left = 60 % accuracy = the first star), so a won fight doesn't end with a boss that still looks healthy. The results show "Boss defeated!" / "Try again!". `stat_bossesDefeated` goes up when a Perform on a **song boss** stage gives its first star (`ResultRecorder`; the classic every-fifth-level battle bosses don't count). *Story cards:* `Models/Campaign/StoryCards.swift` holds the **13 cards** (6 chapter intros, 6 after-boss, 1 finale card shown after the last boss and before Indonesia Raya), 2–3 lines each, every line a key in `Localizable.strings` with an Indonesian translation (a test fails if one is missing or still English). `StoryCatalog.pending` decides what to show: an intro only while the player is up to that chapter (so a migrated player doesn't get the intros they skipped), a boss card once its boss has a star, the finale card once the last boss does. `CampaignMapView` shows them over a dimmed map 0.7 s after it appears (so the avatar's hop is seen first), one after another, and marks each `story_seen_<id>` on Continue. `StoryCardView` uses Alpanica, the chapter's boss art (stars circling it once beaten) and the flag emoji for the anthem, not an emoji monster. *Certificate:* the finale's first star stamps `stat_tourCompletedAt` (`ResultRecorder`); the map then shows `CertificateView` once (`story_seen_certificate`): title, total stars, that date and Alpanica on a cream card, with a `ShareLink` of an `ImageRenderer` picture (2×). It can be opened again from the finale's stage sheet ("Certificate"). *Home:* a top bar (streak, a **placeholder coin badge reading 0** until 6.1, achievements, a **disabled settings gear** until 6.4, help, share), the big **Nusantara Tour** card (the current island, "Up next: <stage>", tour stars, Start / Continue, or "Tour Complete" when every stage has a star) and three cards: **Daily Challenge** (disabled, "Coming soon", until 6.3), **Free Play** and **Learn**. The `dashboard` background is kept. **Learn** opens the new `LearnHubView` (`Route.learnHub`) with Notes (`.notationLearn`), Songs (`.songRepositoryLearn`) and Skill Test (`.postplay`). Decisions: (a) files outside the task's Touches: `BossHealth`, `StoryCards`, `BossBadgeView`, `CertificateView`, `LearnHubView`, `Color+Hex` (the hex initializer moved out of the map), `HubCard` (the Free Play card, extracted so the Learn hub shares it; `FreePlayView` now uses it) and `Route.learnHub` in `AppRouter`. (b) The greeting title is gone, so the DEBUG Chart Recorder shortcut is now a **long press on the streak capsule**. (c) The certificate and the map avatar still use `AlpanicaOutfit.none`: Task 6.2 should switch both to the equipped outfit. (d) `NotationMenuView`, `SongMenuView`, their routes and the three menu button images (`notationMenuButton`, `songMenuButton`, `postplayMenuButton`) are no longer reachable from Home; I left them in place for Task 7.4's cleanup to decide. **Verified in the iPad Air simulator:** the new Home (also with the current island moved on to Jawa), the map's first-visit intro card, a seeded profile stepping through the after-boss card, the next island's intro, the finale card and the certificate in order (each Continue moving on, the map clean afterwards), the share sheet opening with the rendered picture and title, the boss stage's HUD (Fals at the top right, full green bar with the notch) and its **lost** results ("Try again!", Retry and Map), and the Learn hub plus its Notes lesson. **Not verified, please check by hand:** a real boss fight that scores (the bar dropping with hits, the shake, "Boss defeated!" and the first-defeat counter), the Indonesian wording on a device set to Indonesian, the rendered certificate image in a real share target (only the share sheet's preview was seen), the layout on an iPad mini, and Reduce Motion on the cards.
- **6.1** — `coins_earnedTotal` / `coins_spentTotal` (both only ever increase) with `coinBalance`, `earn(_:)` and `spend(_:) -> Bool` (false and no change when the balance is short) in `ProgressStore+Game.swift`. The §2.4 amounts are pure functions in the new `Models/Game/CoinRewards.swift` (so the table lives in one place and is unit-tested); `ResultRecorder` only says what happened and pays `CoinRewards` once per play. How the table was read: (a) **new star** = a star above the previous best, +10 each; for a song played from the map the song's own best and the stage's best both go up, so the stars are paid **once** (the larger of the two gains). (b) **First clear +20** is for **campaign stages** only (the table says "stage"), not for free-play songs, which would otherwise pay twice. (c) **Boss +100** is added on top of the first-clear +20 and the stars (a first 1★ boss pays 130). (d) **Replay +5** is a won stage or Perform that adds no stars. (e) **Practice +15** the first time a song is practiced. (f) **Rush** pays one coin per five right answers and **endless Echo** two per round. (g) **The classic 100 levels, Listen, lost plays and non-endless Echo without a stage pay nothing** (the table has no row for them). (h) The daily reward is `CoinRewards.daily(streak:)` (50 + 10 × min(streak, 5)); it is not wired until Task 6.3. To pay Rush by answers I added `PlayResult.correctCount` (default 0, so existing initializers still compile), which `BattleView` fills from the battle. **UI:** `CoinBadge` (a yellow capsule showing the live balance) replaces Home's placeholder; the results screen shows "+N 🪙" under the stats (`CoinCountUp`, which counts up about 25 steps after the stars have landed, or jumps to the total under Reduce Motion); Task 6.2's shop should reuse `CoinBadge`. One existing assertion changed: `testFirstPerformRecordsBestsStarsAndStats` expected 0 coins from a first 3★ Perform and now expects 30. **Verified in the iPad Air simulator:** c1-02 played to 3 hearts, the results counting up to **+50** (3 × 10 + 20), then Next, the map, and Home's badge reading 50 with the tour at 6 / 159. **Not verified, please check by hand:** the coin row on a song result and a boss result, Rush and Echo payouts on a real run, Reduce Motion, and the badge on an iPad mini. Coin earning has no sound yet (Task 7.2).
- **6.2** — `ShopCatalog` (12 items, prices as §2.4: keyboard Navy free / Merah Batik 100 / Hijau Hutan 150 / Biru Laut 150 / Emas 300, notes Default free / Pelangi 200 / Neon 250, outfits Default free / Kacamata 150 / Mahkota 300 / Raja Gaya 500; 2,100 coins in all), `ProgressStore+Shop.swift` (`shop_owned`, `equip_keyboard` / `equip_notes` / `equip_outfit`; `owns`, `buy` (false and no change when owned or short of coins), `equip` (only what you own), `equippedItem` (falls back to the category default for an unknown or unowned id)) and `ShopView` (Keyboard / Notes / Outfit tabs, a card per item with a preview, a Buy / Equip / Equipped button, a confirm alert on buying, `CoinBadge` in the corner; **a new purchase is worn at once**; an item you can't afford is greyed out). **Skins applied:** `PianoKeyboard` takes its body colour and pressed-key colour from the equipped `KeyboardSkin` (read once when the keyboard appears), `NoteHighwayView` colours notes with the equipped `NoteSkin` (Pelangi = a hue per pitch class from `semitone % 12`, black keys a shade deeper; Neon = cyan on white keys, magenta on black; both are pure functions in `Models/Shop/NoteSkin.swift` with tests), and Alpanica wears the equipped outfit in Battle / Rush, on the map, on Home's tour card, on the results screen, on story cards and on the certificate (`AlpanicaOutfit.equipped`). Decisions: (a) files outside the task's Touches: `Route.shop` and a **Shop button on Home** next to the coin badge (the plan shows the badge but no way in), `StageResultView`, `StoryCardView`, `CertificateView`, `CharacterMotion.swift` and Home's tour card for the outfit, `Skins.swift` (turns catalog colours into `Color`s), `ProgressStore+Shop.swift`. (b) The happy and sad poses have no outfit art, so `AlpanicaView` got `keepsOutfit`: the results, story and Home screens (which stay open for a while) show the outfit's idle art instead of the happy / sad pose when an outfit is on; Battle's 0.6–0.8 s attack and sad flashes still use the poses. (c) Item names are shown as the plan gives them (mostly Indonesian proper names that read the same in both languages); only "Default" is translated. (d) Every `PianoKeyboard` takes the equipped keyboard skin, so the Learn, Quiz, Battle and Echo keyboards change as well as the song stage's. That is intended (it is one component) but worth a look. **Verified in the iPad Air simulator:** the shop's three tabs, the confirm alert, buying Merah Batik, Pelangi and Kacamata with the balance dropping 750 → 650 → 450 → 300 and each purchase worn at once, the equipped / equip states, the Merah Batik keyboard and Kacamata Alpanica in Melody Rush and on its results screen, Alpanica with glasses on Home, rainbow notes on a Berkibarlah Benderaku Listen stage over the Batik keyboard, and everything still equipped after restarting the app. **Not verified, please check by hand:** Neon, Biru Laut, Hijau Hutan and Emas on a real device (the colours were only seen in the shop previews), Mahkota and Raja Gaya on the map and certificate, the keyboard skin on the Learn and Quiz screens, a purchase that leaves exactly 0 coins, and the shop layout on an iPad mini.
- **6.3** — `DailyChallenge` (`Models/Game/DailyChallenge.swift`, pure and tested) builds the day's challenge from the date alone: key `yyyyMMdd` in the player's local calendar, `seed = UInt64(key)`, type by `dayOfYear % 3` (0 Echo × 5 rounds, 1 Note Battle × 15 questions at 4 s, 2 Song Sprint = the first 32 notes of a seeded song at 1×), note pool = every note taught up to the player's current campaign chapter (chapter clamped to 1…6). The sprint song is picked by the seed from non-solemn songs whose first 32 notes fit the pool (any non-solemn song if none fit). A bad key (not a real date) gives `nil`. The Home card now shows today's type and exact reward (`CoinRewards.daily(streak:)` using the new `ProgressStore.streakAfterPlayingToday()`), a tick and "Done! Come back tomorrow" once won. Playing: `PlayRequest.kind = .daily(dateKey:)` is resolved in `PlayDestinationView` into the real mode and a request carrying the new `PlayRequest.dailyDateKey`, so results and Retry replay the same challenge. `ResultRecorder.recordDaily` counts the play towards the streak first, then pays once per date (`daily_done_<key>`), only on a win; **a daily play never touches song bests, stars, stats, stage stars or Rush records, and the sprint pays no star coins** (a 32-note sprint would inflate a song's accuracy). Results show "Daily Challenge" and a "Menu" button back to Home. Strings for the card are in `id.lproj`. **Verified in the iPad Air simulator:** the Home card ("Note Battle · +60 coins" on 10 Oct 2026, a day-of-year 283 battle), starting the challenge into the 15-question battle with the 4 s timer, and a lost run ending on "Daily Challenge / Try again!" with Retry and Menu and no coins. **Not verified, please check by hand:** winning a daily (the +coins count-up and the tick on Home afterwards), the Echo and Song Sprint days, a day with a longer streak, and the card after midnight. My automated tapping was too slow for the 4 s timer, so the win path is covered by unit tests only (29 tests in `DailyChallengeTests.swift`).
- **0.4** — Plan approved by the user, who also pre-approved the later ⚠︎ tasks 2.1, 3.2 and 5.2 (Task 8.1 was not covered). `PianoKeyboard` replaces the private keyboard view; `PianoMetrics.stage` is added; the four `PianikaStack*` views are thin wrappers. Decisions: (a) a key counts the fingers on it, so two fingers on one key keep it pressed and sounding until the **last** one lifts, but `onNoteOn` / `onNoteOff` still fire once per finger (a second finger landing on a held key retriggers the sample). (b) `highlights` beat the pressed look, so a hint glow stays visible while the key is touched; `pressedFromOutside` draws the normal pressed grey. (c) `onKeyFrames` gives **window (global)** frames and fires whenever the preference changes. (d) Leaving the screen with fingers down stops the sounding samples (`onDisappear`). (e) I updated the two FAQ answers named in the task (the "pressed it at least 2 seconds" answer now says to check the volume, and the "more than one tile" answer now says yes) in `HelpPageView` and `id.lproj`; **the quiz bullet "make sure your pressed tiles are at least 2 seconds…" (HelpPageView line 19, id.lproj line 19) still says 2 seconds**: it was out of the task's scope, so fix it in 7.3 with the Help rewrite. Verified in the iPad Air simulator by logging key events (temporary, removed): two fingers on keys 5 and 7 both went down before either came up, then both released with `isRelease = true`; a glide from key 5 to key 7 gave down 5 → up 5 (slide) → down 6 → up 6 (slide) → down 7 → up 7 (release); the notation quiz still answers on lift (tapping the asked key passed level 1). **Please check by hand on a real iPad:** two-finger play feels right on both a big and a small iPad, and fast passages with overlapping fingers don't drop notes. The simulator panel shows the landscape app rotated in the framebuffer, and `touch2_path` can't be screenshot mid-gesture.
- **Process (after 0.4)** — `git add -A` swept two folders the user was adding to the repo root into earlier commits: `Design/` (in the Task 4.1 commit) and `kenney_interface-sounds/` (in the Task 0.4 commit). I untracked both in a follow-up commit (`Stop tracking Design/ and kenney_interface-sounds/`); their blobs are still in the history of this **unpushed** local branch. If you want them gone from history, rewrite the branch yourself (for example an interactive rebase that drops them from those two commits) before pushing. Rule 9 above now says to stage explicit paths. The files are untouched on disk.
- **Assets (user OK'd using them)** — `Design/generate_assets.py` already installed 30 vector imagesets into `Melodissimo/Assets.xcassets/Game/` (committed with Task 3.1/4.1, so they are in the app): `fals_minion_1…3`, `fals_boss_1…6`, `alpanica_happy`, `alpanica_attack`, `alpanica_outfit_crown|glasses|royal`, `map_ocean`, `map_island_1…6`, `stage_bg_concert`, `stage_bg_ceremony`, `icon_coin` and `icon_stage_battle|boss|echo|finale|song`. They use the §6 names, so they replace the emoji placeholders. Use them in the UI tasks (3.2 monsters and Alpanica poses, 5.2 map and node icons, 2.3 the ceremony background for solemn songs, 6.1 the coin, 6.2 the outfits). `kenney_interface-sounds/` is CC0 `.ogg`, which **AVAudioPlayer can't play**: Task 7.2 needs to convert the chosen files to `.m4a` / `.caf` before bundling them. Both source folders are left untracked; say the word if you want them committed.
- **2.1** — Plan pre-approved with the rest of the ⚠︎ tasks. `PlayModels.swift` now holds the full §3.5 models; `Route.play(PlayRequest)` maps through a new `PlayDestinationView` (song → `SongStageView`, every other mode → a "Coming soon" screen that 3.2 / 4.2 / 3.4 replace). The lane and note math lives in `HighwayGeometry` (tested); `NoteHighwayView` draws everything in one `Canvas` with the 32 note labels as resolved symbols, and keeps a note visible until its **end** is 0.3 s past the hit line (so long notes don't pop out). The stage uses `stage_bg_concert` behind a darkened highway. `noteLimit` is already applied by `SongStageView` (truncates the chart) for the daily song sprint. Approach time is a constant 2.0 s and the audio offset 0 until Task 6.4. The HUD is the placeholder the task asks for (back button, title, score, combo ≥ 2) and the end screen is a placeholder overlay (score, Retry, Back) that Task 2.4 replaces with the real results route. **Correction (found in 2.3):** the first version of the highway stopped redrawing a few frames after the stage started, because the `Canvas` closure captured nothing that changed per frame, so SwiftUI skipped it; my 2.1 screenshots were of that frozen frame. It is fixed in 2.3 (the closure now captures the timeline's date), and I then confirmed in the simulator that upcoming notes sit in the right lanes at the right distances. If you ever see the highway freeze, that is the place to look. **Verified in the iPad Air simulator:** the stage opens, lane alignment, and Back returns to Home without a crash. **Not verified, please check by hand:** (a) hitting a note on time removes it and scores, (b) lane alignment on an iPad mini and an iPad Pro 13", (c) smooth 60 fps with the Xcode FPS gauge. The DEBUG button on Home is temporary and is removed in Task 2.4.
- **2.2** — HUD: pause button (replaces the 2.1 back button; Quit lives in the pause menu), title, score with `.contentTransition(.numericText())` (iOS 16, allowed), combo from 2, and a progress bar that redraws every frame so Listen and Practice, which don't publish per note, still move it. The count-in math is a pure `CountIn.display(songTime:secondsPerBeat:)` (tested; my first version had the within-beat progress inverted and the test caught it). Popups are drawn in the highway `Canvas` from `recentEvents` (text **and** colour: yellow "Perfect!", green "Great", blue "Good", red "Miss"), rise 50 pt and fade over 0.5 s at the lane; they are **only shown in Perform** (`showsPopups`), and a wrong press has no popup. The scene-phase auto-pause pauses on any phase other than `.active` and leaves resuming to the player. **Verified in the simulator:** the HUD, progress bar, pause overlay (Resume / Restart / Quit), the Restart reset, and the 3-2-1 overlay. **Not verified, please check by hand:** the popups (they need a real timed hit), the numeric-text score animation, auto-pause when you swipe up to the home screen, and Resume continuing from the same song position.
- **2.3** — `StageSetupView` (Listen / Practice / Perform, 0.5× / 0.75× / 1×, key-label toggle, best stars and accuracy, ✓ Practiced) and `Route.stageSetup(songId:campaignStageId:isBoss:)` (the two extra parameters have defaults, so `.stageSetup(songId:)` works as written in the plan; 5.2 will pass the stage). Decisions: (a) the song progress accessors the setup screen reads (`song_practiced_`, `song_bestScore_`, … in `ProgressStore+Game.swift`) were added here instead of 2.4 because 2.3 needs them; 2.4 adds the *writers* in `ResultRecorder`. (b) The chosen label setting travels in a new `PlayRequest.showKeyLabels: Bool?`. `nil` means the mode default: **on** for Listen and Practice, the `settings_labelsInPerform` setting (off) for Perform. The setup toggle starts on; Perform ignores it until the player flips it. (c) **Practice finishing marks the song practiced directly from `SongStageView`** (`ProgressStore.setSongPracticed`) because the results route doesn't exist until 2.4; the call is idempotent, and 2.4's `ResultRecorder` will set the same flag, after which this direct call can go. (d) The finish screens are per mode: Listen offers "Try Practice →", Practice offers "Perform →" (both use the new `AppRouter.replaceTop(with:)` so Back skips the finished stage), Perform keeps the placeholder until 2.4. (e) Practice and Listen show "Practice" / "Listen" in the HUD instead of a score. (f) A wrong key in Practice flashes red for 0.3 s; the right key glows yellow after two wrong presses or 3 s. (g) Solemn songs use the new `stage_bg_ceremony` art (sky and grass) with a faint `flag.fill` watermark instead of the plain `vanila` colour in the plan, dark-green HUD text, no combo text, and a faint ✓ in place of judgment words (misses show nothing). (h) This codebase's `Font` extension defines its own `Font.system(size:weight:design:)`, which is ambiguous with SwiftUI's, so use `.custom("BalooDa-Regular", size:)` for symbol sizes. **Verified in the iPad Air simulator:** the setup screen (Perform locked), Listen (the sounding key is drawn pressed, labels on, notes fall), Practice (the song waits at the first note, two wrong keys light the hint, the right key advances and clears the hint), and the solemn Listen stage with the ceremony background. **Not verified, please check by hand:** the red wrong-key flash, the finish screens (Listen → "Try Practice →", Practice → "Perform →" and the Perform unlock), the speed picker at 0.5× and 0.75×, and the 3-star cap hint. Two temporary DEBUG buttons on Home open the setup screen for "Berkibarlah Benderaku" and "Indonesia Raya"; Task 2.4 removes them.
- **2.4** — **v2.0 content is complete: setup → practice → perform → results → back works for all 18 songs.** `ResultRecorder` (a struct with an injectable `ProgressStore` and achievement hook, so it is unit-tested against a throwaway `UserDefaults`) writes song bests, stars (`RewardSummary.newStars` is the stars gained over the old best), the practiced flag, `stat_songsPerformed`, `stat_fullCombos`, the legacy trophy on 3★, `recordCombo`, the daily streak and `AchievementStore.evaluate()`; coins stay 0 until 6.1. Decisions: (a) **Listening records nothing at all** (no streak, no achievements); Practice sets the practiced flag and counts as playing today. (b) `stat_fullCombos` counts each song's **first** full combo, so replaying one song can't farm the "Tanpa Cela" achievement. (c) Practice finishing goes through `ResultRecorder` (replacing the direct flag write from 2.3) but keeps its own "Perform →" overlay rather than the results screen, since there is no score to show. (d) Perform finishes with a one-second "Finished!" banner, then `router.replaceTop(with: .result(...))`, so Back from the results lands on the setup screen; the hop is skipped if the player already left (`isOnScreen`). Results' **Retry** replays the exact request (same speed, same label choice); **Song menu** is `pop(to: .songRepositoryQuiz)`; **Next** only appears for campaign stages and is a no-op until Phase 5. (e) `StageResultView` uses `alpanica_happy` for 1–3★ and `alpanicaSad` for 0★, ConfettiSwiftUI on 3★, and a reduce-motion path (stars fade in instead of springing). (f) The song list opens `.stageSetup(songId:)` and shows each song's best stars under its name; the trophy shelf code is untouched. The Song menu card now says "STAGE" and the list title "Song Stage" (Indonesian: PANGGUNG / Panggung Lagu). The old `SongQuizView`, `SongQuizScoreView` and the `.songQuiz` route are unrouted but still in the project for Task 7.4 to delete. The temporary DEBUG buttons on Home are gone. **Not verified, please check by hand:** a 3★ result (confetti, trophy appears on the shelf), progress surviving an app relaunch with real play, and the Indonesian strings on a device set to Bahasa Indonesia.
- **2.5** — The quantizing, JSON and file-writing logic is pure and tested (`ChartQuantizer`, with the recorder's state machine in `ChartRecorderViewModel`); the screen (`ChartRecorderView`) is wrapped in `#if DEBUG` and I confirmed the Release configuration still compiles. Opened by a **1-second long-press on the Home title**. Decisions: (a) the quantizer's `t_0` is the **first recorded press**, so a chart always starts at beat 0; a song with a rest before its first note should be played so that its first note comes first. (b) The recording **stops by itself after the last note** as well as on the Stop button; presses during the 4-beat count-in are ignored. (c) When it stops, it prints the JSON, copies it to the clipboard and writes `Documents/chart_<slug>.json`, then shows the path and a warning if the recorded keys differ from the melody (use that before saving the chart into the repo). (d) There is an audible metronome tick (system sound 1104) as well as the flashing dot; it follows the silent switch. (e) "Preview (Listen)" pushes the new `Route.chartPreview(SongChart)` into the normal Listen stage through a new optional `chart:` parameter on `SongStageView`. (f) The recorder's own strings are English only (developer tool). **Verified in the iPad Air simulator:** the long-press, a 3-note recording, the file on disk (pretty-printed, sorted keys, as in §3.6), and the Listen preview. **How to use it:** record a song, find the file with `xcrun simctl get_app_container booted com.balqishafiraini.Melodissimo data` → `Documents/`, copy it to `Melodissimo/Data/Charts/chart_<slug>.json`, and check it in Listen. A chart that matches the melody and passes `SongChart.isValid` is loaded automatically in place of the default one. **Task 2.6 is yours:** I haven't drafted any chart from the score-sheet images (the plan makes that an opt-in shortcut); say so if you want me to.
- **3.2** — Plan pre-approved. Built on `Views/Common/CharacterMotion.swift` (idle breathing, hop, hit-shake, floating "−1", `AlpanicaView` moods) and the `fals_*` art, which the user dropped into the repo. `BattleView` (arena, speech bubble with the note in Baloo 70 and a draining timer bar, hearts / combo / score top bar, `PianoKeyboard(.full)` with the reveal key glowing green) runs on `BattleViewModel`: answers register on finger lift, a 20 Hz timer drives `step`, and on a mistake the right key's sample plays and the screen nudges 8 pt (skipped under Reduce Motion). `MonsterSprite` is the monster's art (through `AssetImage`, so a missing asset falls back to 👾 / 🐲) with a health bar, hit flash and lunge. The monster is picked from the config seed (minions 1–3, bosses 1–6) so a stage always shows the same one. Layout order is Alpanica · bubble · monster so the bubble points at Fals. Decisions: (a) the battle uses the same red background as the old notation quiz; (b) Alpanica switches to her `attack` pose for 0.6 s on a hit and `sad` for 0.8 s on a mistake; (c) for finite battles the **first-try percentage rides in `PlayResult.accuracy`** (Task 3.3's classic-level score reads it); it is `nil` for endless Rush; (d) the battle's result goes through `ResultRecorder`, which for now only records combo, streak and achievements for battle kinds (classic storage arrives in 3.3, campaign stars in 5.2); (e) `StageResultView` now handles every kind: a title per mode, "Victory!" / "Try again!", the stars row, score and max combo, and **hearts left** instead of the accuracy breakdown for non-song results; its second button is "Song menu" for songs, "Levels" for classic levels and "Back" otherwise. (f) `HeartsView` draws a white ring behind each heart and uses a deeper red than the app's `red`, because the plain red vanished on the red background. **Verified in the iPad Air simulator:** the arena layout, a correct answer (score, the monster's health bar drops a quarter, next question), a timeout and wrong answers costing hearts with the key reveal, and the loss path through to the results screen. **Not verified, please check by hand:** the win path and its results (hearts left), the boss variant (bigger monster, shrinking timer), the screen nudge and monster lunge animations, Reduce Motion, and the layout on an iPad mini (the full keyboard leaves about 215 pt for the arena there). A temporary DEBUG "Note Battle" button on Home launches a test battle; Task 3.3 removes it.
- **3.3** — The level grid now pushes `.play(PlayRequest(kind: .classic(levelNo:)))`, and `PlayDestinationView` builds the battle with the new pure `BattleConfig.classic(levelNo:answers:)` (the level's exact `answer` sequence, no timer on levels 1–10, then `max(3, 6 − level × 0.03)` s, every 5th level a boss, seed = the level number). `ResultRecorder` stores the first-try percentage (carried in `PlayResult.accuracy`) with `recordScore(category: "notation", …)` and calls `unlock(upToLevel:)` on a win, so the grid's stars (60 / 80 / 100) and unlocking keep reading the same legacy keys; `testLegacyKeysAreUntouched` pins `bestScore_notation_<n>` and `currentLevel`. As the plan notes, this is more forgiving than before: a win with up to two mistakes unlocks the next level. Decisions: (a) **boss levels do not double their questions**: the 3.3 recipe says to use `level.answer` as is, and the "×2 questions" in §2.2B is only applied where a config is built from scratch (campaign battles). (b) I added a **"Next level" button** to a classic win's results (not in the plan) because the old flow went straight to the next level; it replays `.classic(levelNo + 1)`. (c) The temporary DEBUG "Note Battle" button is gone. The old `NotationQuizView` and the correct / incorrect / five-level views are no longer routed but still in the project for 7.4. The old five-level celebration screen is not reproduced; a flawless win just fires the standard 3★ confetti. **Verified in the iPad Air simulator:** Notation → Quiz → Level 1 opens the battle, answering its question wins, the results show "Level 1 / Victory!" with hearts left, stars popping in and confetti, and back on the grid Level 1 keeps its 3 stars and **Level 2 is now open**. **Not verified, please check by hand:** a higher level with a timer, a boss level (5), losing a level (it must not unlock the next), and the existing player's saved progress carrying over from an older build.
- **3.4** — **v2.1's battle half is complete.** `rush_highScore` is stored by `ProgressStore.recordRushScore` (returns `true` only for a strictly higher score, so a tie or a 0 is never a "new high score"), `ResultRecorder` sets `isNewBest` from it, and the results screen shows "Game over", score, max combo, the **high score** and a **NEW HIGH SCORE** badge with confetti (no stars row for Rush, since it can't be won). `FreePlayView` has four cards using the new `icon_stage_*` art: Songs (→ the Song Stage list), Classic Levels (→ the existing grid), Echo (greyed out, "Coming soon", for 4.2 to enable) and Melody Rush (shows the high score). Home gets a **"Free Play"** button in the top bar (between the trophy and Share); Task 5.3's Home redesign will move it. Decisions: (a) `PlayDestinationView` picks Rush's random seed **once** (`@State`) so a re-render can't change the notes or swap the monster mid-run; (b) the Rush pool is the 19 white keys (from 3.1). **Verified in the iPad Air simulator:** Home → Free Play (all four cards), Melody Rush starting (a different monster, no health bar, draining timer, hearts lost to timeouts) and the game-over results. **Not verified, please check by hand:** a real Rush run that scores (the 10 × combo scoring, the interval shrinking every 10 answers, and the NEW HIGH SCORE badge and confetti), and Free Play → Songs / Classic Levels from the new hub.
- **4.2** — **v2.1 is complete (Phases 3–4).** `EchoView` runs on `EchoViewModel`: the big status ("👂 Listen…", "🎹 Your turn!", "⭐ Round cleared!", "Oops! Listen again…") with Alpanica, progress dots (yellow as the phrase plays, green as the player gets notes right), hearts, the round number and the full keyboard with **labels off**. Easy lights the playback key yellow; a right note flashes the key green and floats its **name above the key** in a white capsule; a wrong note flashes it red and Alpanica winces. Answers register on key **down** (not on lift as in the battle) because Echo is about hearing and answering at once. Decisions: (a) Free Play's Echo card asks Easy / Hard through a `confirmationDialog` and starts an **endless** run over the notes 1 2 3 4 5 6 7 1˙ (ids 5–12) with `useSongSnippets` on, so later rounds use real-song phrases that fit the pool; (b) an endless run gets a fresh random seed per play (`PlayDestinationView`), a campaign echo keeps its stage seed; (c) the Echo result's `score` is the **rounds cleared**: `echo_highScore` (endless best, with a NEW HIGH SCORE badge and confetti) and `stat_echoBestRounds` (best over any Echo, including campaign) are written by `ResultRecorder`; the results screen shows "Rounds" and "High score" with no stars or combo for an endless run, and stars = hearts left for a campaign echo that is won. **Verified in the iPad Air simulator:** Free Play → Echo → Easy, the listening phase with the glowing key and dots, a wrong key (red flash, heart lost, "Oops! Listen again…", the phrase replayed), and a right key (green flash, the floating name label, the first dot turning green). **Not verified, please check by hand:** the Hard mode (no glow), clearing a round and the "Round cleared" state, a longer phrase, a run that ends in the game-over results with a NEW HIGH SCORE, and the layout on an iPad mini (the full keyboard leaves about 215 pt for the status area).
- **6.4** — `SettingsView` (Home's gear now opens it through `Route.settings`) has cards for **Note speed** (1.5 / 2.0 / 2.5 / 3.0 s; a bigger number = slower notes), **Show key labels in Perform**, **Audio timing** (a −150…+150 ms slider in 5 ms steps, a Reset button and "Tap to the beat"), **Reset progress** (two confirmations) and **About** (version and build). `SongStageView` now reads `approachTime` and `audioOffsetMs` from the settings each time a stage opens (the old `SongStageView.approachTime` constant is gone); they apply to Listen, Practice and Perform, and the audio offset only affects judging, as in 1.2(c). **Calibration** (`CalibrationView`, full-screen from Settings): 8 clicks at 80 bpm after a 1.5 s lead-in, the player taps any key on the **real `PianoKeyboard`** (silent, so the touch path measured is the song stage's own), and `AudioCalibration` (pure, tested) takes the average lateness of the taps against the nearest beat, ignores taps more than 0.3 s from every beat, needs at least 4 usable taps and clamps to ±150. A positive result means "taps arrive late", which is the engine's sign (it judges `songTime − offset`). The click is a piano sample played through `playSound(key:)`, so it shares the notes' audio latency. Decisions: (a) **Reset keeps the settings** (note speed, labels, offset, later the SFX switch), the `LevelN` question sets and `isPreplayDone`; the plan's literal reading ("every key in §3.4") would also wipe the settings, but they are preferences and wiping a calibration is annoying. (b) Reset removes keys by exact name or prefix (`ProgressStore.isResettableKey`, tested, including song-title trophy flags) and then re-runs the chapter migration, which writes `campaign_grantedChapter = 1`, so a fresh profile opens the tour at chapter 1; `SettingsView` also reloads `AchievementStore`. (c) Settings live in `ProgressStore+Game.swift` next to `labelsInPerform`; `approachTime` falls back to 2.0 if the stored value isn't one of the four choices. **Verified in the iPad Air simulator:** Settings from Home, the note-speed and slider cards, the Audio and Reset cards after scrolling, About reading "Version 1.2 (1)", the calibration screen (idle → running with the dots filling as the clicks play → "We didn't catch enough taps" because my automated tapping can't keep a beat). **Not verified, please check by hand:** a real calibration run (the suggested value, "Use +N ms"), that a changed note speed or offset is really felt in Perform, the two reset alerts (the logic is unit-tested, the alerts themselves were not tapped), and the layout on an iPad mini.
- **6.5** — **Phase 6 (the meta systems) is complete.** The seven new badges are in `AchievementStore`, with the plan's Indonesian titles and a short Indonesian description each: Panggung Pertama (`stat_songsPerformed ≥ 1`), Tanpa Cela (`stat_fullCombos ≥ 1`), Telinga Emas (`stat_echoBestRounds ≥ 10`), Pemburu Fals (`stat_bossesDefeated ≥ 3`), Dari Sabang Sampai Merauke (`stat_tourCompletedAt` is set, which is when the finale gets its first star), Kilat (`rush_highScore ≥ 100`) and Kolektor (3 bought shop items; the free defaults don't count). All read stats that earlier tasks already write, so nothing new is stored. Decisions: (a) `AchievementStore.init(defaults:progress:)` is now injectable (the app still uses `shared`), so the conditions are unit-tested against a throwaway suite, including one end-to-end test through `ResultRecorder`. (b) Nothing used to show a new badge: `RewardSummary.newAchievements` was filled but never displayed. I added `AchievementBanner` ("Achievement unlocked!" plus the titles) to the results screen and, because **Kolektor is the one badge earned outside a play**, the shop shows it for 3.5 s after the purchase that triggers it (`ShopView` now calls `AchievementStore.evaluate()` after `buy`). (c) The titles and descriptions are still hardcoded Indonesian strings as before, so an English device shows Indonesian badge names; Task 7.3 localises them. (d) The symbols are `music.mic`, `checkmark.shield.fill`, `ear.fill`, `shield.fill`, `flag.fill`, `bolt.fill` and `bag.fill`, all available on iOS 16. (e) A player who already met a condition earlier (say a Rush score over 100) gets the badge at their next play. **Verified in the iPad Air simulator** with seeded stats (Rush 120, 3 bosses, 2 performs, 10 Echo rounds): a lost Rush run ended on "Game over" with the banner "Achievement unlocked! Panggung Pertama · Telinga Emas · Pemburu Fals · …", and the Achievements screen showed the new cards, earned ones highlighted. **Not verified, please check by hand:** the shop banner after buying a third item, a real Tanpa Cela / Dari Sabang Sampai Merauke unlock, and the banner on a result with a long list of badges (it wraps to two lines).
- **7.1** — The effects are pure maths in `Models/Game/GameFeel.swift` (tested) that the views only draw. *Perfect burst:* `HitBurst` fans 6–10 circles (the count comes from a seed made of the key and the hit time, so bursts differ) out of the hit line over the upper half circle for 0.3 s; they slow down, shrink and fade, alternating yellow and white. `NoteHighwayView` draws them in the same `Canvas` from `engine.recentEvents` (judgment `.perfect` only, so Great and Good get none). *Lane flash:* `LaneFlashes` (a plain class, not published, read every frame like the notes) remembers each key's last key-down; the highway lights that lane from the hit line upward at 28 % white and fades it over 0.25 s. It is fed from the keyboard's `onNoteOn` in every mode that takes input (Practice and Perform); Listen's autoplay presses nothing, so nothing flashes there. *Combo pulse:* the combo number in the HUD swells to 1.6× and springs back on every 10th hit (`ComboPulse.isMilestone`), which is also when the multiplier steps up. *Stars stamp:* the results' gold star now lands on its empty outline at 2.4× size and tilted −25°, then springs down to 1× (it only fades under Reduce Motion); the coin count-up already ticked up from 6.1 and the unlock banner arrived in 6.5. **Reduce Motion** removes the bursts and the combo pulse and leaves the lane flash, which is only a fade. **Solemn songs** get none of the three (no lane flash, no burst, no pulse), as before: the plan says they stay calm. Decisions: (a) SongStageView reads `accessibilityReduceMotion` and passes it to the highway; (b) the lane flash is drawn behind the notes and the hit line, so a falling note stays readable on top of it. **Verified in the iPad Air simulator:** Practice on Berkibarlah Benderaku with the new draw code running (no crash, notes in their lanes), and a key tap leaving the lane flash visible in the screenshot taken just after. **Not verified, please check by hand:** the Perfect bursts and the combo pulse (they need real on-time hits in Perform), the star stamp on a 3-star result, and that Reduce Motion and a solemn song really show none of them.
- **7.2** — **Conversion:** macOS `afconvert` reads Ogg Vorbis directly on this Mac, so no ffmpeg was needed. `Scripts/convert_sfx.sh` turns the chosen Kenney files into **16-bit PCM `.caf`** (not `.m4a`: AAC adds about 45 ms of encoder delay, which would swallow the 10 ms clicks) and writes `Melodissimo/Data/Sound/sfx_*.caf` (388 KB in all). To swap a sound, change its source name in the script and run it again. **I chose the sounds by name and length, not by ear** (the sandbox has no speakers), so please listen: perfect = `glass_002`, miss = `drop_002`, wrong = `error_001`, coin = `confirmation_003`, star = `confirmation_002`, unlock = `confirmation_004`, monster hit = `drop_003`, player hurt = `error_003`, tick = `tick_004`, button = `click_001`. They keep Kenney's own levels (no loudness normalisation beyond the 0.6 volume), so some may need a different pick. **`SFX`** (`Services/SFX.swift`): `SFX.play(.perfect)` etc. Each effect has its own cache of 3 `AVAudioPlayer`s used in turn, so rapid Perfects overlap instead of restarting, at volume 0.6 beside the note samples; a missing or undecodable file, or the setting being off, is a silent no-op (`play` returns `false`). `SFX.shared.preload()` runs at launch next to `preloadAllSounds()`; I made `configureAudioSessionIfNeeded()` internal so `SFX` shares the notes' audio session. **Hooks:** a click on every game-flow button through a drop-in **`SoundButton`** (same call shape as `Button { … } label: { … }`; used on Home, Free Play, Learn, results, stage setup, the pause / finish overlays, the shop, Settings, the map, the stage sheet, story cards, the certificate, the song and level lists, Achievements, Battle, Echo); Perfect and Miss in Perform, wrong key in Practice and Perform, a tick for each 3-2-1 of the count-in; monster hit and player hurt in Battle and Rush; wrong key and round-cleared (star) in Echo; each star as it stamps in, then the coin sound as the coins start counting, then the unlock fanfare for a new badge or a new high score on the results; the coin sound on a shop purchase; the unlock fanfare when the map's avatar hops to a newly opened stage. **Solemn songs are silent** (no effects at all, not even the count-in ticks). The Settings card **Sound effects** (`settings_sfxEnabled`, default on, kept by a progress reset) switches all of them off, and About credits Kenney.nl (CC0). Decisions: (a) Great and Good have no sound (a ting on every hit would be tiring beside the melody); (b) the calibration screen and the DEBUG chart recorder keep plain `Button`s so their clicks don't mix with the metronome; (c) the old screens (the pre/post-play quizzes, Help, the learn lessons) have no clicks. **Verified:** a test that every one of the ten files is in the app bundle and decodes (it would fail if a conversion were missing), that a missing file does nothing, and that nothing plays while the setting is off; and the Settings card in the iPad Air simulator. **Not verified, please check by ear on a real iPad:** every sound listed above, that the Perfect ting doesn't clash with the melody, that the count-in ticks line up with the numbers, that effects and note samples mix without cutting each other off, and the volume balance.
- **7.3** — *Onboarding:* the pre-play score screen's button now says **"Start the Tour"** (it used to say "Menu") and opens `DashboardView(startsFirstStage: true)`, which, a beat after appearing and only for a player with no tour stars who hasn't seen the bubbles, pushes **the map and then stage `c1-01`** (so "Next" and "Back" from that stage land on the map). `CoachMarkOverlay` (`Views/Common`) dims the screen with a lit-up hole over the target, a yellow outline and a bubble with Alpanica, dots, **Skip** and **Next / Got it!**; it swallows taps, so the keyboard underneath can't be played during the tour. `BattleView` marks three targets (`.coachTarget`): the speech bubble, the keyboard and the hearts; the bubbles are shown only on `c1-01` while it has no star, `coach_seen_firstStage` isn't set, and the battle has no timer (it is the timer-less "Meet the notes" stage), and finishing or skipping stores the flag (a progress reset clears it again). **Deviations from the plan's wording:** `c1-01` is a monster battle, not a falling-notes stage, so the second bubble says "Play the key that matches the note" instead of "Play the key under the falling note", and the third says "Hearts you keep become stars. Stars unlock the next stage." (in a battle the stars *are* the hearts left). *Help:* rewritten with a section per mode (Nusantara Tour, Song Stage, Note Battle and Rush, Echo, Daily Challenge, coins and the shop), then the skill test, a new "how do I change speed, labels or sound", and the common questions kept from before. The old quiz section's "pressed tiles at least 2 seconds" bullet is gone, and so is the same sentence in the tutorial shown before the pre-play test (both said 2 seconds; they now say the answer counts when you lift your finger), and the Song Quiz bullet (that mode became Song Stage). *Localization:* the achievement titles and descriptions are now English keys with Indonesian translations (they were hardcoded Indonesian, so an English iPad showed Indonesian); the streak chip says "N days" / "N hari"; I added the strings the earlier tasks and my new screens lacked, including some that were already untranslated before this task: "< Back" (15 screens), "Score:", "Start Quiz", "Learn Song Notation Repository", the Help e-mail line and **the share text, whose key had drifted from the code so it never matched its Indonesian line** (it was shown in English). The grid title "Menu Level" is now "Classic Levels" to match its Free Play card. The "< Back" buttons are `minWidth: 120` and grow with the text, because "< Kembali" was cut off at the old fixed 120 pt. `LocalizationTests` now guard the catalogues (every achievement, Help string, coach bubble and the settings strings must have an Indonesian entry; no key may appear twice in the source file; nothing may say "2 seconds"). **Verified in the iPad Air simulator set to Bahasa Indonesia (`-AppleLanguages (id)`):** Home (Tur Nusantara, Mulai, Main Bebas, Belajar, Tantangan Harian), the stage sheet, all three coach bubbles on `c1-01` with their highlights (and that finishing them leaves the battle playable), the rewritten Help page and the fitted "< Kembali" button. **Not verified, please check by hand:** the very first launch end to end (First launch → Tutorial → pre-play quiz → score → "Start the Tour" → map → `c1-01` with the bubbles; I couldn't answer the pre-play quiz by automation, so the hop from the score screen to the stage is covered only by the code path I walked through above), the other screens in Indonesian (Settings, results, shop, achievements, Echo), and Help's expanded text.
- **7.4** — **Phase 7 is complete.** *Cleanup (every reference was grepped first):* deleted `NotationQuizView`, `NotationQuizCorrectAnswerView`, `NotationQuizIncorrectAnswerView`, `NotationQuizFiveLevelPassedView`, `SongQuizView`, `SongQuizScoreView` and the two menus Home no longer reaches, `NotationMenuView` and `SongMenuView`, plus the routes only they used (`.notationMenu`, `.songMenu`, `.notationQuiz`, `.songQuiz`, `.afterQuiz`) and the unused touch helpers in `ViewExtension.swift` (`onTouchDownUp`, `TouchLocatingView`, `onTouch`; this also removes two compiler warnings). **`AfterQuizView` stays**, trimmed to the pre-play and post-play score screens, because those two tests still end through `PianikaStackQuiz`'s navigation link; for the same reason `PianikaStackQuiz` stays, without its `autoNavigateOnFinish` switch, and the mini quiz keyboard (`PianikaStackQuizMini`) went with Song Quiz. The "Menu" button on the song list and the level grid used `router.pop(to:)` on the deleted routes, which (not being on the stack) already popped to Home, so they now say `popToRoot()`: **same behaviour, honest code**. Images: removed the three unreferenced menu buttons (`Assets.xcassets/Button`), `paper` and `bulb` (about 700 KB). I kept the other imagesets that nothing names literally, because they are loaded by built string (`fals_boss_N`, `map_island_N`, `tutorialSlider N`, the outfit names, the song notation sheets) or look like your artwork (`alpanicaCrown`, `alpanicaCrownGlasses`, `artwork`, `pianikaButton`, `pianikaNot`, `pianikaSplashscreen`; delete them yourself if they're dead). `id.lproj` keeps the lines for the deleted screens (unused, harmless). `SongProgressTests` used `.songMenu` as an arbitrary route and now uses `.freePlay`. *Performance:* **Instruments' Time Profiler** was recorded with `xctrace` on a running Listen stage (Berkibarlah Benderaku, 12 s) on an **iPad mini (6th generation) simulator on iOS 17.0**, the oldest runtime that can install the app (the deployment target is 16.6, so the iOS 16.2 simulators refuse it). Result on this Mac (an M1 running the simulator, so it flatters an iPad): the main thread used **16.4 % of one core = 2.7 ms per 60 Hz frame for everything the app does**, of which `NoteHighwayView.draw` was 0.25 ms and `RhythmEngine.step` 0.34 ms. The one real waste was that the highway rebuilt the canvas symbols for **all 32 key labels every frame** (Swift metadata lookups were 177 ms of the 12 s); it now builds only the labels of the keys the song uses, and a second trace of the same stage shows 15.0 % / 2.5 ms per frame and metadata lookups down to 111 ms (the two windows aren't identical, so read it as "a bit lower", not as a precise gain). Because that song only shows 3 to 5 notes at once, `HighwayPerformanceTests` renders the real highway offscreen with a **synthetic chart that has 10+ notes in view** (16 at 2 s approach): about **3.3 ms per frame** (61 renders in 0.2 s, each with a fresh `ImageRenderer`, so an upper bound), asserted below the 16.7 ms frame budget. Two cheap things I left alone: in Listen each note's `playSound` costs about 9 ms on the main thread in the display-link step (Perform plays on touch instead), and `stopListenSound` about 3 ms. **Not done, please check on a real iPad:** the Core Animation FPS gauge or an Animation Hitches trace on hardware (the simulator has no GPU frame pacing, so I can't claim 60 fps there, only that the CPU cost is a fraction of the frame), Perform with real touches and judgment popups, and a long-running stage for memory growth. The Time Profiler recipe, for next time: `xcrun xctrace record --template "Time Profiler" --device <simulator udid> --attach Melodissimo --time-limit 12s --output stage.trace`, then `xctrace export --input stage.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'`.
- **8.1** — User said "execute them all", which I took as the go-ahead for this ⚠︎ task (no separate plan round). `PitchDetector` (YIN, threshold 0.15, 165–1100 Hz, parabolic refinement), `PitchMapper` (Hz → MIDI → `semitone = midi − 53` → key id) and `OnsetDetector` (RMS gate 0.01, same key in 2 frames, a new onset needs another key or silence) are pure and tested (`PitchDetectorTests`: five sine frequencies within a semitone, 48 kHz, silence/noise, onset rules). `MicrophoneInput` (`Services/`) runs an `AVAudioEngine` tap (2048 buffer, hop 1024) on its own queue in a `.playAndRecord` / `.measurement` / `.defaultToSpeaker` session, and puts the session back to `.playback` on stop. The onset's time is the **host time of the first confirmed frame**, passed straight to `engine.press(keyId:now:)` (both clocks are the mach host clock). Mic mode = `settings_inputMode == pianika` and the stage is Practice or Perform: `PianoKeyboard(playsSound: false)`, the heard key drawn pressed, and `RhythmEngine(windowBonus: Judge.microphoneBonus)` widens every window by 50 ms (`Judge.judge(delta:bonus:)`). Settings has an **Input** card (Touch / Real pianika) and a "Test the microphone" screen (`MicCalibrationView`, "Play 1 (C)", live detected note). `NSMicrophoneUsageDescription` is in `Data/Info.plist` with en + id `InfoPlist.strings`. **Not verified with a real pianika** (the simulator has no instrument): please try it on an iPad, and tune `MicrophoneInput.noiseGate` if a quiet instrument is missed or room noise triggers notes. `RhythmEngine.swift` was committed together with your uncommitted `stopListenSound()` hunks.
- **8.2** — The merge rules are one pure type, `CloudMerge` (`Models/Progress/`, tested in `CloudSyncTests`): numbers keep the larger value (scores, stars, stage stars, coin totals, stats, `currentLevel`, `bestCombo`, `longestStreak`, high scores), flags are OR-ed (achievements, practiced / full-combo, daily done, story and coach seen, `isPreplayDone`, the legacy trophy booleans keyed by song title), `shop_owned` is unioned, `equip_*` stays local unless missing, `stat_tourCompletedAt` keeps the **earliest** day (a max would move the certificate date forward), and `currentStreak` + `lastPlayedDate` travel together from whichever device played last. Settings (`settings_*`) and the `Level1…100` question sets never sync. `CloudSync` (`Services/`) merges in both directions at launch, on `didChangeExternallyNotification`, and 1 s after any `UserDefaults` change; it does nothing when `ubiquityIdentityToken` is nil. `resetProgress()` also removes the synced keys from iCloud so the old progress isn't merged straight back (a second device that still holds it can bring it back; that is the cost of max-merge). **Still [USER]:** add the iCloud capability with **Key-value storage** in Xcode (Signing & Capabilities) so the app has the `com.apple.developer.ubiquity-kvstore-identifier` entitlement; I did not touch signing or the entitlements. Until then `NSUbiquitousKeyValueStore` stays empty and the sync is a harmless no-op. Not tested across two real devices.
- **8.3** — `GameCenter.authenticate()` (called at launch) sets the `authenticateHandler` and **ignores any sign-in sheet the system offers**, so a child is never shown Apple's login; if they aren't signed in nothing is posted. `ResultRecorder` hands `LeaderboardSubmissions.scores(for:tourStars:)` (pure, tested) to an injectable `submitScores` closure at the end of every play: Rush posts its score, endless Echo and Echo stages post rounds cleared, and any play launched from the campaign map posts the tour's total stars. **Still [USER]:** (1) create three Classic leaderboards in App Store Connect with exactly the ids in `LeaderboardID` (`melodissimo.rush`, `melodissimo.echo`, `melodissimo.stars`, integer, high to low); (2) add the **Game Center** capability in Xcode (I did not touch signing or entitlements); (3) check the Kids Category rules before shipping: a leaderboard shows other players' Game Center aliases, which the Kids guidelines treat strictly, and I haven't verified how they apply. If in doubt, ship without calling `GameCenter.shared.authenticate()` (one line in `MelodissimoApp`). There is no leaderboard screen yet; this only posts scores. Not tested against real leaderboards.
- **2.6** — Left **unticked on purpose**: the plan's [USER] step is checking every chart in Listen mode, and I can't hear them. Using the optional shortcut, I drafted **17 of the 18 charts** from the score-sheet images into `Data/Charts/chart_<slug>.json` (bpm from each sheet, durations in beats). **Indonesia Raya is deliberately left on the default uniform chart**: it is the national anthem, its sheet is the hardest to read, and a wrong rhythm there would be disrespectful, so please record it yourself with the Chart Recorder. How they were made: I transcribed each sheet as `label:duration` tokens (a dot after a note extends it, underlines mean eighths / sixteenths, ties merge two notes), and a script (`generate` step, not kept in the repo) refused any transcription whose note labels differed from `LevelFeederModel.songLevel`, so **every chart has exactly the song's notes in order** (the `matchesMelody` test also covers this). Rhythm is the part to check. Known weak spots: (a) the app's melody differs from the sheet in a few places (ties and slurs the app melody merges or drops, e.g. Garuda Pancasila's last two lines, Hari Merdeka's repeated "5 1˙ 5 4 3", Terima Kasih Guru's bar 15, Rayuan Pulau Kelapa's last page, Merah Putih's 6-6-6 bar, Satu Nusa's slurred pairs); there I gave the notes plain 1-beat or 1.5/.5 values. (b) Ambiguous bars where I couldn't tell dotted-eighth + sixteenth from two eighths. (c) Leading rests are dropped, so every chart starts at beat 0 (pickup notes first), as the Chart Recorder does. (d) Repeats are played once. (e) **Tanah Airku** has only the first half because that is all the app's melody contains. (f) Hari Merdeka is 2/4 at bpm 100. Songs with no clear errors can be committed as they are; fix a bad bar by re-recording just that song with the recorder and overwriting its JSON.
- **Phase 9 (Backsound, `BACKSOUND_PLAN.md`)** — The song list is now the 16 songs of the backing recording, in its order (8 old songs retired, 6 added, "Merah Putih" renamed "Bendera Merah Putih" with its progress copied once), every song has a v2 chart (`offset` into `Data/Sound/Backing/bgm_<slug>.m4a`), the campaign has 49 stages (chapter notes shifted: c1 gained `5.` `7.`, c2 = `6.` `4.`, c3 = `2˙` `3˙`; Bangun Pemudi Pemuda is the chapter-6 boss) and the score sheet is drawn from the chart. **The DEBUG Chart Recorder writes charts *without* `offset`, so a song re-recorded with it loses its backing sync** (and the backing stays silent for it) until `Scripts/backsound/backsound.py build --only <slug>` is run again. The original `Notasi` PNGs are still in the asset catalog but unused. The backing track plays in Listen/Practice/Perform, pauses while Practice waits, is off in Real-pianika mode, and has a Settings toggle (`settings_backingTrack`). Copyright: the recording belongs to someone else; fine for personal and class use, ask permission or replace the tracks before a release.
