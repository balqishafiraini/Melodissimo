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
                NSLocalizedString("The questions will appear only ONCE and change automatically once you lift your finger from the answer tile. Slide to the right tile before you let go.", comment: ""),
                NSLocalizedString("Remember, you CAN'T undo the answer. Make sure you are sure of your answer before clicking, okay? Now are you ready? Let the adventure begin!", comment: "")
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
                            let width = Sizing.isPhone ? proxy.size.width : screenWidth
                            let progress = -minX / (width * 2)
                            var scale = progress > 0 ? 1 - progress : 1 + progress
                            scale = scale < 0.7 ? 0.7 : scale
                            
                            return AnyView(
                                VStack {
                                    Spacer()
                                    Image("tutorialSlider\(index)")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(.all, Sizing.isPhone ? 6 : nil)
                                    
                                    Text(self.quizWelcomeArr[index])
                                        .padding(.all, Sizing.isPhone ? 8 : nil)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.all, Sizing.isPhone ? 8 : nil)
                                        .background(Color.white)
                                        .cornerRadius(Sizing.s(50))
                                        // On iPhone the text takes the room it needs and the picture gets what is left.
                                        .fixedSize(horizontal: false, vertical: Sizing.isPhone)
                                        .layoutPriority(Sizing.isPhone ? 1 : 0)
                                    
                                    if index == 3 {
                                        Button {
                                            isPresenting = true
                                        } label: {
                                            Text("Start Quiz")
                                                .buttonFrame(width: 250, height: 80)
                                                .background(Color.navy)
                                                .foregroundColor(.white)
                                                .cornerRadius(Sizing.s(20))
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
                    .padding(.vertical, Sizing.isPhone ? 2 : nil)
                    .padding(.top, Sizing.isPhone ? 0 : nil)
            }
            .padding(.all, Sizing.isPhone ? 8 : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tutorialBackground)
            // iPad draws edge to edge; on iPhone the content stays inside the safe area (the backdrop still fills the screen).
            .ignoresSafeArea(.all, edges: Sizing.isPhone ? [] : .all)
        }
        .navigationViewStyle(StackNavigationViewStyle())

        
        
    }
}

extension TutorialView {
    @ViewBuilder
    fileprivate var tutorialBackground: some View {
        if Sizing.isPhone {
            ScreenBackdrop(color: Color.softBlue)
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.softBlue)
                    .scaledToFill()
                
                Image("bgMusic")
                    .scaledToFill()
            }
        }
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
