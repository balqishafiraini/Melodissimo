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
        let shareText = NSLocalizedString("Learn melodica (pianika) in a more fun way with Melodissimo! Download it on the App Store (only available on iPad) https://s.id/GetMelodissimo", comment: "")

        NavigationView {
            ZStack{
                Image("dashboard")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack (alignment: .leading, spacing: 1){
                    HStack{
                        Spacer()
                        Button {
                            // Finding the key window scene
                            if let keyWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                // Accessing the key window from the window scene
                                if let rootViewController = keyWindowScene.windows.first?.rootViewController {
                                    let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                                    
                                    // Adjust popover presentation on iPad
                                    activityViewController.popoverPresentationController?.sourceView = rootViewController.view
                                    activityViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                                    
                                    // Presenting the share sheet
                                    rootViewController.present(activityViewController, animated: true, completion: nil)
                                }
                            }
                        } label: {
                            Text("Share")
                                .frame(width: 200, height: 80)
                                .background(Color.yellow)
                                .foregroundColor(Color.darkGreen)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }
                        Button {
                            isPresentingHelp = true
                        } label: {
                            Text("Help")
                                .frame(width: 150, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }
                        .padding(.trailing)
                        NavigationLink(destination: HelpPageView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                                EmptyView()
                            }
                    }
                    .padding()
                    Text("Hello! What do you want to learn today?")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                                        
                    Spacer()
                    
                    HStack{
                        Spacer()
                        
                        Button {
                            isPresentingNotation = true
                        } label: {
                            Image("notationMenuButton")
                        }
                        NavigationLink(destination: NotationMenuView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingNotation) {
                                EmptyView()
                            }
                        
                        Spacer()
                        
                        Button {
                            isPresentingSong = true
                        } label: {
                            Image("songMenuButton")
                        }
                        NavigationLink(destination: SongMenuView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingSong) {
                                EmptyView()
                            }
                        
                        Spacer()
                        
                        Button {
                            isPresentingPostPlay = true
                        } label: {
                            Image("postplayMenuButton")
                        }
                        NavigationLink(destination: OnboardPostplayView()
                            .navigationBarBackButtonHidden(true), isActive: $isPresentingPostPlay) {
                                EmptyView()
                            }
                        
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
                .frame(height: UIScreen.main.bounds.height, alignment: .topLeading)
                
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        
    }
    
}
