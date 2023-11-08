//
//  FiveLevelPassedView.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import Foundation
import SwiftUI
import ConfettiSwiftUI

//
//  FiveLevelPassedView.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import Foundation
import SwiftUI
import ConfettiSwiftUI

struct FiveLevelPassedView: View {
    
    var level: LevelModel?
    
    @State private var showCelebration = false
    @State private var showSurpriseText = true // Added state variable to control the visibility of the surprise text
    @State private var counter = 0
    
    @Environment(\.dismiss) var dismiss
    
    func setCurrentLevelProgress(_ level: Int) {
        UserDefaults.standard.set(level, forKey: "currentLevel")
    }
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.white]), startPoint: .top, endPoint: .bottom))
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
                            if showCelebration {
                                Text("WOHOO! Congratulations, 5 levels passed. After this, you will step up to another 5 levels with +1 question each from your previous levels. Good luck!")
                                    .padding()
                                    .foregroundStyle(.black)
                                    .font(.headline)
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 300)
                                    .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            }
                            
                            Spacer()
                            
                            if showCelebration {
                                Button {
                                    isPresenting = true
                                    if let unwrappedLevelNo = level?.levelNo {
                                        setCurrentLevelProgress(unwrappedLevelNo)
                                    }
                                    
                                } label: {
                                    Text("Next")
                                        .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                        .background(Color.yellow)
                                        .foregroundColor(Color.darkGreen)
                                        .cornerRadius(20)
                                        .font(Font.title)
                                }
                                NavigationLink(destination: NotationQuizLevelMenuView()
                                    .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                        EmptyView()
                                    }
                            }
                            
                            Spacer()
                            
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            if showSurpriseText { // Show the surprise text only when the button is not triggered
                                Text("Click the alpaca for a surprise!")
                                    .foregroundColor(.white)
                                    .font(Font.headline)
                            }
                            Button(action: {
                                counter += 1
                                showCelebration = true
                                showSurpriseText = false // Hide the surprise text when the button is triggered
                            }) {
                                Image("alpanicaCrownGlasses")
                                    .resizable()
                                    .scaledToFit()
                            }
                            .confettiCannon(counter: $counter, num: 100, confettiSize: 20.0, radius: 500.0, repetitions: 50 )
                        }
                        
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
