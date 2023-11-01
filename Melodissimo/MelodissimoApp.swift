//
//  MelodissimoApp.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI

@main
struct MelodissimoApp: App {
    let isPreplayDone = UserDefaults.standard.bool(forKey: "isPreplayDone")
    
    var body: some Scene {
        WindowGroup {
            if isPreplayDone {
                DashboardView()
            } else {
                FirstLaunchView()
            }
        }
    }
}

