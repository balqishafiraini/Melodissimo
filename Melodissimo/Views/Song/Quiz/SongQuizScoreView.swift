//
//  SongQuizScoreView.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import SwiftUI

struct SongQuizScoreView: View {
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    var score: Int
    
    var songTitle: String
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(Color.yellow)
                    .scaledToFill()
                
                Image("bgMusic")
                    .scaledToFill()
                
                VStack{
                    HStack{
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
                    
                    Spacer()
                    
                    HStack{
                        Spacer()
                        VStack (spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.navy)
                                    .frame(width: 200, height: 200)
                                VStack{
                                    Text("Score:")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Text("\(score)")
                                        .font(.custom("BalooDa-Regular", size: 80))
                                        .foregroundColor(.white)

                                }
                                
                            }
                            Text("Great job for finishing the song! If you are hit 100% score, you'll see a trophy in the repository shelf")
                                .multilineTextAlignment(.center)
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: 200)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Button {
                                isPresenting = true
                                
                            } label: {
                                Text("Menu")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.navy)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }
                            NavigationLink(destination: SongRepositoryQuizView()
                                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                    EmptyView()
                                }
                            
                            Spacer()
                            
                        }
                        Spacer()
                        Image("alpanicaGlasses")
                            .resizable()
                            .scaledToFit()
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
                
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if score == 100 {
                UserDefaults.standard.set(true, forKey: songTitle)
            }
        }
        
    }
}
