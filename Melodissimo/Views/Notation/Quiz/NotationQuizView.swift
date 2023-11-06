//
//  LearnNotationView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct NotationQuizView: View {
    
    @State var buttonPressed = false
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject var tilesViewModel = TilesViewModel()
    
    var levelNo: Int
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
            VStack (spacing: 1){
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
                    
                    Text("Level: \(levelNo)")
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                    
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
                    .padding()
                    NavigationLink(destination: HelpPageView()
                        .navigationBarBackButtonHidden(true), isActive: $isPresentingHelp) {
                            EmptyView()
                        }
                    
                }
                .padding([.leading, .trailing])
                
                ZStack {
                    Text("\(tilesViewModel.currentLevel?.question[tilesViewModel.currentQuestionIndex] ?? "N/A")")
                        .foregroundStyle(.black)
                        .font(.largeTitle)
                        .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height*0.15)
                        .background(RoundedRectangle(cornerRadius: 40).fill(.white))
                }
                
                                
                PianikaStackQuiz(viewModel: tilesViewModel)
                                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
        }
        .onAppear {
            tilesViewModel.getLevel(currentLevelNo: levelNo, currentLevelCat: "quiz")
        }
    }
}
