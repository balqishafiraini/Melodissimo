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

    // Gameplay state for combo + lives (Fase 2).
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var lives: Int = 3

    let maxLives = 3

    /// Lives only end the round early for notation levels; songs play to the end.
    private var livesEnabled: Bool {
        currentLevel?.levelCategory == "notation"
    }

    func addAnswer(_ id: Int) {
        let hasExpected = currentLevel?.answer.indices.contains(currentQuestionIndex) ?? false
        let expected = hasExpected ? currentLevel?.answer[currentQuestionIndex] : nil
        let isCorrect = expected != nil && id == expected

        if isCorrect {
            combo += 1
            if combo > maxCombo { maxCombo = combo }
        } else {
            combo = 0
            if livesEnabled { lives = max(0, lives - 1) }
        }

        answers.append(id)

        // Out of lives → end the round immediately (notation gameplay).
        if livesEnabled && lives <= 0 {
            finishQuiz()
            return
        }

        if currentQuestionIndex+1 < currentLevel?.question.count ?? 0 {
            currentQuestionIndex += 1
        } else {
            finishQuiz()
        }
    }

    private func finishQuiz() {
        calculateScore()
        ProgressStore.shared.recordCombo(maxCombo)
        ProgressStore.shared.registerPlayToday()
        AchievementStore.shared.evaluate()
        canNavigateToAfterQuizPage = true
    }
    
    func getStringRepresentation(for answer: Int) -> String {
        NoteCatalog.all.first(where: { $0.id == answer })?.label ?? ""
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

        // Persist the best score for notation levels so the level menu can show stars.
        if let level = currentLevel, level.levelCategory == "notation" {
            ProgressStore.shared.recordScore(category: "notation", level: level.levelNo, score: score)
        }
    }
    
    func resetAll() {
        answers.removeAll()
        currentQuestionIndex = 0
        canNavigateToAfterQuizPage = false
        combo = 0
        maxCombo = 0
        lives = maxLives
    }
    
    func getLevel(currentLevelNo: Int, currentLevelCat: String) {
        //cara 1
        currentLevel = LevelFeederModel.shared.levels.first(where: {$0.levelNo == currentLevelNo && $0.levelCategory == currentLevelCat})
        
        //        print("Current Level: \(String(describing: currentLevel))")
        
        resetAll()
    }
    
    func getSongTitle(songTitle: String) {
        let unwrappedSongTitle = songTitle 
        currentLevel = LevelFeederModel.shared.levels.first(where: { $0.songTitle == unwrappedSongTitle })
        print("Song Title: \(unwrappedSongTitle)")
        resetAll()
    }
}
