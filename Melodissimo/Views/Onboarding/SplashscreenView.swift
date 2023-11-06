//
//  ContentView.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI
import Foundation

struct SplashscreenView: View {
    @State private var scale = 0.7
    @Binding var isActive: Bool
    var body: some View {
        VStack {
            VStack {
                Image("splashscreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                //                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            }
            .onAppear{
                withAnimation(.easeIn(duration: 0.7)) {
                    self.scale = 0.9
                }
            }
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}
