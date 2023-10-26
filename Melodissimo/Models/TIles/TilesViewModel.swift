//
//  TilesViewModel.swift
//  Melodissimo
//
//  Created by Balqis on 28/10/23.
//

import Foundation

class TilesViewModel: ObservableObject {
    
    var currentLevel: LevelModel?
    
    @Published var answers: [Int] = []
    
    func addAnswer(_ id: Int) {
        answers.append(id)
        print("ViewModel answers now: \(answers)")
    }
    
    func checkAnswer() {
        if answers == currentLevel?.answer {
            print("Answer correct!")
        } else {
            print("Answer incorrect!")
        }
    }
    
    func resetAnswer() {
        answers.removeAll()
        print("Answer list is reset")
    }
    
    func getLevel(currentLevelNo: Int, currentLevelCat: String) {
        //cara 1
        currentLevel = LevelFeederModel().levels.first(where: {$0.levelNo == currentLevelNo && $0.levelCategory == currentLevelCat})
        print("Current Level: \(String(describing: currentLevel))")
    }
}
