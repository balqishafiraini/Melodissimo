//
//  SongRepositoryLearnView.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import SwiftUI

struct SongRepositoryLearnView: View {
    
    var levelFeeder = LevelFeederModel.shared

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var router: AppRouter

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
                                router.push(.songLearn(songTitle: level.songTitle ?? ""))
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

