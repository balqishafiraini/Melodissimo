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
            Rectangle()
                .fill(Color.softGreen)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack{
                HStack{
                    Button {
                        dismiss()
                    } label: {
                        Text("< Back")
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 120, minHeight: 80, maxHeight: 80)
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
                    }
                    .padding()
                    NavigationLink(destination: HelpPageView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                            EmptyView()
                        }
                    
                }.padding(.horizontal, 10)
                
                Spacer()
                
                ZStack {
                    Text("\(tilesViewModel.currentLevel?.question[tilesViewModel.currentQuestionIndex] ?? "N/A")")
                        .foregroundStyle(.black)
                        .font(.custom("BalooDa-Regular", size: 70))
                        .frame(width: screenWidth * 0.5, height: screenHeight * 0.15)
                        .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                }
                
                Spacer()
                
                PianikaStackQuiz(viewModel: tilesViewModel)
                
                Spacer()
                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: screenHeight, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "postplay")
        }
    }
    
}

