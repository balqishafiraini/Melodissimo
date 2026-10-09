//
//  AppRouter.swift
//  Melodissimo
//

import SwiftUI

/// Typed destinations for the app's single navigation stack rooted at the dashboard.
/// Carrying payloads here (instead of pushing fresh `NavigationView`s) keeps the
/// game flow on one stack so screens push and pop instead of piling up.
enum Route: Hashable {
    case notationMenu
    case songMenu
    case notationLearn
    case songRepositoryLearn
    case songLearn(songTitle: String)
    case notationLevelMenu
    case notationQuiz(levelNo: Int)
    case songRepositoryQuiz
    case songQuiz(songTitle: String)
    case afterQuiz(level: LevelModel, answers: [Int], score: Int)
    case help
    case achievements
    case postplay
}

/// Drives the app's single `NavigationStack`. Screens push routes and pop back
/// (`pop`, `popToRoot`, `pop(to:)`) instead of stacking new navigation containers.
@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
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
