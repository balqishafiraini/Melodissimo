import XCTest
@testable import Melodissimo

final class EchoViewModelTests: XCTestCase {

    private final class Recorder {
        var played: [String] = []
        var stopped: [String] = []
    }

    private func config(pool: [Int] = [5, 6, 7, 8, 9],
                        rounds: Int? = 3,
                        startLength: Int = 2,
                        maxLength: Int = 8,
                        glow: Bool = true,
                        snippets: Bool = false,
                        hearts: Int = 3,
                        seed: UInt64 = 1) -> EchoConfig {
        EchoConfig(pool: pool, roundsToClear: rounds, startLength: startLength, maxLength: maxLength,
                   glowDuringPlayback: glow, useSongSnippets: snippets, hearts: hearts, seed: seed)
    }

    private func makeVM(_ config: EchoConfig, songs: [[Int]] = [], log: Recorder = Recorder()) -> EchoViewModel {
        EchoViewModel(config: config, songs: songs,
                      soundPlayer: { log.played.append($0) },
                      soundStopper: { log.stopped.append($0) })
    }

    /// Runs time forward in 50 ms steps until the phrase has finished playing and returns the final `now`.
    @discardableResult
    private func listen(_ vm: EchoViewModel, from now: CFTimeInterval) -> CFTimeInterval {
        let duration = EchoViewModel.leadIn + Double(vm.phrase.count) * EchoViewModel.noteInterval
        let steps = Int((duration / 0.05).rounded(.up)) + 2
        var t = now
        for i in 0...steps {
            t = now + Double(i) * 0.05
            vm.step(now: t)
        }
        return t
    }

    /// Plays the current phrase correctly and returns `now` after the last key.
    @discardableResult
    private func playBack(_ vm: EchoViewModel, at now: CFTimeInterval) -> CFTimeInterval {
        for key in vm.phrase { vm.answer(keyId: key, now: now) }
        return now
    }

    // MARK: Phrase generation

    func testLengthScheduleGrowsByOneEveryTwoRounds() {
        let lengths = (0..<14).map { EchoPhraseGenerator.length(forRound: $0, startLength: 2, maxLength: 8) }
        XCTAssertEqual(lengths, [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8])
        XCTAssertEqual(EchoPhraseGenerator.length(forRound: 40, startLength: 2, maxLength: 8), 8, "capped at maxLength")
        XCTAssertEqual(EchoPhraseGenerator.length(forRound: 0, startLength: 3, maxLength: 8), 3)
    }

    func testPhrasesStayInThePoolAndMoveByAtMostTwoPositions() {
        // Ids are not in pitch order: semitones are 0, 1, 2, 3, 4, 7, 9.
        let pool = [3, 21, 1, 5, 2, 20, 6]
        let sorted = EchoPhraseGenerator.sortedPool(pool)
        XCTAssertEqual(sorted, [1, 20, 2, 21, 3, 5, 6])
        var rng = SeededRandom(seed: 3)
        for length in 2...8 {
            for _ in 0..<200 {
                let phrase = EchoPhraseGenerator.randomWalk(pool: pool, length: length, using: &rng)
                XCTAssertEqual(phrase.count, length)
                XCTAssertTrue(phrase.allSatisfy(pool.contains))
                let positions = phrase.map { sorted.firstIndex(of: $0)! }
                for (a, b) in zip(positions, positions.dropFirst()) {
                    XCTAssertLessThanOrEqual(abs(a - b), 2)
                }
            }
        }
    }

    func testTheSameNoteIsNeverRepeatedMoreThanTwiceInARow() {
        var rng = SeededRandom(seed: 11)
        for _ in 0..<500 {
            let phrase = EchoPhraseGenerator.randomWalk(pool: [5, 6, 7], length: 8, using: &rng)
            for i in 2..<phrase.count {
                XCTAssertFalse(phrase[i] == phrase[i - 1] && phrase[i - 1] == phrase[i - 2], "\(phrase)")
            }
        }
    }

    func testWalksUseTheWholePoolAndAreDeterministic() {
        var a = SeededRandom(seed: 5), b = SeededRandom(seed: 5), c = SeededRandom(seed: 6)
        let pool = [5, 6, 7, 8, 9, 10]
        let phraseA = (0..<20).map { _ in EchoPhraseGenerator.randomWalk(pool: pool, length: 5, using: &a) }
        let phraseB = (0..<20).map { _ in EchoPhraseGenerator.randomWalk(pool: pool, length: 5, using: &b) }
        let phraseC = (0..<20).map { _ in EchoPhraseGenerator.randomWalk(pool: pool, length: 5, using: &c) }
        XCTAssertEqual(phraseA, phraseB)
        XCTAssertNotEqual(phraseA, phraseC)
        XCTAssertEqual(Set(phraseA.flatMap { $0 }), Set(pool), "every note of the pool gets used eventually")
    }

    func testDegeneratePools() {
        var rng = SeededRandom(seed: 1)
        XCTAssertEqual(EchoPhraseGenerator.randomWalk(pool: [7], length: 4, using: &rng), [7, 7, 7, 7], "one note can only repeat")
        XCTAssertEqual(EchoPhraseGenerator.randomWalk(pool: [], length: 4, using: &rng), [])
        let two = EchoPhraseGenerator.randomWalk(pool: [5, 6], length: 6, using: &rng)
        XCTAssertTrue(two.allSatisfy { [5, 6].contains($0) })
    }

    func testSongSnippetsAreContiguousSlicesInsideThePool() {
        var rng = SeededRandom(seed: 2)
        let songs = [[5, 6, 7, 9, 5, 5, 5, 6], [10, 11, 12]]
        for _ in 0..<50 {
            let snippet = EchoPhraseGenerator.songSnippet(pool: [5, 6, 7], length: 3, songs: songs, using: &rng)
            // [6,7,9] and [9,5,5] fall outside the pool and [5,5,5] is dull, leaving these two.
            XCTAssertTrue(snippet == [5, 6, 7] || snippet == [5, 5, 6], "\(String(describing: snippet))")
        }
        XCTAssertNil(EchoPhraseGenerator.songSnippet(pool: [5, 6, 7], length: 5, songs: songs, using: &rng))
        XCTAssertNil(EchoPhraseGenerator.songSnippet(pool: [20], length: 2, songs: songs, using: &rng))
    }

    func testRealSongsProduceSnippetsForAWideEnoughPool() {
        var rng = SeededRandom(seed: 4)
        let songs = SongLibrary.all.map(\.keyIds)
        let snippet = EchoPhraseGenerator.songSnippet(pool: Array(5...12), length: 4, songs: songs, using: &rng)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(snippet?.allSatisfy { (5...12).contains($0) } ?? false)
    }

    func testViewModelUsesSnippetsOnLaterEvenRounds() {
        let songs = [[5, 6, 7, 8]]
        let vm = makeVM(config(pool: [5, 6, 7, 8], rounds: nil, startLength: 3, snippets: true), songs: songs)
        var now: CFTimeInterval = 0
        vm.start(now: now)
        var phrases: [[Int]] = []
        for _ in 0..<4 {
            phrases.append(vm.phrase)
            now = listen(vm, from: now)
            playBack(vm, at: now)
            now += EchoViewModel.pauseAfterRound
            vm.step(now: now)
        }
        XCTAssertEqual(phrases[2], [5, 6, 7, 8], "round 2 takes the only song snippet that fits")
    }

    // MARK: Flow

    func testListeningPlaysOneSamplePerInterval() {
        let log = Recorder()
        let vm = makeVM(config(), log: log)
        XCTAssertEqual(vm.phase, .ready)
        vm.start(now: 10)
        XCTAssertEqual(vm.phase, .listening(index: -1))
        XCTAssertEqual(vm.phrase.count, 2)
        let samples = vm.phrase.map { NoteCatalog.note($0).sound }

        vm.step(now: 10.4)
        XCTAssertTrue(log.played.isEmpty)
        XCTAssertNil(vm.glowKeyId)

        vm.step(now: 10.5)                                  // lead-in over
        XCTAssertEqual(log.played, [samples[0]])
        XCTAssertEqual(vm.phase, .listening(index: 0))
        XCTAssertEqual(vm.glowKeyId, vm.phrase[0])

        vm.step(now: 11.0)
        XCTAssertEqual(log.played.count, 1)
        vm.step(now: 11.1)                                  // 0.6 s later
        XCTAssertEqual(log.played, samples)
        XCTAssertEqual(vm.phase, .listening(index: 1))
        XCTAssertEqual(vm.glowKeyId, vm.phrase[1])
        XCTAssertEqual(log.stopped, [samples[0]], "the previous sample is cut when the next begins")

        vm.step(now: 11.6)
        XCTAssertEqual(vm.phase, .listening(index: 1))
        vm.step(now: 11.7)                                  // the last slot is over
        XCTAssertEqual(vm.phase, .yourTurn(progress: 0))
        XCTAssertNil(vm.glowKeyId)
        XCTAssertEqual(log.stopped, samples)
    }

    func testNoGlowOnHardButTheSoundStillPlays() {
        let log = Recorder()
        let vm = makeVM(config(glow: false), log: log)
        vm.start(now: 0)
        vm.step(now: 0.5)
        XCTAssertEqual(log.played.count, 1)
        XCTAssertNil(vm.glowKeyId)
    }

    func testPlayingBackTheWholePhraseClearsTheRound() {
        let vm = makeVM(config(rounds: 3))
        vm.start(now: 0)
        let now = listen(vm, from: 0)
        XCTAssertEqual(vm.phase, .yourTurn(progress: 0))
        vm.answer(keyId: vm.phrase[0], now: now)
        XCTAssertEqual(vm.phase, .yourTurn(progress: 1))
        XCTAssertEqual(vm.lastOutcome?.kind, .correct)
        XCTAssertEqual(vm.lastOutcome?.keyId, vm.phrase[0])
        vm.answer(keyId: vm.phrase[1], now: now)
        XCTAssertEqual(vm.phase, .roundCleared)
        XCTAssertEqual(vm.roundsCleared, 1)
        XCTAssertEqual(vm.hearts, 3)
    }

    func testNextRoundStartsAfterThePauseWithALongerPhraseEveryTwoRounds() {
        let vm = makeVM(config(rounds: nil, startLength: 2))
        var now: CFTimeInterval = 0
        vm.start(now: now)
        var lengths: [Int] = []
        for _ in 0..<5 {
            lengths.append(vm.phrase.count)
            now = listen(vm, from: now)
            playBack(vm, at: now)
            XCTAssertEqual(vm.phase, .roundCleared)
            vm.step(now: now + EchoViewModel.pauseAfterRound - 0.01)
            XCTAssertEqual(vm.phase, .roundCleared, "still showing the cleared state")
            now += EchoViewModel.pauseAfterRound
            vm.step(now: now)
            XCTAssertEqual(vm.phase, .listening(index: -1))
        }
        XCTAssertEqual(lengths, [2, 2, 3, 3, 4])
        XCTAssertEqual(vm.roundsCleared, 5)
    }

    func testAWrongNoteCostsAHeartAndReplaysTheSamePhrase() {
        let log = Recorder()
        let vm = makeVM(config(rounds: 3), log: log)
        vm.start(now: 0)
        var now = listen(vm, from: 0)
        let phrase = vm.phrase
        let wrong = phrase[0] == 30 ? 31 : 30
        vm.answer(keyId: wrong, now: now)
        XCTAssertEqual(vm.hearts, 2)
        XCTAssertEqual(vm.phase, .mistake)
        XCTAssertEqual(vm.lastOutcome, EchoViewModel.Outcome(kind: .wrong, keyId: wrong, token: 1))

        vm.answer(keyId: phrase[0], now: now + 0.1)         // input is ignored during the pause
        XCTAssertEqual(vm.phase, .mistake)

        let playedBefore = log.played.count
        now += EchoViewModel.pauseAfterMistake
        vm.step(now: now)
        XCTAssertEqual(vm.phase, .listening(index: -1))
        XCTAssertEqual(vm.phrase, phrase, "the same phrase comes back")
        now = listen(vm, from: now)
        XCTAssertEqual(log.played.count, playedBefore + phrase.count)
        XCTAssertEqual(vm.phase, .yourTurn(progress: 0))
        XCTAssertEqual(vm.roundsCleared, 0)
    }

    func testAMistakeInTheMiddleOfAPhraseRestartsItFromTheTop() {
        let vm = makeVM(config(startLength: 3))
        vm.start(now: 0)
        var now = listen(vm, from: 0)
        vm.answer(keyId: vm.phrase[0], now: now)
        vm.answer(keyId: 30, now: now)
        XCTAssertEqual(vm.phase, .mistake)
        now += EchoViewModel.pauseAfterMistake
        vm.step(now: now)
        now = listen(vm, from: now)
        XCTAssertEqual(vm.phase, .yourTurn(progress: 0))
    }

    func testLosingAllHeartsEndsTheStage() {
        let vm = makeVM(config(rounds: 3, hearts: 3))
        vm.start(now: 0)
        var now: CFTimeInterval = 0
        for expectedHearts in [2, 1, 0] {
            now = listen(vm, from: now)
            vm.answer(keyId: 30, now: now)
            XCTAssertEqual(vm.hearts, expectedHearts)
            now += EchoViewModel.pauseAfterMistake
            vm.step(now: now)
        }
        XCTAssertEqual(vm.phase, .lost)
        XCTAssertEqual(vm.stars, 0)
        vm.step(now: now + 100)
        XCTAssertEqual(vm.phase, .lost)
        vm.answer(keyId: vm.phrase[0], now: now + 100)
        XCTAssertEqual(vm.roundsCleared, 0)
    }

    func testClearingTheRequiredRoundsWinsWithStarsEqualToHearts() {
        let vm = makeVM(config(rounds: 2, hearts: 3))
        vm.start(now: 0)
        var now = listen(vm, from: 0)
        vm.answer(keyId: 30, now: now)                      // one mistake in round 0
        now += EchoViewModel.pauseAfterMistake
        vm.step(now: now)
        now = listen(vm, from: now)
        playBack(vm, at: now)
        XCTAssertEqual(vm.phase, .roundCleared)
        now += EchoViewModel.pauseAfterRound
        vm.step(now: now)
        now = listen(vm, from: now)
        playBack(vm, at: now)
        XCTAssertEqual(vm.phase, .won)
        XCTAssertEqual(vm.roundsCleared, 2)
        XCTAssertEqual(vm.stars, 2)
    }

    func testEndlessNeverWinsAndTheRoundsClearedAreTheScore() {
        let vm = makeVM(config(rounds: nil))
        XCTAssertTrue(vm.isEndless)
        var now: CFTimeInterval = 0
        vm.start(now: now)
        for _ in 0..<12 {
            now = listen(vm, from: now)
            playBack(vm, at: now)
            now += EchoViewModel.pauseAfterRound
            vm.step(now: now)
        }
        XCTAssertEqual(vm.roundsCleared, 12)
        XCTAssertNotEqual(vm.phase, .won)
        XCTAssertLessThanOrEqual(vm.phrase.count, 8)
    }

    func testInputIsIgnoredWhileListeningAndBeforeStart() {
        let vm = makeVM(config())
        vm.answer(keyId: 5, now: 0)
        XCTAssertEqual(vm.hearts, 3)
        vm.start(now: 0)
        vm.answer(keyId: vm.phrase[0], now: 0.1)
        XCTAssertEqual(vm.phase, .listening(index: -1))
        XCTAssertNil(vm.lastOutcome)
    }

    func testStartingTwiceDoesNotRestartTheGame() {
        let vm = makeVM(config())
        vm.start(now: 0)
        let phrase = vm.phrase
        vm.step(now: 0.5)
        vm.start(now: 5)
        XCTAssertEqual(vm.phase, .listening(index: 0))
        XCTAssertEqual(vm.phrase, phrase)
    }

    func testSameSeedGivesTheSamePhrasesRegardlessOfMistakes() {
        func phrases(withMistakes: Bool) -> [[Int]] {
            let vm = makeVM(config(rounds: nil, seed: 77))
            var now: CFTimeInterval = 0
            vm.start(now: now)
            var result: [[Int]] = []
            for round in 0..<5 {
                result.append(vm.phrase)
                now = listen(vm, from: now)
                if withMistakes, round % 2 == 0 {
                    vm.answer(keyId: 30, now: now)
                    now += EchoViewModel.pauseAfterMistake
                    vm.step(now: now)
                    now = listen(vm, from: now)
                }
                playBack(vm, at: now)
                now += EchoViewModel.pauseAfterRound
                vm.step(now: now)
            }
            return result
        }
        XCTAssertEqual(phrases(withMistakes: false), phrases(withMistakes: true))
    }

    func testAnEmptyPoolFallsBackToTheWhiteKeys() {
        let vm = makeVM(config(pool: []))
        vm.start(now: 0)
        XCTAssertEqual(vm.phrase.count, 2)
        XCTAssertTrue(vm.phrase.allSatisfy(NoteCatalog.whiteKeyIDs.contains))
    }
}
