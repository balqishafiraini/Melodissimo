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
    
    @State var buttonPressed = false
    var keySound: String
    var labelNot: String?
    
    var body: some View {
        Button(action: {stopSound()},
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
    var keySound: String
    var labelNot: String?
    
    var body: some View {
        Button(action: {stopSound()},
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
    
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: UIScreen.main.bounds.size.width, height: 450)
                .cornerRadius(50)
            
            HStack (spacing: 2){
                
                Group {
                    WhiteTilesButton (keySound: "f1")
                    WhiteTilesButton (keySound: "g1")
                    WhiteTilesButton (keySound: "a1")
                    WhiteTilesButton (keySound: "b1")
                }
                
                Group {
                    WhiteTilesButton (keySound: "c2")
                    WhiteTilesButton (keySound: "d2")
                    WhiteTilesButton (keySound: "e2")
                    WhiteTilesButton (keySound: "f2")
                    WhiteTilesButton (keySound: "g2")
                    WhiteTilesButton (keySound: "a2")
                    WhiteTilesButton (keySound: "b2")
                }
                
                Group {
                    WhiteTilesButton (keySound: "c3")
                    WhiteTilesButton (keySound: "d3")
                    WhiteTilesButton (keySound: "e3")
                    WhiteTilesButton (keySound: "f3")
                    WhiteTilesButton (keySound: "g3")
                    WhiteTilesButton (keySound: "a3")
                    WhiteTilesButton (keySound: "b3")
                }
                
                WhiteTilesButton (keySound: "c4")
                
            }
            .frame(width: UIScreen.main.bounds.size.width, height: 450)
            
            
            
            HStack{
                HStack(spacing: UIScreen.main.bounds.width*0.06) {
                    HStack {
                        BlackTilesButton (keySound: "f1s")
                        BlackTilesButton (keySound: "g1s")
                        BlackTilesButton (keySound: "a1s")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c2s")
                        BlackTilesButton (keySound: "d2s")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f2s")
                        BlackTilesButton (keySound: "g2s")
                        BlackTilesButton (keySound: "a2s")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "c3s")
                        BlackTilesButton (keySound: "d3s")
                    }
                    
                    HStack {
                        BlackTilesButton (keySound: "f3s")
                        BlackTilesButton (keySound: "g3s")
                        BlackTilesButton (keySound: "a3s")
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.size.width*0.88, height: 350, alignment: .topLeading)
        }
        .frame(width: UIScreen.main.bounds.size.width, height: 450, alignment: .topLeading)
        .padding()

        
    }
    
    
}
