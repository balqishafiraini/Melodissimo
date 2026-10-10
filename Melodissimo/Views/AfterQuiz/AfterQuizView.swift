//
//  AfterQuizView.swift
//  Melodissimo
//
//  Created by Balqis on 31/10/23.
//

import SwiftUI
import Foundation

/// Where the old-style quiz ends: the score screen of the pre-play or post-play skill test.
/// (The classic levels and the songs now end on `StageResultView`.)
struct AfterQuizView: View {
    var level: LevelModel?
    var userAnswer: [Int]
    var userScore: Int

    var body: some View {
        if level?.levelCategory == "preplay" {
            PreplayScoreView(score: userScore)
        } else if level?.levelCategory == "postplay" {
            PostplayScoreView(score: userScore)
        } else {
            EmptyView()
        }
    }
}
