//
//  QARoutes.swift
//  Melodissimo
//

#if DEBUG
import SwiftUI

/// DEBUG-only launch hooks for the screenshot scripts in `Scripts/iphone` (see `IPHONE_PLAN.md` §3.5).
///
/// They read launch arguments such as `-qaRoute stageListen`. `UserDefaults` serves `-key value` arguments
/// from a volatile domain, so nothing is written to disk. Without the arguments none of this runs, and the
/// whole file is compiled out of Release builds.
///
/// | argument | effect |
/// |---|---|
/// | `-qaSkipSplash YES` | the splash hands over to the first screen at once |
/// | `-qaRoute <name>` | Home pushes that screen on launch (names in `routes(for:)`) |
/// | `-qaSong <slug>` | which song `songLearn`, `stage*` and `result*` use (default: the first non-solemn one) |
/// | `-qaOnboarding <name>` | shows that first-run screen instead of the normal flow |
/// | `-qaOverlay story\|storyBoss\|certificate` | the campaign map opens that overlay on appear |
/// | `-qaSeed YES` | fills the profile with a mid-game player (see `seedProfile()`) |
///
/// The scripts also pass `-AppleLanguages (en)` so every device renders English, whatever the simulator's language.
enum QARoutes {

    private static var didApplyRoute = false

    private static func argument(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static var skipsSplash: Bool { UserDefaults.standard.bool(forKey: "qaSkipSplash") }
    static var overlay: String? { argument("qaOverlay") }

    // MARK: Orientation

    /// Writes the interface orientation to `Documents/qa-orientation.txt`, so `Scripts/iphone/shot.sh` can turn the
    /// simulator's portrait framebuffer the right way up (the simulator may be in either landscape orientation).
    @MainActor
    static func recordOrientation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let name: String
            switch scene?.interfaceOrientation {
            case .landscapeLeft?: name = "landscapeLeft"
            case .landscapeRight?: name = "landscapeRight"
            case .portrait?: name = "portrait"
            case .portraitUpsideDown?: name = "portraitUpsideDown"
            default: name = "unknown"
            }
            writeDocument(name, to: "qa-orientation.txt")
            // First-run screens have no route to wait for; the route path reports itself in `applyLaunchRoute`.
            if hasOnboardingScreen { markReady() }
        }
    }

    /// Tells `Scripts/iphone/capture.sh` that the requested screen has been pushed and may be photographed
    /// (after the script's own settle time). Without this the script would have to guess from the pixels.
    static func markReady() {
        writeDocument("ready", to: "qa-ready.txt")
    }

    private static func writeDocument(_ text: String, to file: String) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? text.write(to: documents.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    // MARK: Routes

    /// Pushes the screen named by `-qaRoute`, once per launch.
    @MainActor
    static func applyLaunchRoute(to router: AppRouter) {
        guard !didApplyRoute, let name = argument("qaRoute") else { return }
        didApplyRoute = true
        guard let routes = routes(for: name) else {
            print("QARoutes: unknown route '\(name)'")
            return
        }
        // A beat after Home appears, so the stack is ready to take the pushes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            routes.forEach { router.push($0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { markReady() }
        }
    }

    /// `-qaSong <slug>`, or the first song that is not solemn (so the concert stage, combo and boss art show).
    private static var song: Song {
        argument("qaSong").flatMap(SongLibrary.song(id:)) ?? SongLibrary.all.first { !$0.isSolemn } ?? SongLibrary.all[0]
    }

    private static func songRequest(_ mode: StageMode, isBoss: Bool = false, stageId: String? = nil) -> Route {
        .play(PlayRequest(kind: .song(songId: song.id, mode: mode, speed: 1, isBoss: isBoss,
                                      isSolemn: song.isSolemn, noteLimit: nil),
                          campaignStageId: stageId))
    }

    private static func firstStage(where matches: (Stage.Kind) -> Bool) -> Stage? {
        CampaignCatalog.allStages.first { matches($0.kind) }
    }

    /// The screens `-qaRoute` can open. `nil` for a name that isn't one of them.
    static func routes(for name: String) -> [Route]? {
        switch name {
        case "dashboard": return []
        case "freePlay": return [.freePlay]
        case "learnHub": return [.learnHub]
        case "campaignMap": return [.campaignMap]
        case "shop": return [.shop]
        case "settings": return [.settings]
        case "achievements": return [.achievements]
        case "help": return [.help]
        case "notationLearn": return [.notationLearn]
        case "songRepositoryLearn": return [.songRepositoryLearn]
        case "songRepositoryQuiz": return [.songRepositoryQuiz]
        case "notationLevelMenu": return [.notationLevelMenu]
        case "postplay": return [.postplay]
        case "chartRecorder": return [.chartRecorder]
        case "songLearn": return [.songLearn(songTitle: song.title)]
        case "stageSetup": return [.stageSetup(songId: song.id)]
        case "stageListen": return [songRequest(.listen)]
        case "stagePractice": return [songRequest(.practice)]
        case "stagePerform": return [songRequest(.perform)]
        case "stageSolemn":
            // A solemn song (no monster, no flames): `-qaSong` is ignored here.
            guard let solemn = SongLibrary.all.first(where: \.isSolemn) else { return nil }
            return [.play(PlayRequest(kind: .song(songId: solemn.id, mode: .perform, speed: 1, isBoss: false,
                                                  isSolemn: true, noteLimit: nil)))]
        case "stageBoss":
            guard let boss = firstStage(where: { if case .boss = $0 { return true } else { return false } })
            else { return nil }
            return [songRequest(.perform, isBoss: true, stageId: boss.id)]
        case "battle":
            guard let stage = firstStage(where: { if case .battle = $0 { return true } else { return false } }),
                  case .battle(let config) = stage.kind else { return nil }
            return [.play(PlayRequest(kind: .battle(config), campaignStageId: stage.id))]
        case "battleBoss":
            // A boss battle: the timer shrinks with every answer.
            var config = BattleConfig(newPool: [5, 6, 7, 8, 9], questionCount: 10, timePerNote: 4, seed: 7)
            config.isBoss = true
            return [.play(PlayRequest(kind: .battle(config)))]
        case "echo":
            guard let stage = firstStage(where: { if case .echo = $0 { return true } else { return false } }),
                  case .echo(let config) = stage.kind else { return nil }
            return [.play(PlayRequest(kind: .echo(config), campaignStageId: stage.id))]
        case "rush": return [.play(PlayRequest(kind: .rush))]
        case "classic": return [.play(PlayRequest(kind: .classic(levelNo: 1)))]
        case "result3": return [result(stars: 3)]
        case "result0": return [result(stars: 0)]
        default: return nil
        }
    }

    /// A finished Perform run with a synthetic result: 3 stars (a new best, a coin reward, an achievement) or 0.
    private static func result(stars: Int) -> Route {
        let request = PlayRequest(kind: .song(songId: song.id, mode: .perform, speed: 1, isBoss: false,
                                              isSolemn: song.isSolemn, noteLimit: nil))
        if stars == 0 {
            return .result(PlayResult(request: request, didWin: false, stars: 0, score: 3_200, accuracy: 41,
                                      maxCombo: 6, perfect: 8, great: 6, good: 5, miss: 31, wrong: 9),
                           RewardSummary())
        }
        return .result(PlayResult(request: request, didWin: true, stars: 3, score: 18_450, accuracy: 96.5,
                                  maxCombo: 52, perfect: 44, great: 8, good: 2, miss: 1, wrong: 0),
                       RewardSummary(coins: 35, newStars: 3, isNewBest: true, newAchievements: ["Bintang Tiga"]))
    }

    // MARK: Onboarding

    /// The first-run screen named by `-qaOnboarding`, or `nil` for the normal flow.
    @MainActor @ViewBuilder
    static func onboardingScreen() -> some View {
        switch argument("qaOnboarding") {
        case "first": FirstLaunchView()
        case "tutorial": NavigationView { TutorialView() }.navigationViewStyle(.stack)
        case "preplay": NavigationView { PreplayView(levelNo: 1) }.navigationViewStyle(.stack)
        case "preplayScore": NavigationView { PreplayScoreView(score: 6) }.navigationViewStyle(.stack)
        case "onboardPostplay": NavigationView { OnboardPostplayView() }.navigationViewStyle(.stack)
        case "postplay": NavigationView { PostplayView(levelNo: 1) }.navigationViewStyle(.stack)
        case "postplayScore": NavigationView { PostplayScoreView(score: 8) }.navigationViewStyle(.stack)
        default: EmptyView()
        }
    }

    static var hasOnboardingScreen: Bool { argument("qaOnboarding") != nil }

    // MARK: Overlays

    /// The overlay `-qaOverlay` asks the campaign map to open on appear.
    static func mapOverlay() -> (card: StoryCard?, certificate: Bool)? {
        switch overlay {
        case "story": return (StoryCatalog.cards.first, false)
        case "storyBoss": return (StoryCatalog.cards.first { $0.kind == .bossDefeated }, false)
        case "certificate": return (nil, true)
        default: return nil
        }
    }

    // MARK: Seed

    /// A mid-game profile for realistic screenshots: chapters 1–2 cleared (40 stars), chapter 3 next, 500 coins,
    /// three shop items owned (a keyboard skin worn), every song practiced, a 4-day streak, and every story card and
    /// coach mark already seen. Written to the simulator's own `UserDefaults`; `simctl uninstall` clears it.
    static func seedProfile() {
        guard UserDefaults.standard.bool(forKey: "qaSeed") else { return }
        let defaults = UserDefaults.standard

        for stage in CampaignCatalog.allStages where stage.chapter <= 2 {
            let stars = stage.chapter == 1 ? 3 : (stage.index <= 8 ? 2 : 1)
            defaults.set(stars, forKey: "stage_stars_\(stage.id)")
        }
        defaults.set(950, forKey: "coins_earnedTotal")
        defaults.set(450, forKey: "coins_spentTotal")
        defaults.set(["keyboard_batik", "notes_rainbow", "outfit_glasses"], forKey: "shop_owned")
        defaults.set("keyboard_batik", forKey: "equip_keyboard")
        defaults.set(4, forKey: "currentStreak")
        defaults.set(7, forKey: "longestStreak")
        defaults.set(Date(), forKey: "lastPlayedDate")
        for (index, song) in SongLibrary.all.enumerated() {
            defaults.set(true, forKey: "song_practiced_\(song.id)")
            if index < 3 {
                defaults.set(3, forKey: "song_stars_\(song.id)")
                defaults.set(12_000 + index * 1_500, forKey: "song_bestScore_\(song.id)")
                defaults.set(92.0 + Double(index), forKey: "song_bestAccuracy_\(song.id)")
            }
        }
        for card in StoryCatalog.cards { defaults.set(true, forKey: "story_seen_\(card.id)") }
        defaults.set(true, forKey: "coach_seen_\(CoachMarks.seenId)")
    }
}
#endif
