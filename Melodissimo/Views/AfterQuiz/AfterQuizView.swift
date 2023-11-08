//
//  PreplayScoreView.swift
//  Melodissimo
//
//  Created by Balqis on 31/10/23.
//

import SwiftUI
import Foundation

struct AfterQuizView: View {
    var level: LevelModel?
    var userAnswer: [Int]
    var userScore: Int

    var body: some View {
        if level?.levelCategory == "preplay" {
            return AnyView(PreplayScoreView(score: userScore))
        } else if level?.levelCategory == "notation" {
            if level?.answer == userAnswer {
                if (level?.levelNo ?? 0) % 5 == 0 {
                    return AnyView(FiveLevelPassedView())
                } else {
                    return AnyView(NotationQuizCorrectAnswerView(level: level))
                }
            } else {
                return AnyView(NotationQuizIncorrectAnswerView(level: level))
            }
        } else if level?.levelCategory == "song" {
            return AnyView(SongQuizScoreView(score: userScore, songTitle: level?.songTitle ?? ""))
        } else {
            return AnyView(EmptyView())
        }
    }
}




