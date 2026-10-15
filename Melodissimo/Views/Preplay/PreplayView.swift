//
//  PreplayView.swift
//  Melodissimo
//
//  Created by Balqis on 03/10/23.
//

import SwiftUI
import Foundation

struct PreplayView: View {
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    var levelNo: Int
    @StateObject var tilesViewModel = TilesViewModel()
    
    var body: some View {
        ZStack {
            backdrop
            
            VStack{
                HStack{
                    Spacer()
                    
                    Button {
                        isPresentingHelp = true
                    } label: {
                        Text("?")
                            .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.title)
                    }
                    .padding(.all, Sizing.isPhone ? 0 : nil)
                    NavigationLink(destination: HelpPageView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                            EmptyView()
                        }
                    
                }
                .padding(.trailing, Sizing.isPhone ? 0 : nil)
                
                Spacer()
                
                ZStack {
                    Text("\(tilesViewModel.currentLevel?.question[tilesViewModel.currentQuestionIndex] ?? "N/A")")
                        .foregroundStyle(.black)
                        .font(.custom("BalooDa-Regular", size: Sizing.f(70)))
                        .frame(width: screenWidth * 0.5, height: Sizing.isPhone ? max(screenHeight * 0.15, 64) : screenHeight * 0.15)
                        .background(RoundedRectangle(cornerRadius: Sizing.s(40)).fill(.white))
                }
                
                Spacer()
                
                PianikaStackQuiz(viewModel: tilesViewModel)
                
                Spacer()
                
            }
            .topBarScreenPadding(ipad: nil)
            .frame(maxWidth: .infinity, maxHeight: screenHeight, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "preplay")
        }
    }
    
}

extension PreplayView {
    /// The flat colour and the music-note pattern. iPad draws them as two layers, as always; iPhone fits the pattern to the screen.
    @ViewBuilder
    fileprivate var backdrop: some View {
        if Sizing.isPhone {
            ScreenBackdrop(color: Color.softBlue)
        } else {
            Rectangle()
                .fill(Color.softBlue)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
        }
    }
}
