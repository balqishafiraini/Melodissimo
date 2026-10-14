//
//  SongRepositoryView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI

struct SongRepositoryQuizView: View {

    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    var levelFeeder = LevelFeederModel.shared
    var trophyRepository = TrophyRepositoryModel()

    var filteredSongLevels: [LevelModel] {
        return levelFeeder.levels.filter { $0.levelCategory == "song" }
    }

    var body: some View {
        ZStack {
            LegacyBackdrop(color: Color.yellow)
            
            VStack{
                ZStack {
                    Text("Song Stage")
                        .foregroundColor(Color.darkGreen)
                        .font(Font.largeTitle)

                    HStack{
                        SoundButton {
                            router.popToRoot()
                        } label: {
                            Text("Menu")
                                .buttonFrame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(Sizing.s(20))
                                .font(Font.headline)
                        }

                        Spacer()

                        SoundButton {
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(Sizing.s(20))
                                .font(Font.title)
                        }
                    }
                }
                .padding(.all, Sizing.isPhone ? 4 : nil)
                
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: Sizing.isPhone ? 190 : screenWidth * 0.4), spacing: Sizing.isPhone ? 8 : 10)
                        ],
                        spacing: Sizing.isPhone ? 8 : 20
                    ) {
                        ForEach(filteredSongLevels) { level in
                            SoundButton {
                                router.push(.stageSetup(songId: SongLibrary.slug(for: level.songTitle ?? "")))
                            } label: {
                                VStack(spacing: 1) {
                                    if trophyRepository.isTrophyEarned(songTitle: level.songTitle ?? "") {
                                        if Sizing.isPhone {
                                            Image("trophy").resizable().scaledToFit().frame(height: 26)
                                        } else {
                                            Image("trophy")
                                        }
                                    }
                                    Text(level.songTitle ?? "Unknown Song Title")
                                        .lineLimit(Sizing.isPhone ? 2 : nil)
                                        .minimumScaleFactor(Sizing.isPhone ? 0.6 : 1)
                                        .multilineTextAlignment(.center)
                                    stars(for: level.songTitle ?? "")
                                }
                                .foregroundStyle(.white)
                                .font(.largeTitle)
                                .padding(.horizontal, Sizing.isPhone ? 8 : 0)
                                .frame(width: Sizing.isPhone ? nil : screenWidth * 0.45, height: Sizing.s(250))
                                .frame(maxWidth: Sizing.isPhone ? .infinity : nil)
                                .background(
                                    RoundedRectangle(cornerRadius: Sizing.s(40))
                                        .fill(Color.green)
                                )
                            }
                            .id(level.songTitle ?? "")
                        }
                    }
                    .padding(10)
                    .background(Color.clear)
                }

            }
            .padding(.all, Sizing.isPhone ? 6 : nil)
            .fillsScreenHeight()
            
        }
        
    }
    

    /// Best Perform stars for a song, under its card.
    private func stars(for songTitle: String) -> some View {
        let earned = progress.songStars(SongLibrary.slug(for: songTitle))
        return HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .foregroundColor(index < earned ? Color.yellow : Color.white.opacity(0.5))
                    .font(.title2)
            }
        }
    }
}
