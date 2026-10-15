//
//  SongLearnView.swift
//  Melodissimo
//
//  Created by Balqis on 07/11/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct SongLearnView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var router: AppRouter
    @StateObject private var tilesViewModel = TilesViewModel()

    var songTitle: String


    var body: some View {
        ZStack {
            LegacyBackdrop(color: Color.yellow)
            
            VStack(spacing: 1) {
                HStack {
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
                    }.padding(.all, Sizing.isPhone ? 0 : nil)
                    
                    Spacer()
                    
                    Text(songTitle) // Display the songTitle
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Spacer()
                    
                    Button {
                        router.push(.help)
                    } label: {
                        Text("?")
                            .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.title)
                    }
                    .padding(.all, Sizing.isPhone ? 0 : nil)

                }
                .padding(.horizontal, Sizing.isPhone ? 0 : nil)
                
                sheet
                
                PianikaStackLearningMini()
            }
            .topBarScreenPadding(ipad: nil)
            .fillsScreenHeight()
        }
        .onAppear {
            print("Received Song Title: \(songTitle)")
            // Customize the function behavior based on songTitle
            tilesViewModel.getSongTitle(songTitle: songTitle)
        }

    }

    /// The score sheet. iPad: a screen-wide card half a screen tall inside a scroll view, as it always was. iPhone: the card
    /// takes whatever height the mini keyboard leaves (the sheet scrolls by itself).
    @ViewBuilder
    private var sheet: some View {
        if Sizing.isPhone {
            Group {
                if let song = SongLibrary.song(title: songTitle) {
                    NotAngkaSheetView(chart: SongChart.load(for: song))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                } else if let songNotImg = tilesViewModel.currentLevel?.songNotImg {
                    Image(songNotImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.vertical, 4)
        } else {
            ScrollView {
                    ZStack {
                        if let song = SongLibrary.song(title: songTitle) {
                            // Drawn from the chart, so it matches the song stage and the backing track.
                            NotAngkaSheetView(chart: SongChart.load(for: song))
                                .padding()
                                .frame(width: screenWidth, height: screenHeight * 0.5)
                                .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
                        } else if let songNotImg = tilesViewModel.currentLevel?.songNotImg {
                            Image(songNotImg)
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(width: screenWidth)
                        }
                    }
                }
        }
    }
}
