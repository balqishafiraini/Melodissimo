import XCTest
@testable import Melodissimo

/// The Indonesian table (`id.lproj/Localizable.strings`) has to cover what the newer screens say.
final class LocalizationTests: XCTestCase {

    private var table: [String: String] = [:]

    override func setUpWithError() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "id"))
        table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    /// The keys in the source file, in order. The built bundle holds a compiled copy in which a repeated
    /// key has already been merged, so this reads the file in the repository.
    private func sourceKeys() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Melodissimo/Data/id.lproj/Localizable.strings")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw XCTSkip("the source strings file isn't next to the tests")
        }
        let text = try String(contentsOf: source, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^"((?:[^"\\]|\\.)*)"\s*="#, options: .anchorsMatchLines)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private func assertTranslated(_ key: String, allowSame: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        guard let translation = table[key] else {
            XCTFail("missing Indonesian for \"\(key)\"", file: file, line: line)
            return
        }
        if !allowSame {
            XCTAssertNotEqual(translation, key, "the Indonesian for \"\(key)\" is still English", file: file, line: line)
        }
    }

    func testNoKeyIsDefinedTwice() throws {
        var seen = Set<String>()
        var duplicates: [String] = []
        for key in try sourceKeys() where !seen.insert(key).inserted { duplicates.append(key) }
        XCTAssertEqual(duplicates, [])
    }

    // MARK: Achievements

    func testEveryAchievementTitleAndDescriptionIsTranslated() {
        // These two are the same word in Indonesian.
        let sameInBoth: Set<String> = ["Combo Master", "Maestro"]
        let store = AchievementStore(defaults: UserDefaults(suiteName: "LocalizationTests-\(UUID().uuidString)")!,
                                     progress: ProgressStore(defaults: UserDefaults(suiteName: "LocalizationTests-\(UUID().uuidString)")!))
        for achievement in store.achievements {
            assertTranslated(achievement.title, allowSame: sameInBoth.contains(achievement.title))
            assertTranslated(achievement.detail)
        }
    }

    func testTheNewBadgesKeepTheIndonesianTitlesFromThePlan() {
        XCTAssertEqual(table["First Show"], "Panggung Pertama")
        XCTAssertEqual(table["Flawless"], "Tanpa Cela")
        XCTAssertEqual(table["Golden Ear"], "Telinga Emas")
        XCTAssertEqual(table["Fals Hunter"], "Pemburu Fals")
        XCTAssertEqual(table["From Sabang to Merauke"], "Dari Sabang Sampai Merauke")
        XCTAssertEqual(table["Lightning"], "Kilat")
        XCTAssertEqual(table["Collector"], "Kolektor")
    }

    // MARK: Help

    func testEveryHelpStringIsTranslated() {
        let help = HelpPageView()
        XCTAssertGreaterThanOrEqual(help.sections.count, 10, "one section per mode plus the common questions")
        for section in help.sections {
            assertTranslated(section.title)
            for item in section.items {
                if case .text(let text) = item { assertTranslated(text) }
            }
        }
    }

    func testHelpHasASectionForEveryMode() {
        let titles = HelpPageView().sections.map(\.title)
        for expected in ["How to play the Nusantara Tour?", "How to play Song Stage?", "How to play Note Battle?",
                         "How to play Echo?", "What is the Daily Challenge?", "What are coins for?"] {
            XCTAssertTrue(titles.contains(expected), expected)
        }
    }

    func testNothingTellsThePlayerToPressForTwoSeconds() {
        let help = HelpPageView()
        for section in help.sections {
            for item in section.items {
                if case .text(let text) = item { XCTAssertFalse(text.contains("2 seconds"), text) }
            }
        }
        XCTAssertNil(table.keys.first { $0.contains("at least 2 seconds") }, "the old wording is gone from id.lproj too")
    }

    // MARK: Coach marks

    func testEveryCoachMarkBubbleIsTranslated() {
        for step in CoachMarks.firstStage {
            assertTranslated(step.text)
        }
        for word in ["Next", "Skip", "Got it!", "Start the Tour"] {
            assertTranslated(word)
        }
    }

    // MARK: Settings

    func testTheSettingsScreenIsTranslated() {
        for key in ["Note speed", "Key labels", "Show key labels in Perform", "Sound effects", "Sound effects on",
                    "Audio timing", "Tap to the beat", "Reset progress", "Reset progress?", "Are you really sure?",
                    "Erase everything", "About", "Version %@", "Achievement unlocked!", "< Back", "Score:"] {
            assertTranslated(key)
        }
    }
}

final class CoachMarksTests: XCTestCase {

    func testThereAreThreeBubblesInTheOrderOfThePlan() {
        XCTAssertEqual(CoachMarks.firstStage.map(\.target), [.question, .keyboard, .hearts])
        XCTAssertEqual(CoachMarks.firstStage[0].text, "These numbers are notes")
        XCTAssertTrue(CoachMarks.firstStage[2].text.contains("Stars unlock the next stage"))
    }

    func testTheyAreShownOnlyOnTheFirstStageWithNoStarsAndOnlyOnce() {
        XCTAssertTrue(CoachMarks.shouldShow(stageId: "c1-01", stars: 0, seen: false))
        XCTAssertFalse(CoachMarks.shouldShow(stageId: "c1-01", stars: 0, seen: true), "already seen")
        XCTAssertFalse(CoachMarks.shouldShow(stageId: "c1-01", stars: 1, seen: false), "already played")
        XCTAssertFalse(CoachMarks.shouldShow(stageId: "c1-02", stars: 0, seen: false), "another stage")
        XCTAssertFalse(CoachMarks.shouldShow(stageId: nil, stars: 0, seen: false), "free play")
    }

    func testTheFirstStageIsAMonsterBattleWithNoTimer() throws {
        // The bubbles are shown over a battle that waits for the player, so it has to have no timer.
        let stage = try XCTUnwrap(CampaignCatalog.stage(id: CoachMarks.firstStageId))
        guard case .battle(let config) = stage.kind else { return XCTFail("c1-01 should be a battle") }
        XCTAssertNil(config.timePerNote)
        XCTAssertEqual(CampaignCatalog.allStages.first?.id, CoachMarks.firstStageId)
    }

    func testSeenIsStoredAndAProgressResetShowsTheBubblesAgain() {
        let suite = "CoachMarksTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        XCTAssertFalse(progress.isCoachSeen(CoachMarks.seenId))
        progress.markCoachSeen(CoachMarks.seenId)
        XCTAssertTrue(progress.isCoachSeen(CoachMarks.seenId))
        progress.resetProgress()
        XCTAssertFalse(progress.isCoachSeen(CoachMarks.seenId))
    }
}
