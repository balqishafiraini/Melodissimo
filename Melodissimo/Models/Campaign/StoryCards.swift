//
//  StoryCards.swift
//  Melodissimo
//

import Foundation

/// A short story moment on the map: Alpanica says a few lines when a chapter begins and after each boss.
struct StoryCard: Identifiable, Hashable {
    enum Kind: Hashable {
        /// The first time the player is on a chapter's island.
        case chapterIntro
        /// After the chapter's boss is beaten.
        case bossDefeated
        /// Before the national anthem.
        case finale
    }

    /// `intro_1`…`intro_6`, `boss_1`…`boss_6`, `finale`. Also the suffix of the `story_seen_<id>` key.
    let id: String
    let kind: Kind
    let chapter: Int
    /// Two or three short lines in English. They are keys in `Localizable.strings`; views look them up
    /// at display time because models can't import SwiftUI.
    let lines: [String]
}

enum StoryCatalog {

    /// The 13 cards in story order.
    static let cards: [StoryCard] = [
        StoryCard(id: "intro_1", kind: .chapterIntro, chapter: 1, lines: [
            "Oh no! Fals the off-key monster has scrambled the songs of Nusantara!",
            "Alpanica is sailing from Sabang to Merauke to bring them back.",
            "Our first stop is Sumatra. Let's learn the notes!"
        ]),
        StoryCard(id: "boss_1", kind: .bossDefeated, chapter: 1, lines: [
            "You did it! The Sumatra Fals is defeated.",
            "Its song of thanks to our teachers rings out again.",
            "Next stop: Jawa!"
        ]),
        StoryCard(id: "intro_2", kind: .chapterIntro, chapter: 2, lines: [
            "Welcome to Jawa, the island of palaces and gamelan!",
            "Fals is hiding in the lower notes here.",
            "Listen closely and play quickly!"
        ]),
        StoryCard(id: "boss_2", kind: .bossDefeated, chapter: 2, lines: [
            "Boom! The Jawa Fals ran away.",
            "Garuda Pancasila is flying proud again.",
            "Let's sail to Kalimantan!"
        ]),
        StoryCard(id: "intro_3", kind: .chapterIntro, chapter: 3, lines: [
            "Kalimantan has a huge, green rainforest.",
            "Fals is hiding between the trees with new notes!",
            "Can you find them all?"
        ]),
        StoryCard(id: "boss_3", kind: .bossDefeated, chapter: 3, lines: [
            "Merdeka! The Kalimantan Fals gave up.",
            "Hari Merdeka is ringing through the forest.",
            "Onward to Sulawesi!"
        ]),
        StoryCard(id: "intro_4", kind: .chapterIntro, chapter: 4, lines: [
            "Sulawesi is an island of sailors and the deep blue sea.",
            "The notes get higher here, so reach up!",
            "Fals is faster, too. Stay sharp!"
        ]),
        StoryCard(id: "boss_4", kind: .bossDefeated, chapter: 4, lines: [
            "Great job! The Sulawesi Fals sailed away.",
            "Rayuan Pulau Kelapa sounds sweet again.",
            "Next: Bali and Nusa Tenggara!"
        ]),
        StoryCard(id: "intro_5", kind: .chapterIntro, chapter: 5, lines: [
            "Bali and Nusa Tenggara are full of dance and sunshine!",
            "Now you will meet the black keys.",
            "They sound a little different, so listen well!"
        ]),
        StoryCard(id: "boss_5", kind: .bossDefeated, chapter: 5, lines: [
            "The Nusa Tenggara Fals is defeated!",
            "Hymne Guru fills the air with thanks.",
            "The last island is waiting: Maluku and Papua!"
        ]),
        StoryCard(id: "intro_6", kind: .chapterIntro, chapter: 6, lines: [
            "This is the far east, where Indonesia reaches Merauke.",
            "Every note you have learned is here.",
            "You are ready!"
        ]),
        StoryCard(id: "boss_6", kind: .bossDefeated, chapter: 6, lines: [
            "The last Fals is gone!",
            "From Sabang to Merauke, every song is back.",
            "Just one more song to play together."
        ]),
        StoryCard(id: "finale", kind: .finale, chapter: 6, lines: [
            "Indonesia Raya is our national anthem.",
            "We play it calmly and with respect.",
            "Play it from your heart."
        ])
    ]

    static func card(id: String) -> StoryCard? {
        cards.first { $0.id == id }
    }

    /// The key under which the Tour Complete certificate is marked as shown.
    static let certificateId = "certificate"

    /// The stage that ends a chapter: its boss.
    static func bossStage(inChapter chapter: Int) -> Stage? {
        CampaignCatalog.stages(inChapter: chapter).first {
            if case .boss = $0.kind { return true }
            return false
        }
    }

    static func finaleStage() -> Stage? {
        CampaignCatalog.allStages.first {
            if case .finale = $0.kind { return true }
            return false
        }
    }

    /// The cards to show now, in story order.
    ///
    /// - a chapter's intro shows once, while the player is up to that chapter (so a player who starts
    ///   further along through migration doesn't get the intros they skipped);
    /// - a boss card shows once its boss has a star;
    /// - the finale card shows once the last boss has a star.
    static func pending(currentChapter: Int, stars: (String) -> Int, seen: (String) -> Bool) -> [StoryCard] {
        func beaten(_ chapter: Int) -> Bool {
            guard let boss = bossStage(inChapter: chapter) else { return false }
            return stars(boss.id) >= 1
        }
        return cards.filter { card in
            guard !seen(card.id) else { return false }
            switch card.kind {
            case .chapterIntro: return card.chapter == currentChapter
            case .bossDefeated: return beaten(card.chapter)
            case .finale: return beaten(CampaignCatalog.chapters.count)
            }
        }
    }

    /// The certificate is shown once, after the finale has a star.
    static func shouldShowCertificate(stars: (String) -> Int, seen: (String) -> Bool) -> Bool {
        guard let finale = finaleStage(), !seen(certificateId) else { return false }
        return stars(finale.id) >= 1
    }
}
