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
    @State private var currentLevel = 0 // Initialize with the first level
    
    // Function to retrieve user's current progress from UserDefaults
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
                            dismiss()
                        } label: {
                            Text("Back")
                                .frame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }.padding()

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
                        }.padding()
                        NavigationLink(destination: HelpPageView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                                EmptyView()
                            }
                    }.padding()
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height*0.6)
                        
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
                                    } label: {
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
                            .background(Color.clear) // Use a clear background to avoid extra spacing
                        }

                        .frame(width: UIScreen.main.bounds.width * 0.95, height: UIScreen.main.bounds.height*0.55)
                        
                    }.padding()
                    
                    Spacer()
                }.padding()
            }
        }
        .onAppear {
            // Initialize currentLevel on view appear
            currentLevel = getCurrentLevelProgress()
        }
        .ignoresSafeArea()
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
