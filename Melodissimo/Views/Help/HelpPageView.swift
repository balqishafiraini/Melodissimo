//
//  HelpPageView.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import SwiftUI

import SwiftUI

struct HelpPageView: View {
    @State private var isExpanded: [Bool]
    
    var sections = [
        ExpandableSectionData(title: "How to play quiz feature?", items: [
            .text("You'll see You'll see You'll see You'll see You'll seeYou'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see You'll see "),
        ]),
        ExpandableSectionData(title: "Why my tiles won’t make sound?", items: [
            .text("Here are the steps to make a creamy cheesecake:"),
        ]),
        ExpandableSectionData(title: "Can  I pressed more than one tiles?", items: [
            .text("Here are the steps to make a creamy cheesecake:"),
        ]),
        ExpandableSectionData(title: "If I move to another iPad, will my progress saved?", items: [
            .text("Here are the steps to make a creamy cheesecake:"),
        ]),
        ExpandableSectionData(title: "Contact us for further assist!", items: [
            .text("Email us on:"),
            .text("appmelodissimo@gmail.com"),
        ])
    ]
    
    init() {
            _isExpanded = State(initialValue: Array(repeating: false, count: sections.count))
        }
    
    @State var isPresenting = false
    @State var isPresentingHelp = false
    @Environment(\.dismiss) var dismiss
    
    
    var body: some View {
        
        ZStack{
            Rectangle()
                .fill(Color.softBlue)
                .scaledToFill()
            
            Image("bgMusic")
                .scaledToFit()
            VStack {
                HStack{
                    Button {
                        dismiss()
                    } label: {
                        Text("< Back")
                            .frame(width: 120, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    
                    Spacer()
                    
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<sections.count, id: \.self) { index in
                            let section = sections[index]
                            ExpandableSectionView(data: section, isExpanded: $isExpanded[index])
                        }
                    }
                    .padding()
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .topLeading)
            
        }
        
    }
}

