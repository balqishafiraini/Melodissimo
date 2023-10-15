//
//  ContentView.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI
import AVFoundation
import Foundation

struct SplashscreenView: View {
    @State var isPresenting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("splashscreen")
                    .resizable()
                    .ignoresSafeArea()
                    .frame(width: UIScreen.main.bounds.size.width)
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    struct SplashscreenView_Previews: PreviewProvider {
        static var previews: some View {
            SplashscreenView()
        }
    }
}
