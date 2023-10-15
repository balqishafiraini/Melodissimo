//
//  FontExtension.swift
//  Melodissimo
//
//  Created by Balqis on 14/10/23.
//

import Foundation
import SwiftUI

extension Font {
    
    /// Create a font with the large title text style.
    public static var largeTitle: Font {
        return Font.custom("BalooDa-Regular", size: 50)
    }

    /// Create a font with the title text style.
    public static var title: Font {
        return Font.custom("BalooDa-Regular", size: 40)
    }

    /// Create a font with the headline text style.
    public static var headline: Font {
        return Font.custom("BalooDa-Regular", size: 30)
    }

    /// Create a font with the subheadline text style.
    public static var subheadline: Font {
        return Font.custom("BalooDa-Regular", size: 20)
    }

    /// Create a font with the body text style.
    public static var body: Font {
           return Font.custom("BalooDa-Regular", size: 15)
       }

    /// Create a font with the callout text style.
    public static var callout: Font {
           return Font.custom("BalooDa-Regular", size: UIFont.preferredFont(forTextStyle: .callout).pointSize)
       }

    /// Create a font with the footnote text style.
    public static var footnote: Font {
           return Font.custom("BalooDa-Regular", size: UIFont.preferredFont(forTextStyle: .footnote).pointSize)
       }

    /// Create a font with the caption text style.
    public static var caption: Font {
           return Font.custom("BalooDa-Regular", size: UIFont.preferredFont(forTextStyle: .caption1).pointSize)
       }

    public static func system(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let font = "BalooDa-Regular"
//        switch weight {
//        case .bold: font = "OpenSans-Bold"
//        case .heavy: font = "OpenSans-ExtraBold"
//        case .light: font = "OpenSans-Light"
//        case .medium: font = "OpenSans-Regular"
//        case .semibold: font = "OpenSans-SemiBold"
//        case .thin: font = "OpenSans-Light"
//        case .ultraLight: font = "OpenSans-Light"
//        default: break
//        }
        return Font.custom(font, size: size)
    }
}
