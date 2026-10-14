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
        #if DEBUG
        // `-qaSeed YES` fills a mid-game profile for the screenshot scripts; a no-op without the argument.
        QARoutes.seedProfile()
        #endif
        // Warm the note-sample cache so the first tap on any key plays instantly.
        preloadAllSounds()
        SFX.shared.preload()
        // Players with classic levels already cleared start further along the Nusantara Tour (runs once).
        ProgressStore.shared.runMigrationIfNeeded()
        // A renamed song keeps its stars and trophy (runs once).
        ProgressStore.shared.migrateRenamedSongs()
        // Mirror progress to iCloud (needs the iCloud key-value capability; a no-op without it).
        CloudSync.shared.start()
        // Sign in to Game Center without any sign-in sheet, so leaderboards can take scores.
        GameCenter.shared.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            CoordinatorView()
            #if DEBUG
                .onAppear { QARoutes.recordOrientation() }
            #endif
        }
    }
}

