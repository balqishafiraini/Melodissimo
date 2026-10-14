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
            LegacyBackdrop(color: Color.red)
            
            VStack{
                HStack{
                    Button {
                        dismiss()
                    } label: {
                        Text("< Back")
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(80), maxHeight: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.headline)
                    }.padding(.all, Sizing.isPhone ? 4 : nil)
                    
                    Spacer()
                    
                    Button {
                        router.push(.help)
                    } label: {
                        Text("?")
                            .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.title)
                    }.padding(.all, Sizing.isPhone ? 4 : nil)

                }
                .padding(.all, Sizing.isPhone ? 4 : nil)
                
                Spacer()
                
                PianikaStackLearning()
                
                Spacer()
                
                
            }
            .padding(.all, Sizing.isPhone ? 6 : nil)
            .fillsScreenHeight()
        }
    }
}
