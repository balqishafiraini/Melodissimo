//
//  QuizIncorrectAnswerView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import Foundation
import SwiftUI

struct QuizIncorrectAnswerView: View {
    var level: LevelModel?
    var userAnswer: [Int]
    @State var isPresenting = false


    var body: some View {
        VStack {
            Text("Level \(level?.levelNo ?? -1) - Category: \(level?.levelCategory ?? "N/A")")
            Text("True answer: \(level?.answer.description ?? "")")
            Text("User's answer: \(userAnswer.description)")
            Text("SORRY answer is still incorrect")
            
            Button {
                isPresenting = true
                
            } label: {
                Text("Try again")
            }
            NavigationLink(destination: NotationQuizView(levelNo: level?.levelNo ?? 0)
                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                    EmptyView()
                }
        }
    }
}

