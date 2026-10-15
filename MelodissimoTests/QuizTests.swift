import XCTest
@testable import Melodissimo

final class QuizTests: XCTestCase {

    private let songs: [QuizSong] = [
        QuizSong(title: "A", keyIds: [5, 6, 7, 8, 9, 10, 11, 12, 11, 10], onsets: (0..<10).map { Double($0) * 0.5 }, isSolemn: false),
        QuizSong(title: "B", keyIds: [9, 9, 10, 9, 12, 11, 9, 9], onsets: (0..<8).map { Double($0) * 0.6 }, isSolemn: false),
        QuizSong(title: "C", keyIds: [12, 11, 10, 9, 8, 7, 6, 5], onsets: (0..<8).map { Double($0) * 0.7 }, isSolemn: false),
        QuizSong(title: "D", keyIds: [5, 7, 9, 12, 9, 7, 5, 5], onsets: (0..<8).map { Double($0) * 0.4 }, isSolemn: false),
        QuizSong(title: "Anthem", keyIds: [9, 12, 12, 12, 14, 12, 11], onsets: (0..<7).map { Double($0) }, isSolemn: true),
    ]

    private func config(_ variant: QuizVariant, seed: UInt64 = 7) -> QuizConfig {
        QuizConfig(variant: variant, questionCount: 10, hearts: 3, seed: seed)
    }

    // MARK: Generator

    func testTheSameSeedGivesTheSameQuestions() {
        for variant in QuizVariant.allCases {
            XCTAssertEqual(QuizQuestionGenerator.questions(for: config(variant), songs: songs),
                           QuizQuestionGenerator.questions(for: config(variant), songs: songs))
        }
    }

    func testGuessTheSongPlaysTheOpeningAndOffersFourDistinctTitles() {
        let questions = QuizQuestionGenerator.questions(for: config(.guessSong), songs: songs)
        XCTAssertEqual(questions.count, 10)
        for question in questions {
            XCTAssertEqual(question.choices.count, 4)
            XCTAssertEqual(Set(question.choices).count, 4)
            let song = songs.first { $0.title == question.choices[question.correctIndex] }!
            XCTAssertEqual(question.phrase, Array(song.keyIds.prefix(question.phrase.count)))
            XCTAssertTrue(QuizQuestionGenerator.openingNotes.contains(question.phrase.count))
            XCTAssertEqual(question.onsets.count, question.phrase.count)
        }
    }

    func testGuessTheSongUsesEverySongBeforeRepeating() {
        let questions = QuizQuestionGenerator.questions(for: config(.guessSong), songs: songs)
        let firstFive = questions.prefix(5).map { $0.choices[$0.correctIndex] }
        XCTAssertEqual(Set(firstFive).count, 5)
    }

    func testTheOpeningIsTheNotesOfTheFirstFewSecondsClamped() {
        let slow = QuizSong(title: "S", keyIds: Array(repeating: 5, count: 10), onsets: (0..<10).map { Double($0) * 2 }, isSolemn: false)
        let fast = QuizSong(title: "F", keyIds: Array(repeating: 5, count: 20), onsets: (0..<20).map { Double($0) * 0.2 }, isSolemn: false)
        XCTAssertEqual(QuizQuestionGenerator.openingLength(of: slow), 5)
        XCTAssertEqual(QuizQuestionGenerator.openingLength(of: fast), 8)
    }

    func testSpotFalsChangesExactlyOneNoteAfterTheFirstAndNeverUsesASolemnSong() {
        let questions = QuizQuestionGenerator.questions(for: config(.spotFals), songs: songs)
        XCTAssertEqual(questions.count, 10)
        for (index, question) in questions.enumerated() {
            XCTAssertEqual(question.phrase.count, index < 5 ? 5 : 6)
            let written = question.choices
            let played = question.phrase.map { NoteCatalog.note($0).label }
            let differences = zip(written, played).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
            XCTAssertEqual(differences, [question.correctIndex])
            XCTAssertGreaterThan(question.correctIndex, 0)
            let fromASong = songs.filter { !$0.isSolemn }.contains { song in
                let labels = song.keyIds.map { NoteCatalog.note($0).label }
                return (0...(labels.count - written.count)).contains { Array(labels[$0..<($0 + written.count)]) == written }
            }
            XCTAssertTrue(fromASong, "\(written) is not a slice of a non-solemn song")
        }
    }

    func testFalsNoteIsANearbyWhiteKey() {
        var rng = SeededRandom(seed: 3)
        for key in NoteCatalog.whiteKeyIDs {
            let replaced = QuizQuestionGenerator.falsNote(replacing: key, using: &rng)
            XCTAssertNotEqual(replaced, key)
            XCTAssertTrue((1...4).contains(abs(NoteCatalog.note(replaced).semitone - NoteCatalog.note(key).semitone)))
        }
    }

    func testHigherLowerAnswersMatchThePitches() {
        let questions = QuizQuestionGenerator.questions(for: config(.higherLower, seed: 11), songs: [])
        XCTAssertEqual(questions.count, 10)
        for (index, question) in questions.enumerated() {
            XCTAssertEqual(question.choices, QuizQuestionGenerator.higherLowerChoices)
            let a = NoteCatalog.note(question.phrase[0]).semitone, b = NoteCatalog.note(question.phrase[1]).semitone
            XCTAssertEqual(question.correctIndex, b > a ? 0 : (b < a ? 1 : 2))
            if index < 5, a != b { XCTAssertGreaterThanOrEqual(abs(a - b), 4) }
        }
    }

    // MARK: View model

    private func makeViewModel(_ variant: QuizVariant = .higherLower, played: Recorder = Recorder()) -> QuizViewModel {
        QuizViewModel(config: config(variant), songs: songs,
                      soundPlayer: { played.started.append($0) }, soundStopper: { played.stopped.append($0) })
    }

    final class Recorder {
        var started: [String] = []
        var stopped: [String] = []
    }

    func testPlaybackPlaysEachNoteAtItsOnsetThenWaitsForTheAnswer() {
        let recorder = Recorder()
        let vm = makeViewModel(played: recorder)
        vm.start(now: 0)
        vm.step(now: QuizViewModel.leadIn)
        XCTAssertEqual(vm.phase, .listening(index: 0))
        vm.step(now: QuizViewModel.leadIn + 0.9)
        XCTAssertEqual(vm.phase, .listening(index: 1))
        XCTAssertEqual(recorder.started.count, 2)
        vm.step(now: QuizViewModel.leadIn + 0.9 + QuizViewModel.tail)
        XCTAssertEqual(vm.phase, .answering)
        XCTAssertTrue(vm.canReplay)
    }

    func testARightAnswerScoresAndMovesOn() {
        let vm = makeViewModel()
        vm.start(now: 0)
        let right = vm.question!.correctIndex
        vm.answer(right, now: 1)
        XCTAssertEqual(vm.phase, .feedback(chosen: right, isCorrect: true))
        XCTAssertEqual(vm.correctCount, 1)
        vm.step(now: 1 + QuizViewModel.pauseAfterCorrect)
        XCTAssertEqual(vm.questionIndex, 1)
        XCTAssertEqual(vm.phase, .listening(index: -1))
    }

    func testThreeWrongAnswersLose() {
        let vm = makeViewModel()
        vm.start(now: 0)
        var now = 0.0
        for _ in 0..<3 {
            let wrong = (vm.question!.correctIndex + 1) % 3
            vm.answer(wrong, now: now)
            now += QuizViewModel.pauseAfterWrong
            vm.step(now: now)
        }
        XCTAssertEqual(vm.phase, .lost)
        XCTAssertEqual(vm.stars, 0)
    }

    func testAnsweringEveryQuestionWinsWithHeartsAsStars() {
        let vm = makeViewModel(.guessSong)
        vm.start(now: 0)
        var now = 0.0
        for index in 0..<vm.questions.count {
            let pick = index == 0 ? (vm.question!.correctIndex + 1) % 4 : vm.question!.correctIndex
            vm.answer(pick, now: now)
            now += QuizViewModel.pauseAfterWrong
            vm.step(now: now)
        }
        XCTAssertEqual(vm.phase, .won)
        XCTAssertEqual(vm.correctCount, 9)
        XCTAssertEqual(vm.bestStreak, 9)
        XCTAssertEqual(vm.stars, 2)
    }

    func testAnswersDoNotCountDuringFeedback() {
        let vm = makeViewModel()
        vm.start(now: 0)
        vm.answer(vm.question!.correctIndex, now: 0)
        vm.answer(vm.question!.correctIndex, now: 0.1)
        XCTAssertEqual(vm.correctCount, 1)
    }

    // MARK: Rewards

    func testAQuizPaysOneCoinPerRightAnswerAndKeepsTheBest() {
        let defaults = UserDefaults(suiteName: "QuizTests-\(UUID().uuidString)")!
        let progress = ProgressStore(defaults: defaults)
        let recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] }, submitScores: { _ in })
        func result(_ score: Int) -> PlayResult {
            var result = PlayResult(request: PlayRequest(kind: .quiz(config(.guessSong))), didWin: true, stars: 3,
                                    score: score, accuracy: nil, maxCombo: score,
                                    perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
            result.correctCount = score
            return result
        }
        let first = recorder.record(result(7))
        XCTAssertEqual(first.coins, 7)
        XCTAssertTrue(first.isNewBest)
        XCTAssertEqual(progress.quizBest(.guessSong), 7)
        XCTAssertFalse(recorder.record(result(5)).isNewBest)
        XCTAssertEqual(progress.quizBest(.guessSong), 7)
        XCTAssertEqual(progress.quizBest(.spotFals), 0)
    }
}
