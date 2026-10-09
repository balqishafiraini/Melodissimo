//
//  MelodissimoApp.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI

@main
struct MelodissimoApp: App {

    init() {
        // Warm the note-sample cache so the first tap on any key plays instantly.
        preloadAllSounds()
    }

    var body: some Scene {
        WindowGroup {
            CoordinatorView()
        }
    }
}

