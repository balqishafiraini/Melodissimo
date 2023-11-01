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
            answer: [2, 1]),
        LevelModel(
            levelCategory: "quiz",
            levelNo: 1,
            question: ["1",
                       "2",],
            answer: [2, 1]),
    ]
}
