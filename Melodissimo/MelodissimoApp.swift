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
        // Mirror progress to iCloud (a no-op unless `OnlineServices.isEnabled`). Game Center signs in later,
        // from Home's first appearance.
        CloudSync.shared.start()
        // Cached flags, tuning and update policy at once; a refresh in the background (never blocks launch).
        // Melodissimo Plus members get the free revive; the entitlement is cached, so it works offline too.
        Revive.isPlusMember = { Entitlements.shared.isPlusActive }
        ContentStore.shared.loadActive()
        DispatchQueue.global(qos: .utility).async { ContentStore.shared.collectGarbage() }
        Task { @MainActor in
            BootstrapService.shared.onContent = { info in
                guard let info else { return }
                Task { await ContentSync.shared.sync(to: info) }
            }
            BootstrapService.shared.start()
        }
        // Listen for store transactions from launch, so a purchase is never missed.
        Task { @MainActor in StoreService.shared.start() }
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

