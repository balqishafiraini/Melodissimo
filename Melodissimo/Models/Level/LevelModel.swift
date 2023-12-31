//
//  LevelModel.swift
//  Melodissimo
//
//  Created by Balqis on 28/10/23.
//

import Foundation

struct LevelModel: Identifiable, Hashable {
    let id = UUID()
    var levelCategory: String
    var levelNo: Int
    var question: [String]
    var answer: [Int]
    var songTitle: String?
    var songNotImg: String?
}

