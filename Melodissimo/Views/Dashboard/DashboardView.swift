//
//  DashboardView.swift
//  Melodissimo
//
//  Created by Balqis on 11/10/23.
//

import SwiftUI

struct DashboardView: View {
    
    @State var isPresenting = false
    @State var isPresentingNotation = false
    @State var isPresentingSong = false
    @State var isPresentingPostPlay = false
    @State var isPresentingHelp = false
    
    var body: some View {
        NavigationView {
            ZStack{
                Image("dashboardFix")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack{
                    Text("Hello! What do you want to learn today?")
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    
                    HStack{
                        Spacer()
                        
                        Button {
                            isPresentingNotation = true
                        } label: {
                            Image("notationButton")
                        }
                        NavigationLink(destination: NotationMenuView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingNotation) {
                                EmptyView()
                            }
                        
                        Spacer()
                        
                        Button {
                            print("buttontapped")
                        } label: {
                            Image("songButton")
                        }
                        
                        Spacer()
                        
                        Button {
                            print("buttontapped")
                        } label: {
                            Image("postPlayButton")
                        }
                        
                        Spacer()
                    }
                }
                
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        
    }
}
