//
//  FirstLaunchView.swift
//  Melodissimo
//
//  Created by Balqis on 09/11/23.
//

import Foundation
import SwiftUI

struct TutorialView: View {
    
    @State var isPresenting = false
    @State var currentIndex: Int = 1
    
    var quizWelcomeArr: [String] {
            return [
                NSLocalizedString("", comment: ""),
                NSLocalizedString("You'll go to Pre-Play Quiz like shown image above, but the melodica tiles will come WITHOUT any label. So remember the numeral notation. You must press the tiles that belong to the numeral notation that's shown in the question box.", comment: ""),
                NSLocalizedString("The questions will appear only ONCE and change automatically once you pressed the answer tiles. Please make sure your pressed tiles are at least 2 seconds and the color will change to grey.", comment: ""),
                NSLocalizedString("Remember, you CAN'T undo the answer. Now are you ready? Let the adventure begin!", comment: "")
            ]
        }
    
    var body: some View {
        NavigationView {
            VStack {
                TabView(selection: $currentIndex) {
                    ForEach(1...3, id: \.self) { index in
                        // Custom Scroll Effect
                        GeometryReader { proxy -> AnyView in
                            let minX = proxy.frame(in: .global).minX
                            let width = UIScreen.main.bounds.width
                            let progress = -minX / (width * 2)
                            var scale = progress > 0 ? 1 - progress : 1 + progress
                            scale = scale < 0.7 ? 0.7 : scale
                            
                            return AnyView(
                                VStack {
                                    Spacer()
                                    Image("tutorialSlider\(index)")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding()
                                    
                                    Text(self.quizWelcomeArr[index])
                                        .padding()
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(50)
                                    
                                    if index == 3 {
                                        Button {
                                            isPresenting = true
                                        } label: {
                                            Text("Start Quiz")
                                                .frame(width: 250, height: 80)
                                                .background(Color.navy)
                                                .foregroundColor(.white)
                                                .cornerRadius(20)
                                                .font(Font.headline)
                                        }
                                        NavigationLink(destination: PreplayView(levelNo: 1)
                                            .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                                EmptyView()
                                            }
                                        
                                    }
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                                .scaleEffect(scale)
                            )
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom tab indicator
                CustomeTabIndicator(count: 3, current: $currentIndex)
                    .padding(.vertical)
                    .padding(.top)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Rectangle()
                        .fill(Color.softBlue)
                        .scaledToFill()
                    
                    Image("bgMusic")
                        .scaledToFill()
                }
            )
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())

        
        
    }
}

struct CustomeTabIndicator: View {
    
    var count: Int
    @Binding var current: Int
    
    var body: some View {
        
        HStack {
            HStack {
                ForEach(0..<count, id: \.self) { index in
                    ZStack {
                        if (current - 1) == index {
                            Circle()
                                .fill(Color.blue)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 1.5)
                                )
                        }
                    }
                    .frame(width: 10, height: 10)
                }
            }
        }
    }
}
