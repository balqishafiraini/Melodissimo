//
//  SongQuizView.swift
//  Melodissimo
//
//  Created by Balqis on 07/11/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct SongQuizView: View {
    @State private var isPresentingHelp = false
    @Environment(\.dismiss) var dismiss
    @StateObject private var tilesViewModel = TilesViewModel()
    
    var songTitle: String
    
    @State private var isPresentingLevel = false

    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack(spacing: 1) {
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
                    
                    Text(songTitle) // Display the songTitle
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                    
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
                .padding([.leading, .trailing])
                
                ZStack {
                    Text("\(tilesViewModel.currentLevel?.question[tilesViewModel.currentQuestionIndex] ?? "N/A")")
                        .foregroundStyle(.black)
                        .font(.largeTitle)
                        .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.15)
                        .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                }
                
                PianikaStackQuiz(viewModel: tilesViewModel)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
        }
        .onAppear {
            print("Received Song Title: \(songTitle)")
            // Customize the function behavior based on songTitle
            tilesViewModel.getSongTitle(songTitle: songTitle)
        }
        .onDisappear {
            isPresentingLevel = false
        }

    }
}
