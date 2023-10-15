//
//  ColorExtension.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import Foundation
import SwiftUI

extension Color {
    static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
            return UIColor(red: red/255, green: green/255, blue: blue/255, alpha: 1)
        }
        
    static let darkGreen = Color("darkGreen")
    static let green = Color("green")
    static let navy = Color("navy")
    static let red = Color("red")
    static let softBlue = Color("softBlue")
    static let softGreen = Color("softGreen")
    static let yellow = Color("yellow")
    
}
