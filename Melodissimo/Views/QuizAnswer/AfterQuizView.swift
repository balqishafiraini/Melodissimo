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
        Group {
            if level?.levelCategory == "preplay" {
                PreplayScoreView(score: userScore)
            } else if level?.levelCategory == "quiz" && level?.answer == userAnswer {
                QuizCorrectAnswerView(level: level, userAnswer: userAnswer)
            } else if level?.levelCategory == "quiz" && level?.answer != userAnswer {
                QuizIncorrectAnswerView(level: level, userAnswer: userAnswer)
            }
        }
    }
}



