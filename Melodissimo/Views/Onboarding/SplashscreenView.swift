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
                if Sizing.isPhone {
                    // The 4:3 art would lose "Welcome to" and the fence on a 2.2:1 phone screen, so the whole picture is
                    // shown, with a blurred copy of itself filling the sides.
                    // Overlays, not a ZStack: the zoomed copy must not make the layout bigger than the screen.
                    Color.softBlue
                        .overlay {
                            Image("splashscreen")
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 20)
                        }
                        .overlay {
                            Image("splashscreen")
                                .resizable()
                                .scaledToFit()
                        }
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    Image("splashscreen")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
            }
            .onAppear{
                withAnimation(.easeInOut(duration: 3.0)) {
                    self.scale = 0.9
                }
            }
        }.onAppear {
            #if DEBUG
            if QARoutes.skipsSplash {
                isActive = true
                return
            }
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}
