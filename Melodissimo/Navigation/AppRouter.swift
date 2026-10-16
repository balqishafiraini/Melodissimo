//
//  AppRouter.swift
//  Melodissimo
//

import SwiftUI

/// Typed destinations for the app's single navigation stack rooted at the dashboard.
/// Carrying payloads here (instead of pushing fresh `NavigationView`s) keeps the
/// game flow on one stack so screens push and pop instead of piling up.
enum Route: Hashable {
    case notationLearn
    case songRepositoryLearn
    case songLearn(songTitle: String)
    case notationLevelMenu
    case songRepositoryQuiz
    case help
    case achievements
    case postplay
    /// Launches any play mode; see `PlayRequest`.
    case play(PlayRequest)
    /// Pick Listen / Practice / Perform and the speed for a song. Campaign stages pass their id.
    case stageSetup(songId: String, campaignStageId: String? = nil, isBoss: Bool = false)
    /// What a finished play earned. `ResultRecorder` has already stored it.
    case result(PlayResult, RewardSummary)
    /// DEBUG tools: author a rhythm chart by playing along, then preview it in Listen mode.
    case chartRecorder
    case chartPreview(SongChart)
    /// The hub for playing anything outside the campaign: songs, classic levels, Echo, Melody Rush.
    case freePlay
    /// The Nusantara Tour map.
    case campaignMap
    /// The lessons: notes, songs and the skill test.
    case learnHub
    /// Spend coins on keyboard skins, note skins and outfits.
    case shop
    /// The shop opened at the coin packs (the coin badge, and "not enough coins" on the Continue sheet).
    case shopCoins
    /// The song packs on sale (behind the `packStore` flag).
    case packStore
    /// The purchase screen of one pack.
    case paywall(packId: String)
    /// The Melodissimo Plus subscription screen.
    case plus
    /// Note speed, key labels, audio timing and reset.
    case settings
}

/// Drives the app's single `NavigationStack`. Screens push routes and pop back
/// (`pop`, `popToRoot`, `pop(to:)`) instead of stacking new navigation containers.
@MainActor
final class AppRouter: ObservableObject {
    /// Every navigation (push, pop, replace, the swipe-back gesture) silences the notes, so a
    /// sample started on one screen can never keep ringing on the next.
    @Published var path: [Route] = [] {
        didSet { stopAllSounds() }
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Swaps the top screen for another, so Back from the new one skips the old.
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Pops back to the first occurrence of `route`, keeping it on top of the stack.
    /// Falls back to the root if the route isn't currently on the stack.
    func pop(to route: Route) {
        if let index = path.firstIndex(of: route) {
            path.removeSubrange((index + 1)...)
        } else {
            popToRoot()
        }
    }
}
