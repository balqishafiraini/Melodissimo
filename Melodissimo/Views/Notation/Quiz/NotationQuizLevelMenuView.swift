//
//  NotationQuizLevelMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 24/10/23.
//

import SwiftUI

struct NotationQuizLevelMenuView: View {
    @State private var isPresentingHelp = false
    @State private var isPresentingLevel = false
    @State private var isPresentingMenu = false
    @State private var selectedLevel = -1
    @Environment(\.dismiss) var dismiss
    @State private var currentLevel = UserDefaults.standard.integer(forKey: "currentLevel") // Use UserDefaults to track current level
    
    func getCurrentLevelProgress() -> Int {
        return UserDefaults.standard.integer(forKey: "currentLevel")
    }
    
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("notationQuizLevelMenu")
                    .resizable()
                    .scaledToFill()
                    .frame(height: UIScreen.main.bounds.height)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
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
                        .padding(.init(top: 30, leading: 30, bottom: 0, trailing: 0))
                        NavigationLink(destination: NotationMenuView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingMenu) {
                                EmptyView()
                            }
                        
                        Spacer()
                        
                        Text("Menu Level")
                            .padding(.init(top: 30, leading: 0, bottom: 0, trailing: 0))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.largeTitle)
                        
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
                        .padding(.init(top: 30, leading: 0, bottom: 0, trailing: 30))
                        NavigationLink(destination: HelpPageView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                                EmptyView()
                            }
                    }
                    .padding()
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height*0.8)
                        
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: UIScreen.main.bounds.width * 0.2), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(1..<101, id: \.self) { index in
                                    let isLevelEnabled = index <= currentLevel + 1
                                    Button {
                                        if isLevelEnabled {
                                            selectedLevel = index
                                            isPresentingLevel = true
                                        }
                                    }label: {
                                        Text("Level \(index)")
                                            .foregroundStyle(Color.darkGreen)
                                            .font(.largeTitle)
                                            .frame(width: UIScreen.main.bounds.width * 0.2, height: 250)
                                            .background(
                                                RoundedRectangle(cornerRadius: 40)
                                                    .fill(isLevelEnabled ? Color.yellow : Color.gray)
                                            )
                                    }
                                    .disabled(!isLevelEnabled)
                                    
                                    .background(NavigationLink("", destination: NotationQuizView(levelNo: selectedLevel)
                                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLevel))
                                }
                            }
                            .padding(10)
                            .background(Color.clear)
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.95, height: UIScreen.main.bounds.height*0.75)
                        
                    }.padding()
                    
                    Spacer()
                }.padding()
            }
        }
        .onAppear {
            currentLevel = getCurrentLevelProgress()
        }
        .ignoresSafeArea()
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
