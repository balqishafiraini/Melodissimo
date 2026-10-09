//
//  QuizIncorrectAnswerView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import Foundation
import SwiftUI

struct NotationQuizIncorrectAnswerView: View {

    var level: LevelModel?

    @EnvironmentObject private var router: AppRouter

    var body: some View {
            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .scaledToFill()
                
                Image("bgMusic")
                    .scaledToFill()
                
                VStack{
                    HStack{
                        Button {
                            router.pop(to: .notationMenu)
                        } label: {
                            Text("Menu")
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
                    .padding()
                    
                    Spacer()
                    
                    HStack{
                        Spacer()
                        VStack {
                            Spacer()
                            Text("Sorry, wrong answer! Let’s try again or learn some more in Learn Menu")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: 300)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Button {
                                let levelNo = level?.levelNo ?? 0
                                router.pop(to: .notationLevelMenu)
                                router.push(.notationQuiz(levelNo: levelNo))
                            } label: {
                                Text("Try again")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.yellow)
                                    .foregroundColor(Color.red)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }

                            Spacer()

                        }
                        Spacer()
                        Image("alpanicaSad")
                            .scaledToFit()
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)

            }
    }
}
