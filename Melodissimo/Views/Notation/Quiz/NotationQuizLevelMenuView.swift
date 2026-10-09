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
            ZStack {
                Image("notationQuizLevelMenu")
                    .resizable()
                    .scaledToFill()
                    .frame(height: UIScreen.main.bounds.height)
                    .ignoresSafeArea()
                
                VStack {
                    ZStack {
                        VStack(spacing: 4) {
                            Text("Menu Level")
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
                            Button {
                                router.pop(to: .notationMenu)
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
                    .padding(.init(top: 30, leading: 30, bottom: 0, trailing: 30))
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height*0.8)
                        
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: UIScreen.main.bounds.width * 0.2), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(1..<101, id: \.self) { index in
                                    let isLevelEnabled = index <= currentLevel + 1
                                    let earnedStars = progress.stars(category: "notation", level: index)
                                    Button {
                                        if isLevelEnabled {
                                            router.push(.notationQuiz(levelNo: index))
                                        }
                                    }label: {
                                        VStack(spacing: 12) {
                                            Text("Level \(index)")
                                                .foregroundStyle(Color.darkGreen)
                                                .font(.largeTitle)
                                            StarRatingView(earned: earnedStars, isEnabled: isLevelEnabled)
                                        }
                                        .frame(width: UIScreen.main.bounds.width * 0.2, height: 250)
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
                        .frame(width: UIScreen.main.bounds.width * 0.95, height: UIScreen.main.bounds.height*0.75)

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
        .font(.title2)
    }
}
