//
//  MelodissimoApp.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI

@main
struct MelodissimoApp: App {
    
    var body: some Scene {
        WindowGroup {
            CoordinatorView()
                .environment(\.locale, .init(identifier: "id"))
        }
    }
}

