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
            Rectangle()
                .fill(Color.yellow)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack{
                ZStack {
                    Text("Song Stage")
                        .foregroundColor(Color.darkGreen)
                        .font(Font.largeTitle)

                    HStack{
                        Button {
                            router.pop(to: .songMenu)
                        } label: {
                            Text("Menu")
                                .frame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }

                        Spacer()

                        Button {
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: 80, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.title)
                        }
                    }
                }
                .padding()
                
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: UIScreen.main.bounds.width * 0.4), spacing: 10)
                        ],
                        spacing: 20
                    ) {
                        ForEach(filteredSongLevels) { level in
                            Button {
                                router.push(.stageSetup(songId: SongLibrary.slug(for: level.songTitle ?? "")))
                            } label: {
                                VStack(spacing: 1) {
                                    if trophyRepository.isTrophyEarned(songTitle: level.songTitle ?? "") {
                                        Image("trophy")
                                    }
                                    Text(level.songTitle ?? "Unknown Song Title")
                                    stars(for: level.songTitle ?? "")
                                }
                                .foregroundStyle(.white)
                                .font(.largeTitle)
                                .frame(width: UIScreen.main.bounds.width * 0.45, height: 250)
                                .background(
                                    RoundedRectangle(cornerRadius: 40)
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
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
            
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
