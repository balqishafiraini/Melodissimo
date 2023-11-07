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
    
    @Published var score: Int = 0
    
    
    func addAnswer(_ id: Int) {
        answers.append(id)
        //        print("ViewModel answers now: \(answers)")
        if currentQuestionIndex+1 < currentLevel?.question.count ?? 0 {
            currentQuestionIndex += 1
        } else {
            canNavigateToAfterQuizPage = true
            calculateScore()
        }
    }
    
    func checkAnswer() {
        if answers == currentLevel?.answer {
            print("Answer correct!")
        } else {
            print("Answer incorrect!")
        }
    }
    
    func calculateScore() {
        var totalCorrectAnswer = 0
        
        for index in 0..<answers.count {
            if answers[index] == currentLevel?.answer[index] {
                totalCorrectAnswer += 1
            }
        }
        let floatScore = Float(totalCorrectAnswer) / Float(currentLevel?.answer.count ?? 1) * 100
        score = Int(floatScore)
    }
    
    func resetAll() {
        answers.removeAll()
        currentQuestionIndex = 0
        canNavigateToAfterQuizPage = false
    }
    
    func getLevel(currentLevelNo: Int, currentLevelCat: String) {
        //cara 1
        currentLevel = LevelFeederModel().levels.first(where: {$0.levelNo == currentLevelNo && $0.levelCategory == currentLevelCat})
        
        //        print("Current Level: \(String(describing: currentLevel))")
        
        resetAll()
    }
    
    func getSongTitle(songTitle: String) {
        let unwrappedSongTitle = songTitle 
        currentLevel = LevelFeederModel().levels.first(where: { $0.songTitle == unwrappedSongTitle })
        print("Song Title: \(unwrappedSongTitle)")
        resetAll()
    }
}
