//
//  SongRepositoryLearnView.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import SwiftUI

struct SongRepositoryLearnView: View {
    
    @State var isPresenting = false
    @State private var isPresentingHelp = false
    @State private var isPresentingLevel = false
    @State private var isPresentingMenu = false
    @State private var selectedSongTitle: String?
    
    var levelFeeder = LevelFeederModel()
    
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
                        dismiss()
                    } label: {
                        Text("< Back")
                            .frame(width: 120, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    
                    Spacer()
                    
                    Text("Learn Song Notation Repository")
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
                        ForEach(levelFeeder.levels.filter { $0.levelCategory == "song" }, id: \.self) { level in
                            Button {
                                selectedSongTitle = level.songTitle
                                isPresentingLevel = true
                            } label: {
                                Text(level.songTitle ?? "")
                                    .foregroundStyle(.white)
                                    .font(.largeTitle)
                                    .frame(width: UIScreen.main.bounds.width * 0.45, height: 250)
                                    .background(
                                        RoundedRectangle(cornerRadius: 40)
                                            .fill(Color.green)
                                    )
                            }
                            .background(
                                NavigationLink("", destination: SongLearnView(songTitle: selectedSongTitle ?? "").navigationBarBackButtonHidden(true), isActive: $isPresentingLevel)
                                    
                            )
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

