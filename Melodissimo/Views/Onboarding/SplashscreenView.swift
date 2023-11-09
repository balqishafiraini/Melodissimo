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
            }
            .onAppear{
                withAnimation(.easeInOut(duration: 3.0)) {
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
