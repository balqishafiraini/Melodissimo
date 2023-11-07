//
//  SongMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI

struct SongMenuView: View {
    
    @State var isPresenting = false
    @State var isPresentingLearn = false
    @State var isPresentingQuiz = false
    @State var isPresentingHelp = false
    
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
                        Text("Back")
                            .frame(width: 120, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    
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
                                    .font(.custom("BalooDa-Regular", size: 30))
                                    .foregroundColor(.white)
                                Text("LEARN")
                                    .font(.custom("BalooDa-Regular", size: 55))
                                    .foregroundColor(.white)
                                
                            }
                            .padding()
                            .frame(alignment: .topLeading)
                        }
                        .frame(alignment: .topLeading)
                    }
                    .onTapGesture {
                        isPresentingLearn = true
                    }
                    NavigationLink(destination: SongRepositoryLearnView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLearn) {
                            EmptyView()
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
                                .frame(height: UIScreen.main.bounds.height*0.3, alignment: .topLeading)
                                
                            VStack(alignment: .leading) {
                                Text("SONG")
                                    .font(.custom("BalooDa-Regular", size: 30))
                                    .foregroundColor(.white)
                                Text("QUIZ")
                                    .font(.custom("BalooDa-Regular", size: 55))
                                    .foregroundColor(.white)
                                
                            }
                            .padding()
                            .frame(alignment: .topLeading)
                        }
                        .frame(alignment: .topLeading)
                    }
                    .onTapGesture {
                        isPresentingQuiz = true
                    }
                    NavigationLink(destination: SongRepositoryQuizView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingQuiz) {
                            EmptyView()
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
