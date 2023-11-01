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
struct WhiteTilesQuizButton: View {
    
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

struct WhiteTilesButton: View {
    
    
    @State var buttonPressed = false
    var keySound: String
    var labelNot: String?
    
    var body: some View {
        Button(action: {
            stopSound()
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
struct BlackTilesQuizButton: View {
    
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

struct BlackTilesButton: View {
        
    var keySound: String
    var labelNot: String?
    
    var body: some View {
        Button(action: {
            stopSound()
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


struct PianikaStackLearning: View {
    
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

struct PianikaStackQuiz: View {
    
    @ObservedObject var viewModel: TilesViewModel

    var body: some View {
        
        NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers).navigationBarBackButtonHidden(true), isActive: $viewModel.canNavigateToAfterQuizPage) {
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
                    WhiteTilesQuizButton (keySound: "f1", id: 1)
                    WhiteTilesQuizButton (keySound: "g1", id: 2)
                    WhiteTilesQuizButton (keySound: "a1", id: 3)
                    WhiteTilesQuizButton (keySound: "b1", id: 4)
                }
                
                Group {
                    WhiteTilesQuizButton (keySound: "c2", id: 5)
                    WhiteTilesQuizButton (keySound: "d2", id: 6)
                    WhiteTilesQuizButton (keySound: "e2", id: 7)
                    WhiteTilesQuizButton (keySound: "f2", id: 8)
                    WhiteTilesQuizButton (keySound: "g2", id: 9)
                    WhiteTilesQuizButton (keySound: "a2", id: 10)
                    WhiteTilesQuizButton (keySound: "b2", id: 11)
                }
                
                Group {
                    WhiteTilesQuizButton (keySound: "c3", id: 12)
                    WhiteTilesQuizButton (keySound: "d3", id: 13)
                    WhiteTilesQuizButton (keySound: "e3", id: 14)
                    WhiteTilesQuizButton (keySound: "f3", id: 15)
                    WhiteTilesQuizButton (keySound: "g3", id: 16)
                    WhiteTilesQuizButton (keySound: "a3", id: 17)
                    WhiteTilesQuizButton (keySound: "b3", id: 18)
                }
                
                WhiteTilesQuizButton (keySound: "c4", id: 19)
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 450)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesQuizButton (keySound: "f1s", id: 20)
                        BlackTilesQuizButton (keySound: "g1s", id: 21)
                        BlackTilesQuizButton (keySound: "a1s", id: 22)
                    }
                    
                    HStack {
                        BlackTilesQuizButton (keySound: "c2s", id: 23)
                        BlackTilesQuizButton (keySound: "d2s", id: 24)
                    }
                    
                    HStack {
                        BlackTilesQuizButton (keySound: "f2s", id: 25)
                        BlackTilesQuizButton (keySound: "g2s", id: 26)
                        BlackTilesQuizButton (keySound: "a2s", id: 27)
                    }
                    
                    HStack {
                        BlackTilesQuizButton (keySound: "c3s", id: 28)
                        BlackTilesQuizButton (keySound: "d3s", id: 29)
                    }
                    
                    HStack {
                        BlackTilesQuizButton (keySound: "f3s", id: 30)
                        BlackTilesQuizButton (keySound: "g3s", id: 31)
                        BlackTilesQuizButton (keySound: "a3s", id: 32)
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
