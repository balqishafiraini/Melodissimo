//
//  TrophyRepository.swift
//  Melodissimo
//
//  Created by Balqis on 08/11/23.
//

import Foundation
import SwiftUI

class TrophyRepositoryModel: ObservableObject {
    @Published var trophies: [TrophyModel] = []
    
    init() {
        // Initialize with your available trophies
        trophies = LevelFeederModel().levels
            .filter({ $0.levelCategory == "song" })
            .map({ TrophyModel(name: $0.songTitle ?? "", isEarned: false) })
        
        //Get saved value from userDefault and set the trophy isEarned value based on it
        for trophy in trophies {
            if UserDefaults.standard.bool(forKey: trophy.name) {
                setTrophyEarned(trophy.name, isEarned: true)
            }
        }
    }
    
    func setTrophyEarned(_ name: String, isEarned: Bool) {
        if let index = trophies.firstIndex(where: { $0.name == name }) {
            trophies[index].isEarned = isEarned
            // Save user's earned trophies to UserDefaults or another storage mechanism
            UserDefaults.standard.set(isEarned, forKey: name)
        }
    }
    
    func isTrophyEarned(songTitle: String) -> Bool {
        return trophies.filter({ $0.name == songTitle }).first?.isEarned ?? false
    }
}
