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
                        Text("< Back")
                            .frame(width: 120, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }.padding()
                    
                    Spacer()
                    
                    Text(songTitle) // Display the songTitle
                        .foregroundColor(Color.darkGreen)
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
                    .padding()
                    NavigationLink(destination: HelpPageView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                            EmptyView()
                        }
                    
                }
                .padding([.leading, .trailing])
                
                ScrollView {
                    ZStack {
                        if let songNotImg = tilesViewModel.currentLevel?.songNotImg {
                            Image(songNotImg)
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width)
                        }
                    }
                }
                
                ScrollViewReader { scrollViewProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tilesViewModel.answers.indices, id: \.self) { index in
                                Text(tilesViewModel.getStringRepresentation(for: tilesViewModel.answers[index]))
                                    .foregroundColor(Color.darkGreen)
                                    .cornerRadius(20)
                                    .font(Font.subheadline)
                            }
                            .onChange(of: tilesViewModel.answers.count) { _ in
                                withAnimation {
                                    scrollViewProxy.scrollTo(tilesViewModel.answers.count - 1)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(minWidth: UIScreen.main.bounds.width)
                }
                
                Button {
                    tilesViewModel.resetAll()
                }label: {
                    Text("Reset")
                        .frame(width: 80, height: 30)
                        .background(Color.darkGreen)
                        .foregroundColor(Color.white)
                        .cornerRadius(20)
                        .font(Font.body)
                }
                
                PianikaStackQuizMini(viewModel: tilesViewModel)
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
