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
            LegacyBackdrop(color: Color.yellow)
            
            VStack{
                HStack(alignment: Sizing.isPhone ? .top : .center) {
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
                    }
                    
                    Spacer()
                    
                    Text("Learn Song Notation Repository")
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(20)
                        .font(Font.largeTitle)
                        .lineLimit(Sizing.isPhone ? 1 : nil)
                        .minimumScaleFactor(Sizing.isPhone ? 0.5 : 1)
                    
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

                }
                .padding(.all, Sizing.isPhone ? 0 : nil)
                
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: Sizing.isPhone ? 190 : screenWidth * 0.4), spacing: Sizing.isPhone ? 8 : 10)
                        ],
                        spacing: Sizing.isPhone ? 8 : 20
                    ) {
                        ForEach(levelFeeder.levels.filter { $0.levelCategory == "song" }, id: \.self) { level in
                            Button {
                                router.push(.songLearn(songTitle: level.songTitle ?? ""))
                            } label: {
                                Text(level.songTitle ?? "")
                                    .foregroundStyle(.white)
                                    .font(.largeTitle)
                                    .lineLimit(Sizing.isPhone ? 2 : nil)
                                    .minimumScaleFactor(Sizing.isPhone ? 0.6 : 1)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Sizing.isPhone ? 8 : 0)
                                    .frame(width: Sizing.isPhone ? nil : screenWidth * 0.45, height: Sizing.s(250))
                                    .frame(maxWidth: Sizing.isPhone ? .infinity : nil)
                                    .background(
                                        RoundedRectangle(cornerRadius: Sizing.s(40))
                                            .fill(Color.green)
                                    )
                            }
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
    
}

