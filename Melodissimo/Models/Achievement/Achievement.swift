//
//  Achievement.swift
//  Melodissimo
//
//  A single badge the player can earn.
//

import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    var isEarned: Bool
}
