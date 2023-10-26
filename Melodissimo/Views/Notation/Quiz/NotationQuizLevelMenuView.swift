//
//  NotationQuizLevelMenuView.swift
//  Melodissimo
//
//  Created by Balqis on 24/10/23.
//

import SwiftUI

struct NotationQuizLevelMenuView: View {
    
    @State var isPresentingHelp = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack{
                Image("notationQuizLevelMenu")
                    .resizable()
                    .scaledToFill()
                    .frame(height: UIScreen.main.bounds.height)
                    .ignoresSafeArea()

                
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
                        }.padding()
                        
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
                        }.padding()
                        NavigationLink(destination: HelpPageView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                                EmptyView()
                            }
                    }.padding()
                    
                    Spacer()
                    
                    ZStack{
                        RoundedRectangle(cornerRadius: 50)
                            .fill(.white)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width, height: 350)
                        
                        
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(1..<101) { index in
                                    Button(action: {
                                        print("Level \(index) tapped")
                                    }) {
                                        Text("Level \(index)")
                                            .foregroundStyle(Color.darkGreen)
                                            .font(.largeTitle)
                                            .frame(width: UIScreen.main.bounds.width * 0.2, height: 250)
                                            .background(RoundedRectangle(cornerRadius: 40).fill(Color.yellow))
                                    }
                                }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width*0.9, height: 350)
//                        .clipped()

                        
                        
                    }.padding()
                    
                    Spacer()
                    
                }.padding()
                
                
            }
        }
        .ignoresSafeArea()
        .navigationViewStyle(StackNavigationViewStyle())
        
    }
}
