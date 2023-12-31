//
//  SongRepositoryView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI

struct SongRepositoryQuizView: View {
    
    @State var isPresenting = false
    @State private var isPresentingHelp = false
    @State private var isPresentingLevel = false
    @State private var isPresentingMenu = false
    @State private var selectedSongTitle: String?
    
    var levelFeeder = LevelFeederModel()
    var trophyRepository = TrophyRepositoryModel()
    
    var filteredSongLevels: [LevelModel] {
        return levelFeeder.levels.filter { $0.levelCategory == "song" }
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack{
                HStack{
                    Button {
                        isPresenting = true
                    } label: {
                        Text("Menu")
                            .frame(width: 120, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    NavigationLink(destination: SongMenuView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                            EmptyView()
                        }
                    
                    Spacer()
                    
                    Text("Quiz Song Notation Repository")
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(20)
                        .font(Font.largeTitle)
                    
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
                                selectedSongTitle = level.songTitle ?? ""
                                isPresentingLevel = true
                            } label: {
                                VStack(spacing: 1) {
                                    if trophyRepository.isTrophyEarned(songTitle: level.songTitle ?? "") {
                                        Image("trophy")
                                    }
                                    Text(level.songTitle ?? "Unknown Song Title")
                                }
                                .foregroundStyle(.white)
                                .font(.largeTitle)
                                .frame(width: UIScreen.main.bounds.width * 0.45, height: 250)
                                .background(
                                    RoundedRectangle(cornerRadius: 40)
                                        .fill(Color.green)
                                )
                            }
                            .background(
                                NavigationLink("", destination: SongQuizView(songTitle: selectedSongTitle ?? "").navigationBarBackButtonHidden(true), isActive: $isPresentingLevel)
                            )
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
    
}
