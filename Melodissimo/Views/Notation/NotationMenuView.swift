//
//  NotationMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI

struct NotationMenuView: View {
    
    @State var isPresenting = false
    @State var isPresentingLearn = false
    @State var isPresentingQuiz = false
    @State var isPresentingHelp = false
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
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
                    NavigationLink(destination: DashboardView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                            EmptyView()
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
                            .fill(Color.softBlue)
                            .frame(width: UIScreen.main.bounds.width*0.4, height: UIScreen.main.bounds.height*0.3)
                        HStack {
                            Image("paper")
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(height: UIScreen.main.bounds.height*0.23, alignment: .topLeading)
                                
                            VStack(alignment: .leading) {
                                Text("NOTATION")
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
                        isPresentingLearn = true
                    }
                    NavigationLink(destination: NotationLearnView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLearn) {
                            EmptyView()
                        }

                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.softBlue)
                            .frame(width: UIScreen.main.bounds.width*0.4, height: UIScreen.main.bounds.height*0.3)
                        HStack {
                            Image("bulb")
                                .resizable()
                                .padding()
                                .scaledToFit()
                                .frame(height: UIScreen.main.bounds.height*0.3, alignment: .topLeading)
                            VStack(alignment: .leading) {
                                Text("NOTATION")
                                    .font(.custom("BalooDa-Regular", size: 20))
                                    .foregroundColor(.white)
                                Text("QUIZ")
                                    .font(.custom("BalooDa-Regular", size: 50))
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
                    NavigationLink(destination: NotationQuizLevelMenuView()
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
