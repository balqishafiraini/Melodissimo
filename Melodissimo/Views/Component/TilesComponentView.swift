//
//  TilesComponentView.swift
//  Melodissimo
//
//  Created by Balqis on 09/12/23.
//

import Foundation
import SwiftUI

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
            
//            print("Button ID: \(id ?? -1) is pressed")
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(WhiteTilesStyle(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.048 || loc.x < 0 || loc.y > 350 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
                viewModel.addAnswer(id ?? -1)
            }
        })
    }
}


struct WhiteTilesQuizButtonMini: View {
    
    @EnvironmentObject var viewModel: TilesViewModel
    
    @State var buttonPressed = false
    var keySound: String
    var labelNot: String?
    var id: Int?
    
    var body: some View {
        Button(action: {
            stopSound()
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(WhiteTilesStyleMini(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.048 || loc.x < 0 || loc.y > 200 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
                viewModel.addAnswer(id ?? -1)
            }
        })
    }
}

struct WhiteTilesButtonMini: View {
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
        .buttonStyle(WhiteTilesStyleMini(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.048 || loc.x < 0 || loc.y > 200 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
            }
        })
    }
}

struct BlackTilesButtonMini: View {
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
        .buttonStyle(BlackTilesStyleMini(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.048 || loc.x < 0 || loc.y > 200 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
            }
        })
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
        .buttonStyle(WhiteTilesStyle(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.048 || loc.x < 0 || loc.y > 350 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
            }
        })
    }
}

//button black tiles
struct BlackTilesQuizButton: View {
    
    @EnvironmentObject var viewModel: TilesViewModel
    
    @State var buttonPressed = false
    var keySound: String
    var labelNot: String?
    var id: Int?
    
    var body: some View {
        Button(action: {
            stopSound()
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(BlackTilesStyle(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.042 || loc.x < 0 || loc.y > 220 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
                viewModel.addAnswer(id ?? -1)

            }
        })
    }
}
struct BlackTilesQuizButtonMini: View {
    @State var buttonPressed = false

    @EnvironmentObject var viewModel: TilesViewModel
    
    var keySound: String
    var labelNot: String?
    var id: Int?

    
    var body: some View {
        Button(action: {
            stopSound()
        },
               label: {
            Text(labelNot ?? "")
                .font(.subheadline)
        })
        .buttonStyle(BlackTilesStyleMini(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.042 || loc.x < 0 || loc.y > 120 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
                viewModel.addAnswer(id ?? -1)

            }
        })
    }
}

struct BlackTilesButton: View {
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
        .buttonStyle(BlackTilesStyle(isPressed: $buttonPressed))
        .onTouch(limitToBounds: false) { loc in
            //Using UIScreen.main.bound.width bcs the width is dynamic
            if loc.x > UIScreen.main.bounds.width*0.042 || loc.x < 0 || loc.y > 220 || loc.y < 0 {
                buttonPressed = false
            } else {
                buttonPressed = true
            }
        }
        .onChange(of: buttonPressed, perform: { isPressed in
            if isPressed {
                playSound(key: keySound)
            } else {
                stopSound()
            }
        })
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
                
                WhiteTilesButton (keySound: "c4", labelNot: "1˙˙")
                
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

struct PianikaStackLearningMini: View {
    
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width, height: 300)
                .cornerRadius(50)
            
            HStack (spacing: 2){
                
                Group {
                    WhiteTilesButtonMini (keySound: "f1", labelNot: "4.")
                    WhiteTilesButtonMini (keySound: "g1", labelNot: "5.")
                    WhiteTilesButtonMini (keySound: "a1", labelNot: "6.")
                    WhiteTilesButtonMini (keySound: "b1", labelNot: "7.")
                }
                
                Group {
                    WhiteTilesButtonMini (keySound: "c2", labelNot: "1")
                    WhiteTilesButtonMini (keySound: "d2", labelNot: "2")
                    WhiteTilesButtonMini (keySound: "e2", labelNot: "3")
                    WhiteTilesButtonMini (keySound: "f2", labelNot: "4")
                    WhiteTilesButtonMini (keySound: "g2", labelNot: "5")
                    WhiteTilesButtonMini (keySound: "a2", labelNot: "6")
                    WhiteTilesButtonMini (keySound: "b2", labelNot: "7")
                }
                
                Group {
                    WhiteTilesButtonMini (keySound: "c3", labelNot: "1˙")
                    WhiteTilesButtonMini (keySound: "d3", labelNot: "2˙")
                    WhiteTilesButtonMini (keySound: "e3", labelNot: "3˙")
                    WhiteTilesButtonMini (keySound: "f3", labelNot: "4˙")
                    WhiteTilesButtonMini (keySound: "g3", labelNot: "5˙")
                    WhiteTilesButtonMini (keySound: "a3", labelNot: "6˙")
                    WhiteTilesButtonMini (keySound: "b3", labelNot: "7˙")
                }
                
                WhiteTilesButtonMini (keySound: "c4", labelNot: "1˙˙")
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 300)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesButtonMini (keySound: "f1s", labelNot: "4.#")
                        BlackTilesButtonMini (keySound: "g1s", labelNot: "5.#")
                        BlackTilesButtonMini (keySound: "a1s", labelNot: "6.#")
                    }
                    
                    HStack {
                        BlackTilesButtonMini (keySound: "c2s", labelNot: "1#")
                        BlackTilesButtonMini (keySound: "d2s", labelNot: "2#")
                    }
                    
                    HStack {
                        BlackTilesButtonMini (keySound: "f2s", labelNot: "4#")
                        BlackTilesButtonMini (keySound: "g2s", labelNot: "5#")
                        BlackTilesButtonMini (keySound: "a2s", labelNot: "6#")
                    }
                    
                    HStack {
                        BlackTilesButtonMini (keySound: "c3s", labelNot: "1˙#")
                        BlackTilesButtonMini (keySound: "d3s", labelNot: "2˙#")
                    }
                    
                    HStack {
                        BlackTilesButtonMini (keySound: "f3s", labelNot: "4˙#")
                        BlackTilesButtonMini (keySound: "g3s", labelNot: "5˙#")
                        BlackTilesButtonMini (keySound: "a3s", labelNot: "6˙#")
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.size.width*0.88, height: 200, alignment: .topLeading)
        }
        .frame(width: UIScreen.main.bounds.size.width, height: 300, alignment: .topLeading)
        .padding()
    }
    
    
}

struct PianikaStackQuiz: View {
    
    @ObservedObject var viewModel: TilesViewModel

    var body: some View {
        
        NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers, userScore: viewModel.score).navigationBarBackButtonHidden(true), isActive: $viewModel.canNavigateToAfterQuizPage) {
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
struct PianikaStackQuizMini: View {
    
    @ObservedObject var viewModel: TilesViewModel

    var body: some View {
        
        NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers, userScore: viewModel.score).navigationBarBackButtonHidden(true), isActive: $viewModel.canNavigateToAfterQuizPage) {
            Text("")
        }
        
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width, height: 300)
                .cornerRadius(50)
            
            HStack (spacing: 2){
                
                Group {
                    WhiteTilesQuizButtonMini (keySound: "f1", id: 1)
                    WhiteTilesQuizButtonMini (keySound: "g1", id: 2)
                    WhiteTilesQuizButtonMini (keySound: "a1", id: 3)
                    WhiteTilesQuizButtonMini (keySound: "b1", id: 4)
                }
                
                Group {
                    WhiteTilesQuizButtonMini (keySound: "c2", id: 5)
                    WhiteTilesQuizButtonMini (keySound: "d2", id: 6)
                    WhiteTilesQuizButtonMini (keySound: "e2", id: 7)
                    WhiteTilesQuizButtonMini (keySound: "f2", id: 8)
                    WhiteTilesQuizButtonMini (keySound: "g2", id: 9)
                    WhiteTilesQuizButtonMini (keySound: "a2", id: 10)
                    WhiteTilesQuizButtonMini (keySound: "b2", id: 11)
                }
                
                Group {
                    WhiteTilesQuizButtonMini (keySound: "c3", id: 12)
                    WhiteTilesQuizButtonMini (keySound: "d3", id: 13)
                    WhiteTilesQuizButtonMini (keySound: "e3", id: 14)
                    WhiteTilesQuizButtonMini (keySound: "f3", id: 15)
                    WhiteTilesQuizButtonMini (keySound: "g3", id: 16)
                    WhiteTilesQuizButtonMini (keySound: "a3", id: 17)
                    WhiteTilesQuizButtonMini (keySound: "b3", id: 18)
                }
                
                WhiteTilesQuizButtonMini (keySound: "c4", id: 19)
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 300)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesQuizButtonMini (keySound: "f1s", id: 20)
                        BlackTilesQuizButtonMini (keySound: "g1s", id: 21)
                        BlackTilesQuizButtonMini (keySound: "a1s", id: 22)
                    }
                    
                    HStack {
                        BlackTilesQuizButtonMini (keySound: "c2s", id: 23)
                        BlackTilesQuizButtonMini (keySound: "d2s", id: 24)
                    }
                    
                    HStack {
                        BlackTilesQuizButtonMini (keySound: "f2s", id: 25)
                        BlackTilesQuizButtonMini (keySound: "g2s", id: 26)
                        BlackTilesQuizButtonMini (keySound: "a2s", id: 27)
                    }
                    
                    HStack {
                        BlackTilesQuizButtonMini (keySound: "c3s", id: 28)
                        BlackTilesQuizButtonMini (keySound: "d3s", id: 29)
                    }
                    
                    HStack {
                        BlackTilesQuizButtonMini (keySound: "f3s", id: 30)
                        BlackTilesQuizButtonMini (keySound: "g3s", id: 31)
                        BlackTilesQuizButtonMini (keySound: "a3s", id: 32)
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.size.width*0.88, height: 200, alignment: .topLeading)
        }
        .frame(width: UIScreen.main.bounds.size.width, height: 300, alignment: .topLeading)
        .environmentObject(viewModel)
        
    }
    
    
}
