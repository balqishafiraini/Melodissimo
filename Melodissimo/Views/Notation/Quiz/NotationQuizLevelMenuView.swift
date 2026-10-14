//
//  NotationQuizLevelMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 24/10/23.
//

import SwiftUI

struct NotationQuizLevelMenuView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared
    @State private var currentLevel = ProgressStore.shared.highestUnlockedLevel

    private let levelRange = 1...100

    func getCurrentLevelProgress() -> Int {
        return progress.highestUnlockedLevel
    }


    var body: some View {
        if Sizing.isPhone { phoneBody } else { ipadBody }
    }

    /// iPhone: a short title bar, then the levels in a white panel that fills the rest of the safe area. The 100 level
    /// cells are small, three or more to a row, and the panel scrolls.
    private var phoneBody: some View {
        ZStack {
            // Overlays and `.clipped()` before `.ignoresSafeArea()`, so the picture can't make the layout wider than the screen.
            Color.softBlue
                .overlay {
                    Image("notationQuizLevelMenu")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 6) {
                ZStack {
                    VStack(spacing: 0) {
                        Text("Classic Levels")
                            .foregroundColor(.white)
                            .font(Font.largeTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(progress.totalStars(category: "notation", levels: levelRange)) / \(levelRange.count * 3)")
                                .foregroundColor(.white)
                                .font(Font.title3)
                        }
                    }

                    HStack {
                        SoundButton {
                            router.popToRoot()
                        } label: {
                            Text("Menu")
                                .buttonFrame(width: 120, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .font(Font.headline)
                        }

                        Spacer()

                        SoundButton {
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: 44, height: 44)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .font(Font.title)
                        }
                    }
                }
                .padding(.horizontal, 10)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(1..<101, id: \.self) { index in
                            let isLevelEnabled = index <= currentLevel + 1
                            let earnedStars = progress.stars(category: "notation", level: index)
                            SoundButton {
                                if isLevelEnabled {
                                    router.push(.play(PlayRequest(kind: .classic(levelNo: index))))
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("Level \(index)")
                                        .foregroundStyle(Color.darkGreen)
                                        .font(.custom("BalooDa-Regular", size: 20))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    StarRatingView(earned: earnedStars, isEnabled: isLevelEnabled)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(isLevelEnabled ? Color.yellow : Color.gray)
                                )
                            }
                            .disabled(!isLevelEnabled)
                        }
                    }
                    .padding(10)
                }
                .background(RoundedRectangle(cornerRadius: 24).fill(.white))
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
        }
        .onAppear {
            currentLevel = getCurrentLevelProgress()
        }
    }

    /// iPad: the v2 layout, unchanged.
    private var ipadBody: some View {
            ZStack {
                Image("notationQuizLevelMenu")
                    .resizable()
                    .scaledToFill()
                    .frame(height: screenHeight)
                    .ignoresSafeArea()
                
                VStack {
                    ZStack {
                        VStack(spacing: 4) {
                            Text("Classic Levels")
                                .foregroundColor(.white)
                                .font(Font.largeTitle)
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(progress.totalStars(category: "notation", levels: levelRange)) / \(levelRange.count * 3)")
                                    .foregroundColor(.white)
                                    .font(Font.title3)
                            }
                        }

                        HStack {
                            SoundButton {
                                router.popToRoot()
                            } label: {
                                Text("Menu")
                                    .frame(width: 120, height: 80)
                                    .background(Color.darkGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .font(Font.headline)
                            }

                            Spacer()

                            SoundButton {
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
                    .padding(.init(top: 30, leading: 30, bottom: 0, trailing: 30))
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white)
                            .padding()
                            .frame(width: screenWidth, height: screenHeight*0.8)
                        
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: screenWidth * 0.2), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(1..<101, id: \.self) { index in
                                    let isLevelEnabled = index <= currentLevel + 1
                                    let earnedStars = progress.stars(category: "notation", level: index)
                                    SoundButton {
                                        if isLevelEnabled {
                                            router.push(.play(PlayRequest(kind: .classic(levelNo: index))))
                                        }
                                    }label: {
                                        VStack(spacing: 12) {
                                            Text("Level \(index)")
                                                .foregroundStyle(Color.darkGreen)
                                                .font(.largeTitle)
                                            StarRatingView(earned: earnedStars, isEnabled: isLevelEnabled)
                                        }
                                        .frame(width: screenWidth * 0.2, height: 250)
                                        .background(
                                            RoundedRectangle(cornerRadius: 40)
                                                .fill(isLevelEnabled ? Color.yellow : Color.gray)
                                        )
                                    }
                                    .disabled(!isLevelEnabled)
                                }
                            }
                            .padding(10)
                            .background(Color.clear)
                        }
                        .frame(width: screenWidth * 0.95, height: screenHeight*0.75)

                    }.padding()

                    Spacer()
                }.padding()
            }
        .onAppear {
            currentLevel = getCurrentLevelProgress()
        }
        .ignoresSafeArea()
    }
}

/// Shows up to three stars, filling in the ones the player has earned on a level.
struct StarRatingView: View {
    var earned: Int
    var isEnabled: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .foregroundColor(index < earned ? .orange : Color.darkGreen.opacity(isEnabled ? 0.4 : 0.6))
            }
        }
        .font(Sizing.isPhone ? Font.custom("BalooDa-Regular", size: 15) : Font.title2)
    }
}
