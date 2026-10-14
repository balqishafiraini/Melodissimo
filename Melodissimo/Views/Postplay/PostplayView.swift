//
//  PreplayView.swift
//  Melodissimo
//
//  Created by Balqis on 03/10/23.
//

import SwiftUI
import Foundation

struct PostplayView: View {
    @State var isPresenting = false
    @State var isPresentingHelp = false
    @Environment(\.dismiss) var dismiss
    
    var levelNo: Int
    @StateObject var tilesViewModel = TilesViewModel()
    
    var body: some View {
        ZStack {
            backdrop
            
            VStack{
                HStack{
                    Button {
                        dismiss()
                    } label: {
                        Text("< Back")
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(80), maxHeight: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.headline)
                    }.padding(.all, Sizing.isPhone ? 4 : nil)

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
                    .padding(.all, Sizing.isPhone ? 4 : nil)
                    NavigationLink(destination: HelpPageView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                            EmptyView()
                        }
                    
                }.padding(.horizontal, Sizing.isPhone ? 4 : 10)
                
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
            .padding(.all, Sizing.isPhone ? 6 : nil)
            .frame(maxWidth: .infinity, maxHeight: screenHeight, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "postplay")
        }
    }
    
}

extension PostplayView {
    /// The flat colour and the music-note pattern. iPad draws them as two layers, as always; iPhone fits the pattern to the screen.
    @ViewBuilder
    fileprivate var backdrop: some View {
        if Sizing.isPhone {
            ScreenBackdrop(color: Color.softGreen)
        } else {
            Rectangle()
                .fill(Color.softGreen)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
        }
    }
}
