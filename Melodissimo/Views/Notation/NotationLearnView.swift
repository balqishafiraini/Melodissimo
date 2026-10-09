//
//  LearnNotationView.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct NotationLearnView: View {
    
    @State var buttonPressed = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            
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
                    }.padding()
                    
                    Spacer()
                    
                    Button {
                        router.push(.help)
                    } label: {
                        Text("?")
                            .frame(width: 80, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.title)
                    }.padding()

                }
                .padding()
                
                Spacer()
                
                PianikaStackLearning()
                
                Spacer()
                
                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.size.height, alignment: .topLeading)
        }
    }
}
