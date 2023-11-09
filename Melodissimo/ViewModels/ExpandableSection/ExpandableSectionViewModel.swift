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
                        .padding()
                        .font(.title)
                        .padding(.horizontal)
                        .foregroundColor(.black)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title)
                        .foregroundColor(.black)
                }
            }
            .padding()
            .frame(width: UIScreen.main.bounds.width, height: 100, alignment: .leading)
            .background(Color.white)
            
            if isExpanded {
                VStack(alignment: .leading) {
                    ForEach(data.items.indices, id: \.self) { index in
                        let item = data.items[index]
                        switch item {
                        case .text(let text):
                            if text.contains("@") {
                                Link(destination: URL(string: "mailto:\(text)")!) {
                                    Text(text)
                                        .font(Font.subheadline)
                                        .foregroundColor(Color.darkGreen)
                                }
                            } else {
                                Text(text)
                                    .font(Font.subheadline)
                            }
                        case .image(let imageName):
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        }
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
                .padding()
                .frame(width: UIScreen.main.bounds.width, alignment: .leading)
                .background(Color.white)
            }
        }
        .frame(width: UIScreen.main.bounds.width-50)
        .background(Color.white)
        .cornerRadius(30)
        .padding()
    }
}
