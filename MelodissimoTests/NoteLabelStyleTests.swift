import XCTest
@testable import Melodissimo

final class NoteLabelStyleTests: XCTestCase {

    func testNotAngkaIsTheOriginalLabelForAll32Keys() {
        for id in 1...32 {
            XCTAssertEqual(NoteCatalog.label(for: id, style: .notAngka), NoteCatalog.note(id).label)
        }
    }

    func testLetterNamesForAll32Keys() {
        let expected = ["F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "D5", "E5", "F5", "G5", "A5", "B5", "C6",
                        "F♯3", "G♯3", "A♯3", "C♯4", "D♯4", "F♯4", "G♯4", "A♯4", "C♯5", "D♯5", "F♯5", "G♯5", "A♯5"]
        XCTAssertEqual((1...32).map { NoteCatalog.label(for: $0, style: .letters) }, expected)
    }

    func testSolfegeNamesForAll32KeysUseDotsForOctaves() {
        let expected = ["Fa.", "Sol.", "La.", "Si.", "Do", "Re", "Mi", "Fa", "Sol", "La", "Si", "Do˙", "Re˙", "Mi˙", "Fa˙", "Sol˙", "La˙", "Si˙", "Do˙˙",
                        "Fa♯.", "Sol♯.", "La♯.", "Do♯", "Re♯", "Fa♯", "Sol♯", "La♯", "Do♯˙", "Re♯˙", "Fa♯˙", "Sol♯˙", "La♯˙"]
        XCTAssertEqual((1...32).map { NoteCatalog.label(for: $0, style: .solfege) }, expected)
    }

    func testEveryStyleNamesEveryKeyUniquely() {
        for style in NoteLabelStyle.allCases {
            XCTAssertEqual(Set((1...32).map { NoteCatalog.label(for: $0, style: style) }).count, 32, style.rawValue)
        }
    }

    func testTheStylesAgreeWithTheNotAngkaDigits() {
        // 1 2 3 4 5 6 7 = Do Re Mi Fa Sol La Si = C D E F G A B, in every octave.
        let digits = ["1": ("Do", "C"), "2": ("Re", "D"), "3": ("Mi", "E"), "4": ("Fa", "F"), "5": ("Sol", "G"), "6": ("La", "A"), "7": ("Si", "B")]
        for id in 1...32 {
            let label = NoteCatalog.note(id).label
            guard let names = digits[String(label.prefix(1))] else { continue }
            XCTAssertTrue(NoteCatalog.label(for: id, style: .solfege).hasPrefix(names.0), "\(label)")
            XCTAssertTrue(NoteCatalog.label(for: id, style: .letters).hasPrefix(names.1), "\(label)")
            XCTAssertEqual(label.contains("#"), NoteCatalog.label(for: id, style: .letters).contains("♯"), label)
        }
    }

    func testTheDefaultStyleFollowsTheLanguage() {
        XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: "id"), .notAngka)
        XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: "id-ID"), .notAngka)
        XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: "en-US"), .letters)
        for code in ["es", "fr-CA", "it", "pt-BR"] { XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: code), .solfege, code) }
        XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: "ja"), .letters)
        XCTAssertEqual(NoteLabelStyle.defaultStyle(forLanguage: nil), .letters)
    }

    func testTheChoiceIsStoredAndOverridesTheLanguageDefault() {
        let suite = "NoteStyle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        XCTAssertEqual(progress.noteLabelStyle, NoteLabelStyle.defaultStyle(forLanguage: Locale.preferredLanguages.first))
        progress.noteLabelStyle = .solfege
        XCTAssertEqual(ProgressStore(defaults: defaults).noteLabelStyle, .solfege)
        XCTAssertEqual(defaults.string(forKey: "settings_noteLabelStyle"), "solfege")
        defaults.set("banana", forKey: "settings_noteLabelStyle")
        XCTAssertEqual(progress.noteLabelStyle, NoteLabelStyle.defaultStyle(forLanguage: Locale.preferredLanguages.first), "unknown value: default")
    }

    func testTheSheetGlyphsFollowTheStyleAndNotAngkaIsUnchanged() {
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: 25), NotAngkaLayout.glyph(forKeyId: 25, style: .notAngka))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: 25, style: .notAngka), NotAngkaLayout.Glyph(digit: "4", dotsAbove: 0, dotsBelow: 0, isSharp: true))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: 12, style: .solfege), NotAngkaLayout.Glyph(digit: "Do", dotsAbove: 1, dotsBelow: 0, isSharp: false))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: 20, style: .solfege), NotAngkaLayout.Glyph(digit: "Fa", dotsAbove: 0, dotsBelow: 1, isSharp: true))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: 25, style: .letters), NotAngkaLayout.Glyph(digit: "F4", dotsAbove: 0, dotsBelow: 0, isSharp: true))
    }

    func testNoteIdsAreUntouched() {
        XCTAssertEqual(NoteCatalog.all.map(\.id), Array(1...32))
        XCTAssertEqual(NoteCatalog.id(forLabel: "1"), 5)
    }
}
