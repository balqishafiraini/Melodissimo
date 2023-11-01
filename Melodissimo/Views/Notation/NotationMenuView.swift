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
                    
                    Button {
                        isPresentingLearn = true
                    } label: {
                        Image("notationLearnIcon")
                    }
                    NavigationLink(destination: NotationLearnView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingLearn) {
                            EmptyView()
                        }
                    
                    Spacer()
                    
                    Button {
                        isPresentingQuiz = true
                    } label: {
                        Image("notationQuizIcon")
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
