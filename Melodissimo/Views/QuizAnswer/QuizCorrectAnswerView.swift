//
//  QuizCorrectAnswerView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import Foundation
import SwiftUI

struct QuizCorrectAnswerView: View {
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
                    setCurrentLevelProgress(level?.levelNo ?? 0)
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
    
    func setCurrentLevelProgress(_ level: Int) {
        UserDefaults.standard.set(level, forKey: "currentLevel")
    }
}
