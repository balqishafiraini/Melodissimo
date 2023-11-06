//
//  CoordinatorView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import SwiftUI

struct CoordinatorView: View {
    @State private var isActive = false
    
    let isPreplayDone = UserDefaults.standard.bool(forKey: "isPreplayDone")

    var body: some View {
        if isActive {
            if isPreplayDone {
                DashboardView()
            } else {
                FirstLaunchView()
            }
        }else {
            SplashscreenView(isActive: $isActive)
        }
    }
}
