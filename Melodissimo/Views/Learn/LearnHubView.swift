//
//  LearnHubView.swift
//  Melodissimo
//

import SwiftUI

/// The teaching side of the app in one place: the note lessons, the song lessons and the
/// skill test that follows playing.
struct LearnHubView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.softGreen)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            VStack(spacing: 24) {
                ZStack {
                    Text("Learn")
                        .font(Font.largeTitle)
                        .foregroundColor(Color.darkGreen)

                    HStack {
                        Button {
                            router.pop()
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

                VStack(spacing: 24) {
                    HubCard(title: "Notes", subtitle: "Read and play every note", icon: "icon_stage_battle",
                            color: Color.darkGreen) {
                        router.push(.notationLearn)
                    }
                    HubCard(title: "Songs", subtitle: "Learn a song step by step", icon: "icon_stage_song",
                            color: Color.darkGreen) {
                        router.push(.songRepositoryLearn)
                    }
                    HubCard(title: "Skill Test", subtitle: "See what you remember", icon: "icon_stage_finale",
                            color: Color.darkGreen) {
                        router.push(.postplay)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(30)
        }
    }
}
