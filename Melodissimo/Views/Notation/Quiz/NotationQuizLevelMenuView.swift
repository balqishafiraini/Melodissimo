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
                            .frame(width: UIScreen.main.bounds.width, height: 350)

                        ScrollView(.horizontal) {
                            HStack {
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
                                    .padding(10)
                                    .disabled(!isLevelEnabled)

                                    NavigationLink(destination: NotationQuizView(levelNo: selectedLevel)
                                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLevel) {
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.9, height: 350)
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

//import SwiftUI
//
//struct NotationQuizLevelMenuView: View {
//    
//    @State var isPresentingHelp = false
//    @State var isPresentingLevel = false
//    @State var selectedLevel = -1
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        NavigationView {
//            ZStack{
//                Image("notationQuizLevelMenu")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(height: UIScreen.main.bounds.height)
//                    .ignoresSafeArea()
//
//                
//                VStack{
//                    HStack{
//                        Button {
//                            dismiss()
//                        } label: {
//                            Text("Back")
//                                .frame(width: 120, height: 80)
//                                .background(Color.darkGreen)
//                                .foregroundColor(.white)
//                                .cornerRadius(20)
//                                .font(Font.headline)
//                        }.padding()
//                        
//                        Spacer()
//                        
//                        Button {
//                            isPresentingHelp = true
//                        } label: {
//                            Text("?")
//                                .frame(width: 80, height: 80)
//                                .background(Color.darkGreen)
//                                .foregroundColor(.white)
//                                .cornerRadius(20)
//                                .font(Font.title)
//                        }.padding()
//                        NavigationLink(destination: HelpPageView()
//                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
//                                EmptyView()
//                            }
//                    }.padding()
//                    
//                    Spacer()
//                    
//                    ZStack{
//                        RoundedRectangle(cornerRadius: 50)
//                            .fill(.white)
//                            .padding()
//                            .frame(width: UIScreen.main.bounds.width, height: 350)
//                        
//                        
//                        ScrollView(.horizontal) {
//                            HStack {
//                                ForEach(1..<101, id: \.self) { index in
//                                    Button {
//                                        selectedLevel = index
//                                        isPresentingLevel = true
//                                    } label: {
//                                        Text("Level \(index)")
//                                            .foregroundStyle(Color.darkGreen)
//                                            .font(.largeTitle)
//                                            .frame(width: UIScreen.main.bounds.width * 0.2, height: 250)
//                                            .background(RoundedRectangle(cornerRadius: 40).fill(Color.yellow))
//                                    }
//                                    .padding(10) // Add padding to create space between buttons
//
//                                    NavigationLink(destination: NotationQuizView(levelNo: selectedLevel)
//                                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLevel) {
//                                        EmptyView()
//                                    }
//                                }
//                            }
//                        }
//                        .frame(width: UIScreen.main.bounds.width*0.9, height: 350)
//                        
//                        
//                    }.padding()
//                    
//                    Spacer()
//                    
//                }.padding()
//                
//                
//            }
//        }
//        .ignoresSafeArea()
//        .navigationViewStyle(StackNavigationViewStyle())
//        
//    }
//}
//
