//
//  LevelFeederModel.swift
//  Melodissimo
//
//  Created by Balqis on 28/10/23.
//

import Foundation

struct LevelFeederModel {
    let notationQuizLevels: [LevelModel] = {
        var generatedLevels: [LevelModel] = []
        var idMappings: [String: Int] = [
            "4.": 1,
            "5.": 2,
            "6.": 3,
            "7.": 4,
            "1": 5,
            "2": 6,
            "3": 7,
            "4": 8,
            "5": 9,
            "6": 10,
            "7": 11,
            "1˙": 12,
            "2˙": 13,
            "3˙": 14,
            "4˙": 15,
            "5˙": 16,
            "6˙": 17,
            "7˙": 18,
            "1˙˙": 19,
            "4.#": 20,
            "5.#": 21,
            "6.#": 22,
            "1#": 23,
            "2#": 24,
            "4#": 25,
            "5#": 26,
            "6#": 27,
            "1˙#": 28,
            "2˙#": 29,
            "4˙#": 30,
            "5˙#": 31,
            "6˙#": 32
        ]
        
        // Use UserDefaults to store and retrieve questions for each level
        let userDefaults = UserDefaults.standard
        
        for levelNo in 1...100 {
            let levelKey = "Level\(levelNo)"
            var randomQuestions: [String]
            
            if let storedQuestions = userDefaults.stringArray(forKey: levelKey) {
                // Retrieve the stored questions for this level
                randomQuestions = storedQuestions
            } else {
                let questionSetSize: Int
                if levelNo <= 5 {
                    questionSetSize = 1
                } else if levelNo <= 10 {
                    questionSetSize = 2
                } else if levelNo <= 15 {
                    questionSetSize = 3
                } else if levelNo <= 20 {
                    questionSetSize = 4
                } else if levelNo <= 25 {
                    questionSetSize = 5
                } else if levelNo <= 30 {
                    questionSetSize = 6
                } else if levelNo <= 35 {
                    questionSetSize = 7
                } else if levelNo <= 40 {
                    questionSetSize = 8
                } else if levelNo <= 50 {
                    questionSetSize = 9
                } else if levelNo <= 55 {
                    questionSetSize = 10
                } else if levelNo <= 60 {
                    questionSetSize = 11
                } else if levelNo <= 65 {
                    questionSetSize = 12
                } else if levelNo <= 70 {
                    questionSetSize = 13
                } else if levelNo <= 75 {
                    questionSetSize = 14
                } else if levelNo <= 80 {
                    questionSetSize = 15
                } else if levelNo <= 85 {
                    questionSetSize = 16
                } else if levelNo <= 90 {
                    questionSetSize = 17
                } else if levelNo <= 95 {
                    questionSetSize = 18
                } else {
                    questionSetSize = 19
                }
                
                randomQuestions = []
                
                for _ in 1...questionSetSize {
                    let randomId = idMappings.randomElement()!
                    randomQuestions.append(randomId.key)
                }
                
                // Store the generated questions in UserDefaults
                userDefaults.set(randomQuestions, forKey: levelKey)
            }
            
            let level = LevelModel(
                levelCategory: "notation",
                levelNo: levelNo,
                question: randomQuestions,
                answer: randomQuestions.map { idMappings[$0]! }
            )
            generatedLevels.append(level)
        }
        
        return generatedLevels
    }()
    
    let preplayLevel = LevelModel(
        levelCategory: "preplay",
        levelNo: 1,
        question: ["5.",
                   "4˙",],
        answer: [2, 1]
    )
    
    var levels: [LevelModel] = []
    
    init() {
        levels.append(contentsOf: notationQuizLevels)
        levels.append(preplayLevel)
    }
}
