//
//  PreplayScoreView.swift
//  Melodissimo
//
//  Created by Balqis on 01/11/23.
//

import SwiftUI

struct PreplayScoreView: View {
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    var score: Int
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            if Sizing.isPhone { phoneBody } else { ipadBody }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    /// iPhone: the score, the card, the button and Alpanica share the screen (see `PhoneStoryPage`).
    private var phoneBody: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)
            PhoneStoryPage(art: "alpanicaGlasses", buttonTitle: "Start the Tour",
                           onButton: startTour,
                           onHelp: { isPresentingHelp = true }) {
                HStack(spacing: 8) {
                    PhoneScoreCircle(score: score)
                    Text("Thank you! After learn with us, see your current score, and you can test your skill again in Post-Play Menu")
                        .phoneCard(alignment: .center)
                }
            }
            NavigationLink(destination: HelpPageView().navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) { EmptyView() }
                .hidden()
        }
        .navigationBarHidden(true)
    }

    /// iPhone: Home becomes the root screen (see `Notification.Name.onboardingFinished`) instead of being pushed.
    private func startTour() {
        UserDefaults.standard.set(true, forKey: "isPreplayDone")
        UserDefaults.standard.set(score, forKey: "preplayScore")
        NotificationCenter.default.post(name: .onboardingFinished, object: nil, userInfo: ["startsFirstStage": true])
    }

    /// iPad: the v2 layout, unchanged.
    private var ipadBody: some View {
        ZStack {
            Rectangle()
                .fill(Color.softBlue)
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
                    VStack (spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 200, height: 200)
                            VStack{
                                Text("Score:")
                                    .font(.subheadline)
                                Text("\(score)")
                                    .font(.custom("BalooDa-Regular", size: 80))
                            }
                            
                        }
                        Text("Thank you! After learn with us, see your current score, and you can test your skill again in Post-Play Menu")
                            .multilineTextAlignment(.center)
                            .padding()
                            .foregroundStyle(.black)
                            .font(.headline)
                            .frame(width: screenWidth * 0.5)
                            .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                        
                        Spacer()
                        
                        Button {
                            isPresenting = true
                            UserDefaults.standard.set(true, forKey: "isPreplayDone")
                            UserDefaults.standard.set(score, forKey: "preplayScore")
                            
                        } label: {
                            Text("Start the Tour")
                                .frame(width: screenWidth * 0.5, height: 100)
                                .background(Color.yellow)
                                .foregroundColor(Color.red)
                                .cornerRadius(20)
                                .font(Font.title)
                        }
                        NavigationLink(destination: DashboardView(startsFirstStage: true)
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
            .frame(maxWidth: .infinity, maxHeight: screenHeight, alignment: .topLeading)
            
        }
    }
    
}
