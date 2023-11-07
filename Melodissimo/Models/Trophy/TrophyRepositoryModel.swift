//
//  TrophyRepository.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import Foundation
import SwiftUI

class TrophyRepository: ObservableObject {
    @Published var trophies: [Trophy] = []
    
    init() {
        // Initialize with your available trophies
        trophies.append(Trophy(name: "100% Quiz Score", description: "Earned when you score 100% in a song quiz", isEarned: false))
        // Load user's earned trophies from UserDefaults or another storage mechanism
        // You can use UserDefaults or CoreData to store user's progress.
        // For simplicity, we'll use UserDefaults in this example.
        if UserDefaults.standard.bool(forKey: "100% Quiz Score") {
            setTrophyEarned("100% Quiz Score", isEarned: true)
        }
    }
    
    func setTrophyEarned(_ name: String, isEarned: Bool) {
        if let index = trophies.firstIndex(where: { $0.name == name }) {
            trophies[index].isEarned = isEarned
            // Save user's earned trophies to UserDefaults or another storage mechanism
            UserDefaults.standard.set(isEarned, forKey: name)
        }
    }
}

