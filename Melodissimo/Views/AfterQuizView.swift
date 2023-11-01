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
    @State var isPresenting = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Level \(level?.levelNo ?? -1) - Category: \(level?.levelCategory ?? "N/A")")
                Text("True answer: \(level?.answer.description ?? "")")
                Text("User's answer: \(userAnswer.description)")
                Text("CONGRATS")
                
                Button {
                    isPresenting = true
                } label: {
                    Text("Level")
                }
                NavigationLink(destination: NotationQuizLevelMenuView()
                    .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                        EmptyView()
                    }
            }
        }        .navigationViewStyle(StackNavigationViewStyle())

        
    }
}

struct IncorrectAnswerView: View {
    var level: LevelModel?
    var userAnswer: [Int]
    @State var isPresenting = false


    var body: some View {
        VStack {
            Text("Level \(level?.levelNo ?? -1) - Category: \(level?.levelCategory ?? "N/A")")
            Text("True answer: \(level?.answer.description ?? "")")
            Text("User's answer: \(userAnswer.description)")
            Text("Nice try, answer is still incorrect")
            
            Button {
                isPresenting = true
            } label: {
                Text("Level")
            }
            NavigationLink(destination: NotationQuizLevelMenuView()
                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                    EmptyView()
                }
        }
    }
}
