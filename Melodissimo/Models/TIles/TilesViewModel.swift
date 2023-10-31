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
    @Published var currentQuestionIndex: Int = 0
    @Published var canNavigateToAfterQuizPage = false
    
    func addAnswer(_ id: Int) {
        answers.append(id)
        print("ViewModel answers now: \(answers)")
        if currentQuestionIndex+1 < currentLevel?.question.count ?? 0 {
            currentQuestionIndex += 1
        } else {
            canNavigateToAfterQuizPage = true
        }
    }
    
    func checkAnswer() {
        if answers == currentLevel?.answer {
            print("Answer correct!")
        } else {
            print("Answer incorrect!")
        }
    }
    
    func resetAll() {
        answers.removeAll()
        currentQuestionIndex = 0
        canNavigateToAfterQuizPage = false
    }
    
    func getLevel(currentLevelNo: Int, currentLevelCat: String) {
        //cara 1
        currentLevel = LevelFeederModel().levels.first(where: {$0.levelNo == currentLevelNo && $0.levelCategory == currentLevelCat})
        print("Current Level: \(String(describing: currentLevel))")
        
        resetAll()
    }
}
