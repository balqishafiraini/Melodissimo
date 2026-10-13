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
        SFX.shared.preload()
        // Players with classic levels already cleared start further along the Nusantara Tour (runs once).
        ProgressStore.shared.runMigrationIfNeeded()
        // Mirror progress to iCloud (needs the iCloud key-value capability; a no-op without it).
        CloudSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            CoordinatorView()
        }
    }
}

