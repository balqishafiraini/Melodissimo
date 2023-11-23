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
    
    func getStringRepresentation(for answer: Int) -> String {
            switch answer {
            case 1: return "4."
            case 2: return "5."
            case 3: return "6."
            case 4: return "7."
            case 5: return "1"
            case 6: return "2"
            case 7: return "3"
            case 8: return "4"
            case 9: return "5"
            case 10: return "6"
            case 11: return "7"
            case 12: return "1˙"
            case 13: return "2˙"
            case 14: return "3˙"
            case 15: return "4˙"
            case 16: return "5˙"
            case 17: return "6˙"
            case 18: return "7˙"
            case 19: return "1˙˙"
            case 20: return "4.#"
            case 21: return "5.#"
            case 22: return "6.#"
            case 23: return "1#"
            case 24: return "2#"
            case 25: return "4#"
            case 26: return "5#"
            case 27: return "6#"
            case 28: return "1˙#"
            case 29: return "2˙#"
            case 30: return "4˙#"
            case 31: return "5˙#"
            case 32: return "6˙#"
            default: return ""
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
