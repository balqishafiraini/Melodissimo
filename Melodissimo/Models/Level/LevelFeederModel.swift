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
            question: ["Which tiles that belongs to (5.)?",
                       "Which tiles that belongs to (4˙)?",
                       "Which tiles that belongs to (3)?",
                       "Which tiles that belongs to (2˙)?",
                       "Which tiles that belongs to (1˙)?",
                       "Which tiles that belongs to (6˙)?",
                       "Which tiles that belongs to (7˙)?",
                       "Which tiles that belongs to (2)?",
                       "Which tiles that belongs to (5)?",
                       "Which tiles that belongs to (6)?",],
            answer: [2, 15, 6, 8, 9, 3, 10, 1, 13, 5]),
    ]
}
