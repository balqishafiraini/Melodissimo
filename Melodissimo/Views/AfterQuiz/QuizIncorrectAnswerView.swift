//
//  QuizIncorrectAnswerView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import Foundation
import SwiftUI

struct QuizIncorrectAnswerView: View {
    @State var isPresenting = false
    @State var isPresentingHelp = false
    @State var isPresentingMenu = false

    
    var level: LevelModel?

    
    @Environment(\.dismiss) var dismiss
    
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
                        Button {
                            isPresentingMenu = true
                        } label: {
                            Text("Menu")
                                .frame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }
                        NavigationLink(destination: NotationMenuView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingMenu) {
                                EmptyView()
                            }
                        
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
                            Text("Sorry, wrong answer! Let’s try again or learn some more in Learn Menu")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: 300)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Button {
                                isPresenting = true
                                
                            } label: {
                                Text("Try again")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.yellow)
                                    .foregroundColor(Color.red)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }
                            NavigationLink(destination: NotationQuizView(levelNo: level?.levelNo ?? 0)
                                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                    EmptyView()
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
        .navigationViewStyle(StackNavigationViewStyle())
        
        
    }
}
