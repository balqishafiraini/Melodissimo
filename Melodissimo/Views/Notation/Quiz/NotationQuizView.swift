//
//  LearnNotationView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct NotationQuizView: View {
    
    @State var buttonPressed = false

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var router: AppRouter

    @StateObject var tilesViewModel = TilesViewModel()

    var levelNo: Int
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack (spacing: 1){
                ZStack {
                    Text("Level: \(levelNo)")
                        .foregroundColor(.white)
                        .font(Font.headline)

                    HStack{
                        Button {
                            dismiss()
                        } label: {
                            Text("< Back")
                                .frame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }

                        Spacer()

                        Button {
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: 80, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.title)
                        }
                    }
                }
                .padding([.leading, .trailing])

                HStack {
                    HStack(spacing: 4) {
                        ForEach(0..<tilesViewModel.maxLives, id: \.self) { index in
                            Image(systemName: index < tilesViewModel.lives ? "heart.fill" : "heart")
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    if tilesViewModel.combo > 1 {
                        Text("Combo x\(tilesViewModel.combo)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.darkGreen))
                    }
                }
                .font(.title2)
                .padding([.leading, .trailing])

                ZStack {
                    Text("\(tilesViewModel.currentLevel?.question[tilesViewModel.currentQuestionIndex] ?? "N/A")")
                        .foregroundStyle(.black)
                        .font(.custom("BalooDa-Regular", size: 70))
                        .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.15)
                        .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                }
                
                                
                PianikaStackQuiz(viewModel: tilesViewModel, autoNavigateOnFinish: false)

            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "notation")
        }
        .onChange(of: tilesViewModel.canNavigateToAfterQuizPage) { finished in
            if finished, let level = tilesViewModel.currentLevel {
                router.push(.afterQuiz(level: level, answers: tilesViewModel.answers, score: tilesViewModel.score))
            }
        }
    }
}
