//
//  PreplayScoreView.swift
//  Melodissimo
//
//  Created by Balqis on 31/10/23.
//

import SwiftUI

struct AfterQuizView: View {
    var level: LevelModel?
    var userAnswer: [Int]

    var body: some View {
        Group {
            if level?.levelCategory == "preplay" {
                HelpPageView()
            } else if level?.levelCategory == "quiz" && level?.answer == userAnswer {
                CorrectAnswerView(level: level, userAnswer: userAnswer)
            } else if level?.levelCategory == "quiz" && level?.answer != userAnswer {
                IncorrectAnswerView(level: level, userAnswer: userAnswer)
            }
        }
    }
}

struct CorrectAnswerView: View {
    var level: LevelModel?
    var userAnswer: [Int]

    var body: some View {
        VStack {
            Text("Level \(level?.levelNo ?? -1) - Category: \(level?.levelCategory ?? "N/A")")
            Text("True answer: \(level?.answer.description ?? "")")
            Text("User's answer: \(userAnswer.description)")
            Text("CONGRATS")
        }
    }
}

struct IncorrectAnswerView: View {
    var level: LevelModel?
    var userAnswer: [Int]

    var body: some View {
        VStack {
            Text("Level \(level?.levelNo ?? -1) - Category: \(level?.levelCategory ?? "N/A")")
            Text("True answer: \(level?.answer.description ?? "")")
            Text("User's answer: \(userAnswer.description)")
            Text("Nice try, answer is still incorrect")
        }
    }
}
