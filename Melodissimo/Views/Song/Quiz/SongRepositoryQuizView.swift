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

    var trophyRepository = TrophyRepositoryModel()

    /// Observed so an unlock (a purchase, a restored Plus) or a new content release redraws the list.
    @ObservedObject private var entitlements = Entitlements.shared
    @ObservedObject private var content = ContentStore.shared

    /// Every song the app offers: the shipped ones plus whatever a content release added.
    private var songs: [Song] { SongLibrary.all }

    private func isLocked(_ song: Song) -> Bool {
        !entitlements.isUnlocked(packId: song.packId, packs: ContentStore.shared.packs)
    }

    var body: some View {
        ZStack {
            LegacyBackdrop(color: Color.yellow)
            
            VStack{
                ZStack(alignment: Sizing.isPhone ? .top : .center) {
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
                .padding(.all, Sizing.isPhone ? 0 : nil)
                
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: Sizing.isPhone ? 190 : screenWidth * 0.4), spacing: Sizing.isPhone ? 8 : 10)
                        ],
                        spacing: Sizing.isPhone ? 8 : 20
                    ) {
                        ForEach(songs) { song in
                            SoundButton {
                                // A locked song opens its pack's purchase screen; the campaign never goes through here.
                                if isLocked(song) {
                                    router.push(.paywall(packId: song.packId))
                                } else {
                                    router.push(.stageSetup(songId: song.id))
                                }
                            } label: {
                                VStack(spacing: 1) {
                                    if isLocked(song) {
                                        Image(systemName: "lock.fill")
                                            .font(.title)
                                    } else if trophyRepository.isTrophyEarned(songTitle: song.title) {
                                        if Sizing.isPhone {
                                            Image("trophy").resizable().scaledToFit().frame(height: 26)
                                        } else {
                                            Image("trophy")
                                        }
                                    }
                                    Text(song.displayTitle)
                                        .lineLimit(Sizing.isPhone ? 2 : nil)
                                        .minimumScaleFactor(Sizing.isPhone ? 0.6 : 1)
                                        .multilineTextAlignment(.center)
                                    stars(for: song)
                                }
                                .foregroundStyle(.white)
                                .font(.largeTitle)
                                .padding(.horizontal, Sizing.isPhone ? 8 : 0)
                                .frame(width: Sizing.isPhone ? nil : screenWidth * 0.45, height: Sizing.s(250))
                                .frame(maxWidth: Sizing.isPhone ? .infinity : nil)
                                .background(
                                    RoundedRectangle(cornerRadius: Sizing.s(40))
                                        .fill(isLocked(song) ? Color.gray : Color.green)
                                )
                            }
                            .id(song.id)
                        }
                    }
                    .padding(10)
                    .background(Color.clear)
                }

            }
            .topBarScreenPadding(ipad: nil)
            .fillsScreenHeight()
            
        }
        
    }
    

    /// Best Perform stars for a song, under its card.
    private func stars(for song: Song) -> some View {
        let earned = progress.songStars(song.id)
        return HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .foregroundColor(index < earned ? Color.yellow : Color.white.opacity(0.5))
                    .font(.title2)
            }
        }
    }
}
