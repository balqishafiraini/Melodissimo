//
//  ExpandableSectionViewModel.swift
//  Melodissimo
//
//  Created by Balqis on 09/11/23.
//

import Foundation
import SwiftUI

enum SectionItem {
    case text(String)
    case image(String)
}

struct ExpandableSectionData {
    let title: String
    let items: [SectionItem]
}

struct ExpandableSectionView: View {
    let data: ExpandableSectionData
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(data.title)
                        .padding(.all, Sizing.isPhone ? 4 : nil)
                        .font(.title)
                        .padding(.horizontal, Sizing.isPhone ? 4 : nil)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title)
                        .foregroundColor(.black)
                }
            }
            .padding(.all, Sizing.isPhone ? 6 : nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)

            if isExpanded {
                VStack(alignment: .leading) {
                    ForEach(data.items.indices, id: \.self) { index in
                        let item = data.items[index]
                        switch item {
                        case .text(let text):
                                Text(text)
                                    .font(Font.headline)
                            
                        case .image(let imageName):
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: Sizing.s(100))
                        }
                    }
                    .padding(.horizontal, Sizing.s(40))
                    Spacer()
                }
                .padding(.all, Sizing.isPhone ? 8 : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(Sizing.s(30))
        .padding(.all, Sizing.isPhone ? 6 : nil)
    }
}
