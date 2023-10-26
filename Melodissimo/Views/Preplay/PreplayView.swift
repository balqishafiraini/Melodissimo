//
//  PreplayView.swift
//  Melodissimo
//
//  Created by Balqis on 03/10/23.
//

import SwiftUI
import Foundation

struct PreplayView: View {
    
    @State var buttonPressed = false
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    var levelNo: Int
    @StateObject var tilesViewModel = TilesViewModel()
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.softBlue)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack{
                
                ZStack {
                    Text("Question: \(tilesViewModel.currentLevel?.question.description ?? "N/A")")
                        .font(.title2)
                        .padding()
                        .background(.white)
                    
                }
                
                Spacer()
                
                PianikaStackWithoutLabel(viewModel: tilesViewModel)
                
                Spacer()
                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "preplay")
        }
    }
}
