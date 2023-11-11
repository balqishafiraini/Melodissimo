//
//  OnboardPostplayView.swift
//  Melodissimo
//
//  Created by Balqis on 09/11/23.
//

import SwiftUI

struct OnboardPostplayView: View {
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(Color.softGreen)
                    .scaledToFill()
                
                Image("bgMusic")
                    .scaledToFill()
                
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
                            Text("Thank you for learn with Melodissimo! Now, let's test your skill again in Post-Play Quiz, it's similar when you do it on Pre-Play Quiz~")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5)
                                .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                            
                            Spacer()
                            
                            Text("Pre-Play score: \(UserDefaults.standard.integer(forKey: "preplayScore"))\n Post-Play Score: \(UserDefaults.standard.integer(forKey: "postplayScore"))")
                                .padding()
                                .foregroundStyle(.black)
                                .font(.headline)
                                .frame(width: UIScreen.main.bounds.width * 0.5, alignment: .leading)
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
                            NavigationLink(destination: PostplayView(levelNo: 1)
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
