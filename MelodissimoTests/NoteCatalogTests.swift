import XCTest
@testable import Melodissimo

final class NoteCatalogTests: XCTestCase {

    func testHasThirtyTwoNotesWithUniqueIdsLabelsAndSounds() {
        let notes = NoteCatalog.all
        XCTAssertEqual(notes.count, 32)
        XCTAssertEqual(Set(notes.map(\.id)).count, 32)
        XCTAssertEqual(Set(notes.map(\.label)).count, 32)
        XCTAssertEqual(Set(notes.map(\.sound)).count, 32)
        XCTAssertEqual(notes.map(\.id), Array(1...32), "ids are persisted and must stay 1...32 in order")
    }

    func testEverySoundResourceExistsInTheBundle() {
        for note in NoteCatalog.all {
            XCTAssertNotNil(Bundle.main.url(forResource: note.sound, withExtension: "m4a"),
                            "missing sample \(note.sound).m4a for key \(note.id)")
        }
    }

    func testSemitonesCoverZeroThroughThirtyOneWithoutDuplicates() {
        XCTAssertEqual(NoteCatalog.all.map(\.semitone).sorted(), Array(0...31))
    }

    func testWhiteAndBlackKeyIds() {
        XCTAssertEqual(NoteCatalog.whiteKeyIDs, Array(1...19))
        XCTAssertEqual(NoteCatalog.blackKeyIDs, Array(20...32))
        XCTAssertTrue(NoteCatalog.whiteKeyIDs.allSatisfy { !NoteCatalog.note($0).isBlack })
        XCTAssertTrue(NoteCatalog.blackKeyIDs.allSatisfy { NoteCatalog.note($0).isBlack })
    }

    func testLookupByIdAndLabel() {
        XCTAssertEqual(NoteCatalog.note(5).label, "1")
        XCTAssertEqual(NoteCatalog.note(5).sound, "c2")
        XCTAssertEqual(NoteCatalog.note(1).semitone, 0)
        XCTAssertEqual(NoteCatalog.id(forLabel: "5."), 2)
        XCTAssertEqual(NoteCatalog.id(forLabel: "6˙#"), 32)
        XCTAssertNil(NoteCatalog.id(forLabel: "8"))
        for note in NoteCatalog.all {
            XCTAssertEqual(NoteCatalog.id(forLabel: note.label), note.id)
        }
    }

    func testAllEighteenSongsMapEveryLabelToItsKeyId() {
        let songs = LevelFeederModel.shared.songLevel
        XCTAssertEqual(songs.count, 18)
        for song in songs {
            let ids = song.question.map { NoteCatalog.id(forLabel: $0) }
            XCTAssertFalse(ids.contains(nil), "\(song.songTitle ?? "?") has a label that isn't a pianika key")
            XCTAssertEqual(ids.compactMap { $0 }, song.answer, "\(song.songTitle ?? "?") labels and key ids disagree")
        }
    }

    func testGeneratedLevelsAreConsistentWithTheCatalog() {
        let feeder = LevelFeederModel.shared
        XCTAssertEqual(feeder.notationQuizLevels.count, 100)
        for level in feeder.notationQuizLevels + [feeder.preplayLevel, feeder.postplayLevel] {
            XCTAssertEqual(level.question.compactMap { NoteCatalog.id(forLabel: $0) }, level.answer)
        }
        // The pre-play test only asks about white keys.
        XCTAssertTrue(feeder.preplayLevel.answer.allSatisfy { NoteCatalog.whiteKeyIDs.contains($0) })
    }

    func testTilesViewModelUsesCatalogLabels() {
        let viewModel = TilesViewModel()
        XCTAssertEqual(viewModel.getStringRepresentation(for: 12), "1˙")
        XCTAssertEqual(viewModel.getStringRepresentation(for: 0), "")
        XCTAssertEqual(viewModel.getStringRepresentation(for: 99), "")
    }
}
