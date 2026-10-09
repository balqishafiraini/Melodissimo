//
//  QuizCorrectAnswerView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import Foundation
import SwiftUI

struct NotationQuizCorrectAnswerView: View {
    
    var level: LevelModel?

    @EnvironmentObject private var router: AppRouter

    func setCurrentLevelProgress(_ level: Int) {
        ProgressStore.shared.unlock(upToLevel: level)
    }

    var body: some View {
            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .scaledToFill()
                
                Image("bgMusic")
                    .scaledToFill()
                
                VStack{
                    HStack{
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
                    .padding()
                    
                    Spacer()
                    
                    HStack{
                        Spacer()
                        VStack {
                            Spacer()
                            Text("Congratulations! Great job for passing this level!")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: 300)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Button {
                                setCurrentLevelProgress(level?.levelNo ?? 0)
                                router.pop(to: .notationLevelMenu)
                            } label: {
                                Text("Next")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.yellow)
                                    .foregroundColor(Color.red)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }

                            Spacer()

                        }
                        Spacer()
                        Image("alpanicaGlasses")
                            .resizable()
                            .scaledToFit()
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)

            }
    }
}
