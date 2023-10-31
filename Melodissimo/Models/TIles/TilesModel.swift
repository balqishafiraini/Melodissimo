//
//  TilesModel.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import SwiftUI

//style white tiles
struct WhiteTilesStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: UIScreen.main.bounds.width*0.048, height: 350, alignment: .bottom)
            .background(configuration.isPressed ? .gray : .white)
            .foregroundColor(!configuration.isPressed ? .black : .white)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

//style black tiles
struct BlackTilesStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: UIScreen.main.bounds.width*0.042, height: 220, alignment: .bottom)
            .background(configuration.isPressed ? .gray : .black)
            .foregroundColor(!configuration.isPressed ? .white : .black)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

//button white tiles
struct WhiteTilesButton: View {
    
    @EnvironmentObject var viewModel: TilesViewModel
    
    @State var buttonPressed = false
    var keySound: String
    var labelNot: String?
    var id: Int?
    
    var body: some View {
        Button(action: {
            stopSound()
            
            print("Button ID: \(id ?? -1) is pressed")
            viewModel.addAnswer(id ?? -1)
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(WhiteTilesStyle())
        .onLongPressGesture(minimumDuration: 0, perform: {}) {
            pressing in
            if pressing {
                playSound(key: keySound)
            }
        }
    }
}

//button black tiles
struct BlackTilesButton: View {
    
    @EnvironmentObject var viewModel: TilesViewModel
    
    var keySound: String
    var labelNot: String?
    var id: Int?

    
    var body: some View {
        Button(action: {
            stopSound()
            
            print("Button ID: \(id ?? -1) is pressed")
            viewModel.addAnswer(id ?? -1)
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(BlackTilesStyle())
        .onLongPressGesture(minimumDuration: 0, perform: {}) {
            pressing in
            if pressing {
                playSound(key: keySound)
            }
        }
    }
}


struct PianikaStackWithLabel: View {
    
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width, height: 450)
                .cornerRadius(50)
            
            HStack (spacing: 2){
                
                Group {
                    WhiteTilesButton (keySound: "f1", labelNot: "4.")
                    WhiteTilesButton (keySound: "g1", labelNot: "5.")
                    WhiteTilesButton (keySound: "a1", labelNot: "6.")
                    WhiteTilesButton (keySound: "b1", labelNot: "7.")
                }
                
                Group {
                    WhiteTilesButton (keySound: "c2", labelNot: "1")
                    WhiteTilesButton (keySound: "d2", labelNot: "2")
                    WhiteTilesButton (keySound: "e2", labelNot: "3")
                    WhiteTilesButton (keySound: "f2", labelNot: "4")
                    WhiteTilesButton (keySound: "g2", labelNot: "5")
                    WhiteTilesButton (keySound: "a2", labelNot: "6")
                    WhiteTilesButton (keySound: "b2", labelNot: "7")
                }
                
                Group {
                    WhiteTilesButton (keySound: "c3", labelNot: "1˙")
                    WhiteTilesButton (keySound: "d3", labelNot: "2˙")
                    WhiteTilesButton (keySound: "e3", labelNot: "3˙")
                    WhiteTilesButton (keySound: "f3", labelNot: "4˙")
                    WhiteTilesButton (keySound: "g3", labelNot: "5˙")
                    WhiteTilesButton (keySound: "a3", labelNot: "6˙")
                    WhiteTilesButton (keySound: "b3", labelNot: "7˙")
                }
                
                WhiteTilesButton (keySound: "c4", labelNot: "1˙'")
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 450)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesButton (keySound: "f1s", labelNot: "4.#")
                        BlackTilesButton (keySound: "g1s", labelNot: "5.#")
                        BlackTilesButton (keySound: "a1s", labelNot: "6.#")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c2s", labelNot: "1#")
                        BlackTilesButton (keySound: "d2s", labelNot: "2#")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f2s", labelNot: "4#")
                        BlackTilesButton (keySound: "g2s", labelNot: "5#")
                        BlackTilesButton (keySound: "a2s", labelNot: "6#")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c3s", labelNot: "1˙#")
                        BlackTilesButton (keySound: "d3s", labelNot: "2˙#")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f3s", labelNot: "4˙#")
                        BlackTilesButton (keySound: "g3s", labelNot: "5˙#")
                        BlackTilesButton (keySound: "a3s", labelNot: "6˙#")
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.size.width*0.88, height: 350, alignment: .topLeading)
        }
        .frame(width: UIScreen.main.bounds.size.width, height: 450, alignment: .topLeading)
        .padding()
    }
    
    
}

struct PianikaStackWithoutLabel: View {
    
    @ObservedObject var viewModel: TilesViewModel

    var body: some View {
        
        NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers), isActive: $viewModel.canNavigateToAfterQuizPage) {
            Text("")
        }
        
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width, height: 450)
                .cornerRadius(50)
            
            HStack (spacing: 2){
                
                Group {
                    WhiteTilesButton (keySound: "f1", id: 1)
                    WhiteTilesButton (keySound: "g1", id: 2)
                    WhiteTilesButton (keySound: "a1", id: 3)
                    WhiteTilesButton (keySound: "b1", id: 4)
                }
                
                Group {
                    WhiteTilesButton (keySound: "c2", id: 5)
                    WhiteTilesButton (keySound: "d2", id: 6)
                    WhiteTilesButton (keySound: "e2", id: 7)
                    WhiteTilesButton (keySound: "f2", id: 8)
                    WhiteTilesButton (keySound: "g2", id: 9)
                    WhiteTilesButton (keySound: "a2", id: 10)
                    WhiteTilesButton (keySound: "b2", id: 11)
                }
                
                Group {
                    WhiteTilesButton (keySound: "c3", id: 12)
                    WhiteTilesButton (keySound: "d3", id: 13)
                    WhiteTilesButton (keySound: "e3", id: 14)
                    WhiteTilesButton (keySound: "f3", id: 15)
                    WhiteTilesButton (keySound: "g3", id: 16)
                    WhiteTilesButton (keySound: "a3", id: 17)
                    WhiteTilesButton (keySound: "b3", id: 18)
                }
                
                WhiteTilesButton (keySound: "c4", id: 19)
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 450)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesButton (keySound: "f1s", id: 20)
                        BlackTilesButton (keySound: "g1s", id: 21)
                        BlackTilesButton (keySound: "a1s", id: 22)
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c2s", id: 23)
                        BlackTilesButton (keySound: "d2s", id: 24)
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f2s", id: 25)
                        BlackTilesButton (keySound: "g2s", id: 26)
                        BlackTilesButton (keySound: "a2s", id: 27)
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c3s", id: 28)
                        BlackTilesButton (keySound: "d3s", id: 29)
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f3s", id: 30)
                        BlackTilesButton (keySound: "g3s", id: 31)
                        BlackTilesButton (keySound: "a3s", id: 32)
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.size.width*0.88, height: 350, alignment: .topLeading)
        }
        .frame(width: UIScreen.main.bounds.size.width, height: 450, alignment: .topLeading)
        .padding()
        .environmentObject(viewModel)
        
    }
    
    
}
