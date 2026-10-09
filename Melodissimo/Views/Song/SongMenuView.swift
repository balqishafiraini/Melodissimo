//
//  SongMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI

struct SongMenuView: View {

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
                
                Spacer()
                
                HStack{
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.green)
                            .frame(width: UIScreen.main.bounds.width*0.4, height: UIScreen.main.bounds.height*0.3)
                        HStack {
                            Image("paper")
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(height: UIScreen.main.bounds.height*0.23, alignment: .topLeading)
                            VStack(alignment: .leading) {
                                Text("SONG")
                                    .font(.custom("BalooDa-Regular", size: 20))
                                    .foregroundColor(.white)
                                Text("LEARN")
                                    .font(.custom("BalooDa-Regular", size: 50))
                                    .foregroundColor(.white)
                                
                            }
                            .padding()
                            .frame(alignment: .topLeading)
                        }
                        .frame(alignment: .topLeading)
                    }
                    .onTapGesture {
                        router.push(.songRepositoryLearn)
                    }

                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.green)
                            .frame(width: UIScreen.main.bounds.width*0.4, height: UIScreen.main.bounds.height*0.3)
                        HStack {
                            Image("bulb")
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(height: UIScreen.main.bounds.height*0.23, alignment: .topLeading)
                                
                            VStack(alignment: .leading) {
                                Text("SONG")
                                    .font(.custom("BalooDa-Regular", size: 20))
                                    .foregroundColor(.white)
                                Text("STAGE")
                                    .font(.custom("BalooDa-Regular", size: 50))
                                    .foregroundColor(.white)
                                
                            }
                            .padding()
                            .frame(alignment: .topLeading)
                        }
                        .frame(alignment: .topLeading)
                    }
                    .onTapGesture {
                        router.push(.songRepositoryQuiz)
                    }

                    Spacer()
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
            
        }
        
    }
    
}
