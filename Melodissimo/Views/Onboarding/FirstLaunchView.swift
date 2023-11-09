//
//  FirstLaunchView.swift
//  Melodissimo
//
//  Created by Balqis on 01/11/23.
//

import SwiftUI

struct FirstLaunchView: View {
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(Color.softBlue)
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
                        VStack {
                            Spacer()
                            Text("Hello! Welcome to Melodissimo. Before learn more with us, let’s do some test to measure your skill 🥰")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: 300)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Button {
                                isPresenting = true

                            } label: {
                                Text("Next")
                                    .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
                                    .background(Color.yellow)
                                    .foregroundColor(Color.red)
                                    .cornerRadius(20)
                                    .font(Font.title)
                            }
                            NavigationLink(destination: PreplayView(levelNo: 1)
                                .navigationBarBackButtonHidden(true), isActive: $isPresenting) {
                                    EmptyView()
                                }
                            
                            Spacer()
                            
                        }
                        Spacer()
                        Image("alpanica")
                            .scaledToFit()
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)

            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        
    }
    
}
