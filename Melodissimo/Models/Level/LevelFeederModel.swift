//
//  LevelFeederModel.swift
//  Melodissimo
//
//  Created by Balqis on 28/10/23.
//

import Foundation

struct LevelFeederModel {
    let levels = [
        LevelModel(
            levelCategory: "preplay",
            levelNo: 1,
            question: ["5.",
                       "4˙",],
            answer: [2, 1]
        ),
        
        LevelModel(
            levelCategory: "notation",
            levelNo: 1,
            question: ["1",
                       "2",],
            answer: [2, 1]
        ),
        LevelModel(
            levelCategory: "notation",
            levelNo: 2,
            question: ["1",
                       "2",],
            answer: [2, 1]
        ),
        
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["10",
                       "5",],
            answer: [2, 1],
            songTitle: "Indonesia Raya",
            songNotImg: "indonesiaRaya"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["10",
                       "5",],
            answer: [2, 1],
            songTitle: "Gugur Bunga",
            songNotImg: "gugurBunga"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["10",
                       "5",],
            answer: [2, 1],
            songTitle: "Ibu Kita Kartini",
            songNotImg: "ibuKitaKartini"
        ),
        LevelModel(
            levelCategory: "song",
            levelNo: 1,
            question: ["10",
                       "5",],
            answer: [2, 1],
            songTitle: "Mengheningkan Cipta",
            songNotImg: "mengheningkanCipta"
        ),
        
        LevelModel(
            levelCategory: "postplay",
            levelNo: 1,
            question: ["1",
                       "2",],
            answer: [2, 1]
        ),
    ]
}
