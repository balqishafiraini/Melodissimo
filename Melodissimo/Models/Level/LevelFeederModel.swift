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
    
    let preplayLevel: LevelModel = {
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
            "1˙˙": 19
        ]
        
        // Define the key for the postplay level
        let levelKey = "PreplayLevel"
        
        var randomQuestions: [String]
        let questionSetSize = 10
        
        randomQuestions = []
        
        for _ in 1...questionSetSize {
            let randomId = idMappings.randomElement()!
            randomQuestions.append(randomId.key)
        }
        
        
        // Create the LevelModel for postplayLevel
        return LevelModel(
            levelCategory: "preplay",
            levelNo: 1,
            question: randomQuestions,
            answer: randomQuestions.map { idMappings[$0]! }
        )
    }()
    
    
    let songLevel = [
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question:  ["5", "5", "3", "1", "2", "3", "2", "1", "1", "3", "5", "5", "6", "6", "6", "6", "5", "5", "5", "6", "5", "4", "3", "2", "1", "7", "6", "6", "6", "5", "7", "2", "4", "4", "3", "5", "5", "2", "2", "2", "2", "3", "2", "1", "1", "1", "1", "5", "5", "2", "2", "2", "2", "3", "4", "5", "5", "3", "2", "1", "7", "1", "3", "6", "5", "1", "2", "3", "3", "5", "4", "3", "2", "1"],
            answer:  [9, 9, 7, 5, 6, 7, 6, 5, 5, 7, 9, 9, 10, 10, 10, 10, 9, 9, 9, 10, 9, 8, 7, 6, 5, 11, 10, 10, 10, 9, 11, 6, 8, 8, 7, 9, 9, 6, 6, 6, 6, 7, 6, 5, 5, 5, 5, 9, 9, 6, 6, 6, 6, 7, 8, 9, 9, 7, 6, 5, 11, 5, 7, 10, 9, 5, 6, 7, 7, 9, 8, 7, 6, 5],
            songTitle: "Berkibarlah Benderaku",
            songNotImg: "berkibarlahBenderaku"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question:  ["5.", "5.", "1", "1", "1", "3", "5", "3", "1", "3", "1", "5.", "4", "3", "2", "1", "1", "2", "3", "3", "3", "2", "4", "3", "1", "6.", "6.", "6.", "2", "1", "7.", "6.", "5.", "5.", "5.", "2", "2", "2", "3", "2", "7.", "5.", "5.", "5.", "3", "3", "3", "2", "4", "3", "3", "4", "5", "4", "6.", "7.", "2", "1", "5.", "1", "3", "5", "4", "4", "3", "2", "1"],
            answer: [2, 2, 5, 5, 5, 7, 9, 7, 5, 7, 5, 2, 8, 7, 6, 5, 5, 6, 7, 7, 7, 6, 8, 7, 5, 3, 3, 3, 6, 5, 4, 3, 2, 2, 2, 6, 6, 6, 7, 6, 4, 2, 2, 2, 7, 7, 7, 6, 8, 7, 7, 8, 9, 8, 3, 4, 6, 5, 2, 5, 7, 9, 8, 8, 7, 6, 5],
            songTitle: "Dari Sabang Sampai Merauke",
            songNotImg: "dariSabangSampaiMerauke"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "5.", "1", "1", "2", "2", "3", "3", "5", "1", "2", "3", "4", "2", "5.", "5.", "2", "2", "3", "3", "4", "3", "2", "1", "5.", "5.", "5.", "6.", "7.", "1", "1", "1", "1", "6.", "1", "4", "5", "6", "5", "1", "1", "1", "6.", "1", "4", "5", "6", "5", "1", "1", "1", "6.", "1", "4", "5", "6", "5", "5", "6", "5", "4", "3", "2", "1", "1", "1", "1", "6.", "5.", "1", "1", "1", "1", "2", "3", "1", "1", "6", "5", "7.", "1"],
            answer: [2, 2, 5, 5, 6, 6, 7, 7, 9, 5, 6, 7, 8, 6, 2, 2, 6, 6, 7, 7, 8, 7, 6, 5, 2, 2, 2, 3, 4, 5, 5, 5, 5, 3, 5, 8, 9, 10, 9, 5, 5, 5, 3, 5, 8, 9, 10, 9, 5, 5, 5, 3, 5, 8, 9, 10, 9, 9, 10, 9, 8, 7, 6, 5, 5, 5, 5, 3, 2, 5, 5, 5, 5, 6, 7, 5, 5, 10, 9, 4, 5],
            songTitle: "Garuda Pancasila",
            songNotImg: "garudaPancasila"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "3", "2", "7.", "2", "1", "5.", "6.", "7.", "1", "7.", "6.", "5.", "7.", "5.", "4", "3", "2", "3", "2", "2", "1", "7.", "2", "5", "6", "3", "5.", "3", "2", "7.", "2", "1", "5.", "6.", "7.", "1", "3", "4", "3", "6.", "6.", "7.", "1", "7.", "2", "1", "7.", "6.", "5.", "4.", "5.", "1", "3", "3", "4", "3", "2", "2", "6.", "7.", "1"],
            answer: [2, 7, 6, 4, 6, 5, 2, 3, 4, 5, 4, 3, 2, 4, 2, 8, 7, 6, 7, 6, 6, 5, 4, 6, 9, 10, 7, 2, 7, 6, 4, 6, 5, 2, 3, 4, 5, 7, 8, 7, 3, 3, 4, 5, 4, 6, 5, 4, 3, 2, 1, 2, 5, 7, 7, 8, 7, 6, 6, 3, 4, 5],
            songTitle: "Halo Halo Bandung",
            songNotImg: "haloHaloBandung"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "5.", "5.", "3", "3", "3", "3", "2", "3", "4", "2", "1", "5.", "5.", "5.", "5.", "5", "5", "5", "5", "4", "5", "6", "4", "3", "1", "1", "1", "6", "6", "4", "5", "6", "5", "3", "5.", "5.", "5.", "1", "1", "1", "1", "3", "3", "2", "1", "2", "5", "4", "2", "3", "3", "3", "3", "2", "3", "4", "2", "1", "1˙", "5", "6", "4", "3", "3", "3", "3", "2", "3", "4", "2", "1", "5.", "6.", "7.", "1", "5.", "2", "5.", "3", "2", "4", "3", "5", "1˙", "5", "4", "3", "5", "1˙", "5", "4", "3", "2", "4", "3", "2", "5.", "6.", "7.", "1", "5.", "2", "5.", "3", "2", "4", "3", "5", "1˙", "5", "4", "3", "2", "1"],
            answer: [2, 2, 2, 7, 7, 7, 7, 6, 7, 8, 6, 5, 2, 2, 2, 2, 9, 9, 9, 9, 8, 9, 10, 8, 7, 5, 5, 5, 10, 10, 8, 9, 10, 9, 7, 2, 2, 2, 5, 5, 5, 5, 7, 7, 6, 5, 6, 9, 8, 6, 7, 7, 7, 7, 6, 7, 8, 6, 5, 12, 9, 10, 8, 7, 7, 7, 7, 6, 7, 8, 6, 5, 2, 3, 4, 5, 2, 6, 2, 7, 6, 8, 7, 9, 12, 9, 8, 7, 9, 12, 9, 8, 7, 6, 8, 7, 6, 2, 3, 4, 5, 2, 6, 2, 7, 6, 8, 7, 9, 12, 9, 8, 7, 6, 5],
            songTitle: "Hari Merdeka",
            songNotImg: "hariMerdeka"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "1˙", "5", "5", "4", "4", "3", "3", "3", "4", "3", "2", "1", "2", "3", "4", "5", "5", "5", "4", "3", "6", "7", "1˙", "6", "5", "4", "3", "4", "2", "1", "1", "2", "2", "3", "4", "5", "3", "3", "4", "5", "1", "2", "2", "4", "6", "5", "1", "2", "2", "3", "4", "5", "3", "3", "4", "5", "5", "4#", "6", "2˙", "1˙", "7", "5", "1˙", "5", "5", "4", "4", "3", "3", "3", "4", "3", "2", "1", "2", "3", "4", "5", "5", "5", "4", "3", "6", "7", "1˙", "6", "5", "4", "4", "5", "3", "3", "4", "5", "5", "5", "4", "3", "6", "7", "1˙", "6", "5", "4", "3", "4", "1"],
            answer: [9, 12, 9, 9, 8, 8, 7, 7, 7, 8, 7, 6, 5, 6, 7, 8, 9, 9, 9, 8, 7, 10, 11, 12, 10, 9, 8, 7, 8, 6, 5, 5, 6, 6, 7, 8, 9, 7, 7, 8, 9, 5, 6, 6, 8, 10, 9, 5, 6, 6, 7, 8, 9, 7, 7, 8, 9, 9, 25, 10, 13, 12, 11, 9, 12, 9, 9, 8, 8, 7, 7, 7, 8, 7, 6, 5, 6, 7, 8, 9, 9, 9, 8, 7, 10, 11, 12, 10, 9, 8, 8, 9, 7, 7, 8, 9, 9, 9, 8, 7, 10, 11, 12, 10, 9, 8, 7, 8, 5],
            songTitle: "Hymne Guru",
            songNotImg: "hymneGuru"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["1", "2", "3", "4", "5", "3", "1", "6", "1˙", "7", "6", "5", "4", "6", "5", "4", "3", "1", "2", "4", "3", "2", "1", "4", "3", "4", "6", "5", "6", "5", "3", "1", "3", "2", "3", "4", "5", "3", "4", "3", "4", "6", "5", "6", "5", "3", "1", "3", "2", "4", "7.", "2", "1"],
            answer: [5, 6, 7, 8, 9, 7, 5, 10, 12, 11, 10, 9, 8, 10, 9, 8, 7, 5, 6, 8, 7, 6, 5, 8, 7, 8, 10, 9, 10, 9, 7, 5, 7, 6, 7, 8, 9, 7, 8, 7, 8, 10, 9, 10, 9, 7, 5, 7, 6, 8, 4, 6, 5],
            songTitle: "Ibu Kita Kartini",
            songNotImg: "ibuKitaKartini"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "5", "6", "5", "3", "1", "1", "6.", "5.", "1", "3", "1", "5", "3", "2", "5", "5", "6", "5", "3", "1", "1", "6.", "5.", "1", "3", "2", "1", "7.", "1", "2", "2", "2", "3", "4", "2", "3", "4", "5", "6", "6", "5", "3", "4", "3", "2", "5", "5", "6", "5", "3", "1", "1", "6.", "5.", "1", "3", "2", "1", "7.", "1"],
            answer: [9, 9, 10, 9, 7, 5, 5, 3, 2, 5, 7, 5, 9, 7, 6, 9, 9, 10, 9, 7, 5, 5, 3, 2, 5, 7, 6, 5, 4, 5, 6, 6, 6, 7, 8, 6, 7, 8, 9, 10, 10, 9, 7, 8, 7, 6, 9, 9, 10, 9, 7, 5, 5, 3, 2, 5, 7, 6, 5, 4, 5],
            songTitle: "Ibu Pertiwi",
            songNotImg: "ibuPertiwi"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "1", "3", "1", "5.", "1", "3", "6", "5", "3", "1", "1", "1", "7.", "1", "7.", "1", "3", "2", "5.", "1", "3", "1", "5.", "1", "7.", "7.", "6.", "4", "2", "7.", "1", "5", "4#", "5", "4", "7.", "1", "5", "5", "5", "6", "5", "4", "2", "7.", "5.", "3", "3", "3", "4", "3", "2", "1", "7.", "6.", "6.", "7.", "1", "7.", "1", "2", "3", "4", "6", "5", "5.", "1", "3", "5", "4#", "5", "4", "7.", "1"],
            answer:  [2, 5, 7, 5, 2, 5, 7, 10, 9, 7, 5, 5, 5, 4, 5, 4, 5, 7, 6, 2, 5, 7, 5, 2, 5, 4, 4, 3, 8, 6, 4, 5, 9, 25, 9, 8, 4, 5, 9, 9, 9, 10, 9, 8, 6, 4, 2, 7, 7, 7, 8, 7, 6, 5, 4, 3, 3, 4, 5, 4, 5, 6, 7, 8, 10, 9, 2, 5, 7, 9, 25, 9, 8, 4, 5],
            songTitle: "Indonesia Pusaka",
            songNotImg: "indonesiaPusaka"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["3", "4", "5", "3˙", "3˙", "2˙", "2˙", "1˙", "5", "5", "5", "6", "5", "4", "3", "2", "2", "3", "4", "2˙", "2˙", "1˙", "1˙", "7", "6", "5", "5", "7", "6", "5", "4", "3", "3", "4", "5", "3˙", "3˙", "2˙", "2˙", "1˙", "5", "5", "5", "6", "5", "1˙", "2˙", "7", "6", "6", "6", "4˙", "4˙", "3˙", "2˙", "5", "1˙", "7", "6", "5", "4˙", "3˙", "2˙", "1˙", "5", "5", "6", "4˙", "4˙", "4˙", "4˙", "4˙", "3", "1˙", "1˙", "1˙", "7", "1˙", "2˙", "5˙", "5˙", "5˙", "4˙", "4˙", "3˙", "1˙", "5", "5", "6", "4˙", "4˙", "4˙", "4˙", "4˙", "3", "1˙", "1˙", "1˙", "7", "1˙", "2˙", "5˙", "5˙", "3˙", "2˙", "1˙", "1˙", "1˙", "4˙", "6˙", "6˙", "6˙", "6˙", "6˙", "5˙", "3˙", "3˙", "4˙", "2˙", "2˙", "5˙", "4˙", "3˙", "1˙", "1˙", "1˙", "4", "6˙", "6˙", "6˙", "6˙", "6˙", "5˙", "3˙", "3˙", "3˙", "5˙", "5˙", "5˙", "4˙", "3˙", "2˙", "3˙", "2˙", "1˙", "1˙", "1˙", "1˙"],
            answer: [7, 8, 9, 14, 14, 13, 13, 12, 9, 9, 9, 10, 9, 8, 7, 6, 6, 7, 8, 13, 13, 12, 12, 11, 10, 9, 9, 11, 10, 9, 8, 7, 7, 8, 9, 14, 14, 13, 13, 12, 9, 9, 9, 10, 9, 12, 13, 11, 10, 10, 10, 15, 15, 14, 13, 9, 12, 11, 10, 9, 15, 14, 13, 12, 9, 9, 10, 15, 15, 15, 15, 15, 7, 12, 12, 12, 11, 12, 13, 16, 16, 16, 15, 15, 14, 12, 9, 9, 10, 15, 15, 15, 15, 15, 7, 12, 12, 12, 11, 12, 13, 16, 16, 14, 13, 12, 12, 12, 15, 17, 17, 17, 17, 17, 16, 14, 14, 15, 13, 13, 16, 15, 14, 12, 12, 12, 8, 17, 17, 17, 17, 17, 16, 14, 14, 14, 16, 16, 16, 15, 14, 13, 14, 13, 12, 12, 12, 12],
            songTitle: "Indonesia Raya",
            songNotImg: "indonesiaRaya"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "5.", "1", "1", "1", "2", "3", "1", "7.", "1", "2", "4", "3", "2", "1", "5.", "5.", "1", "1", "1", "2", "3", "1", "7.", "1", "2", "4", "3", "2", "1", "3", "4", "5", "5", "6", "6", "5", "3", "4", "5", "5", "6", "6", "5", "2", "3", "4", "4", "5", "5", "3", "1", "7.", "1", "2", "4", "3", "2", "1", "3", "4", "5", "5", "6", "6", "5", "3", "4", "5", "5", "6", "6", "5", "2", "3", "4", "4", "5", "5", "3", "1", "7.", "1", "2", "4", "3", "2", "1"],
            answer:  [2, 2, 5, 5, 5, 6, 7, 5, 4, 5, 6, 8, 7, 6, 5, 2, 2, 5, 5, 5, 6, 7, 5, 4, 5, 6, 8, 7, 6, 5, 7, 8, 9, 9, 10, 10, 9, 7, 8, 9, 9, 10, 10, 9, 6, 7, 8, 8, 9, 9, 7, 5, 4, 5, 6, 8, 7, 6, 5, 7, 8, 9, 9, 10, 10, 9, 7, 8, 9, 9, 10, 10, 9, 6, 7, 8, 8, 9, 9, 7, 5, 4, 5, 6, 8, 7, 6, 5],
            songTitle: "Indonesia Tetap Merdeka",
            songNotImg: "indonesiaTetapMerdeka"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "5", "3", "5", "1˙", "3˙", "2˙", "1˙", "2˙", "1˙", "6", "5", "4", "2", "4", "5", "7", "7", "2˙", "1˙", "7", "1˙", "2˙", "5", "3", "5", "1˙", "3˙", "2˙", "1˙", "2˙", "1˙", "6", "5", "4", "2", "4", "5", "7", "7", "2˙", "4˙", "3˙", "2˙", "1˙", "1˙", "7", "6", "4˙", "4˙", "4˙", "3˙", "2˙", "1˙", "3˙", "3˙", "3˙", "2˙", "1˙", "7", "7", "1˙", "2˙", "4˙", "3˙", "1˙", "7", "6", "4˙", "4˙", "4˙", "3˙", "2˙", "1˙", "3˙", "3˙", "3˙", "2˙", "1˙", "7", "7", "1˙", "2˙", "3˙", "1˙"],
            answer:  [9, 9, 7, 9, 12, 14, 13, 12, 13, 12, 10, 9, 8, 6, 8, 9, 11, 11, 13, 12, 11, 12, 13, 9, 7, 9, 12, 14, 13, 12, 13, 12, 10, 9, 8, 6, 8, 9, 11, 11, 13, 15, 14, 13, 12, 12, 11, 10, 15, 15, 15, 14, 13, 12, 14, 14, 14, 13, 12, 11, 11, 12, 13, 15, 14, 12, 11, 10, 15, 15, 15, 14, 13, 12, 14, 14, 14, 13, 12, 11, 11, 12, 13, 14, 12],
            songTitle: "Maju Tak Gentar",
            songNotImg: "majuTakGentar"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "3", "4", "5", "5", "3", "1˙", "1˙", "7", "1˙", "6", "5", "3", "5", "4", "3", "2", "1", "2", "5", "3", "4", "5", "5", "3", "1˙", "1˙", "7", "1˙", "6", "5", "3", "4", "3", "2", "1", "2", "1", "1", "2", "3", "1", "5", "3", "1˙", "6", "6", "5", "4#", "5", "5", "1˙", "5", "2˙", "5", "3˙", "2˙", "1˙", "7", "1˙", "7", "6", "5", "3", "4", "2", "3", "2", "1"],
            answer: [9, 7, 8, 9, 9, 7, 12, 12, 11, 12, 10, 9, 7, 9, 8, 7, 6, 5, 6, 9, 7, 8, 9, 9, 7, 12, 12, 11, 12, 10, 9, 7, 8, 7, 6, 5, 6, 5, 5, 6, 7, 5, 9, 7, 12, 10, 10, 9, 25, 9, 9, 12, 9, 13, 9, 14, 13, 12, 11, 12, 11, 10, 9, 7, 8, 6, 7, 6, 5],
            songTitle: "Mengheningkan Cipta",
            songNotImg: "mengheningkanCipta"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5.", "3", "3", "4", "2", "3", "1", "5.", "5", "4", "3", "4", "5", "6", "5", "5", "6", "6", "6", "6", "5", "4", "3", "1", "1", "2", "3", "1", "1", "7.", "1", "2", "3", "2", "5.", "1", "2", "3", "4", "5", "3", "3", "5", "4", "3", "2", "1"],
            answer:  [2, 7, 7, 8, 6, 7, 5, 2, 9, 8, 7, 8, 9, 10, 9, 9, 10, 10, 10, 10, 9, 8, 7, 5, 5, 6, 7, 5, 5, 4, 5, 6, 7, 6, 2, 5, 6, 7, 8, 9, 7, 7, 9, 8, 7, 6, 5],
            songTitle: "Merah Putih",
            songNotImg: "merahPutih"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question:  ["5", "5", "5", "5", "3", "4", "5", "6", "5", "1˙", "1˙", "1˙", "1˙", "1˙", "7", "6", "7", "5", "4", "4", "4", "4", "4", "2", "3", "4", "5", "4", "4", "7", "7", "7", "7", "6", "1˙", "7", "6", "5", "5", "5", "5", "5", "3", "4", "5", "6", "5", "5", "1˙", "1˙", "1˙", "1˙", "1˙", "7", "1˙", "2˙", "6", "6", "6", "6", "6", "6", "6", "7", "6", "1˙", "3", "5", "1˙", "7", "1˙", "2˙", "7", "1˙", "3", "5", "1˙", "3", "5", "4", "5", "2˙", "2˙", "2˙", "1˙", "3˙", "3", "5", "4", "5", "7", "4", "5", "3", "5", "1˙", "3", "5", "4", "5", "2˙", "2˙", "6", "7", "1˙"],
            answer: [9, 9, 9, 9, 7, 8, 9, 10, 9, 12, 12, 12, 12, 12, 11, 10, 11, 9, 8, 8, 8, 8, 8, 6, 7, 8, 9, 8, 8, 11, 11, 11, 11, 10, 12, 11, 10, 9, 9, 9, 9, 9, 7, 8, 9, 10, 9, 9, 12, 12, 12, 12, 12, 11, 12, 13, 10, 10, 10, 10, 10, 10, 10, 11, 10, 12, 7, 9, 12, 11, 12, 13, 11, 12, 7, 9, 12, 7, 9, 8, 9, 13, 13, 13, 12, 14, 7, 9, 8, 9, 11, 8, 9, 7, 9, 12, 7, 9, 8, 9, 13, 13, 10, 11, 12],
            songTitle: "Rayuan Pulau Kelapa",
            songNotImg: "rayuanPulauKelapa"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "5", "6", "3", "1˙", "1˙", "2˙", "6", "5", "1˙", "3˙", "1˙", "2˙", "3˙", "2˙", "5", "5", "6", "3", "1˙", "1˙", "2˙", "6", "5", "1˙", "3˙", "1˙", "2˙", "7", "1˙", "2˙", "3˙", "2˙", "1˙", "7", "6", "5", "4˙", "4˙", "3˙", "3˙", "4˙", "3˙", "2˙", "5", "5", "6", "3", "1˙", "1˙", "2˙", "6", "5", "1˙", "3˙", "1˙", "2˙", "7", "1˙"],
            answer:  [9, 9, 10, 7, 12, 12, 13, 10, 9, 12, 14, 12, 13, 14, 13, 9, 9, 10, 7, 12, 12, 13, 10, 9, 12, 14, 12, 13, 11, 12, 13, 14, 13, 12, 11, 10, 9, 15, 15, 14, 14, 15, 14, 13, 9, 9, 10, 7, 12, 12, 13, 10, 9, 12, 14, 12, 13, 11, 12],
            songTitle: "Satu Nusa Satu Bangsa",
            songNotImg: "satuNusaSatuBangsa"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["5", "3", "4", "5", "1˙", "3˙", "2˙", "1˙", "7", "6", "5", "5", "1˙", "3˙", "2˙", "1˙", "7", "7", "6", "7", "1˙", "1˙", "1˙", "7", "6", "6", "6", "1˙", "7", "6", "5", "3", "4", "5", "7", "6", "6", "2", "3", "4"],
            answer: [9, 7, 8, 9, 12, 14, 13, 12, 11, 10, 9, 9, 12, 14, 13, 12, 11, 11, 10, 11, 12, 12, 12, 11, 10, 10, 10, 12, 11, 10, 9, 7, 8, 9, 11, 10, 10, 6, 7, 8],
            songTitle: "Tanah Airku",
            songNotImg: "tanahAirku"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["3", "6", "7", "1˙", "6", "7", "1˙", "7", "5", "3", "4", "4", "5", "6", "5", "4", "3", "3", "2", "2", "2", "2", "6", "4", "3", "4", "3", "2", "1", "3", "6", "6", "6", "6", "1˙", "7", "3", "6", "7", "1˙", "6", "7", "1˙", "7", "5", "3", "4", "4", "5", "6", "5", "4", "3", "3", "2", "2", "2", "2", "6", "4", "3", "4", "3", "2", "1", "3", "6", "7", "1˙", "7", "1˙", "7", "6"],
            answer: [7, 10, 11, 12, 10, 11, 12, 11, 9, 7, 8, 8, 9, 10, 9, 8, 7, 7, 6, 6, 6, 6, 10, 8, 7, 8, 7, 6, 5, 7, 10, 10, 10, 10, 12, 11, 7, 10, 11, 12, 10, 11, 12, 11, 9, 7, 8, 8, 9, 10, 9, 8, 7, 7, 6, 6, 6, 6, 10, 8, 7, 8, 7, 6, 5, 7, 10, 11, 12, 11, 12, 11, 10],
            songTitle: "Terima Kasih Guru",
            songNotImg: "terimakasihGuruku"
        ),
        
    ]
    
    let postplayLevel: LevelModel = {
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
        
        // Define the key for the postplay level
        let levelKey = "PostplayLevel"
        
        var randomQuestions: [String]
        let questionSetSize = 10
        
        randomQuestions = []
        
        for _ in 1...questionSetSize {
            let randomId = idMappings.randomElement()!
            randomQuestions.append(randomId.key)
        }
        
        
        // Create the LevelModel for postplayLevel
        return LevelModel(
            levelCategory: "postplay",
            levelNo: 1,
            question: randomQuestions,
            answer: randomQuestions.map { idMappings[$0]! }
        )
    }()
    
    
    var levels: [LevelModel] = []
    
    init() {
        levels.append(contentsOf: notationQuizLevels)
        levels.append(preplayLevel)
        levels.append(contentsOf: songLevel)
        levels.append(postplayLevel)
        
    }
}
