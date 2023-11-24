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
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    @Environment(\.dismiss) var dismiss
    
    func setCurrentLevelProgress(_ level: Int) {
            let highestLevelUnlocked = UserDefaults.standard.integer(forKey: "currentLevel")
            if level > highestLevelUnlocked {
                UserDefaults.standard.set(level, forKey: "currentLevel")
            }
        }
    
    var body: some View {
        NavigationView {
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
                            isPresentingHelp = true
                        } label: {
                            Text("?")
                                .frame(width: 80, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.title)
                        }
                        NavigationLink(destination: HelpPageView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                                EmptyView()
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
                                isPresenting = true
                                setCurrentLevelProgress(level?.levelNo ?? 0)

                            } label: {
                                Text("Next")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.yellow)
                                    .foregroundColor(Color.red)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }
                            NavigationLink(destination: NotationQuizLevelMenuView()
                                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                    EmptyView()
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
        .navigationViewStyle(StackNavigationViewStyle())
        
        
    }
}
