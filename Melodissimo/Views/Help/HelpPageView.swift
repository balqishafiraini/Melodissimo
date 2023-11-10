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
        ExpandableSectionData(title: NSLocalizedString("How to play quiz feature?", comment: ""), items: [
            .text(NSLocalizedString("- In the quiz feature,  You must press the tiles that belong to the numeral notation that's shown in the question box.", comment: "")),
            .text(NSLocalizedString("- The questions will appear only ONCE and change automatically once you pressed the answer tiles.", comment: "")),
            .text(NSLocalizedString("- Please make sure your pressed tiles are at least 2 seconds and the color will change to grey.", comment: "")),
            .text(NSLocalizedString("- Remember, you CAN'T undo the answer.", comment: "")),
            .text(NSLocalizedString("- For Song Quiz feature, you must pressed the button SEQUENTIALLY from the numeral notation song from the song you've selected. If you're not sure about what button you've pressed, click 'Reset' button and you must start it all over again.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("Why my tiles won’t make sound?", comment: ""), items: [
            .text(NSLocalizedString("Make sure you've pressed it at least 2 seconds.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("Can I pressed more than one tiles in one time?", comment: ""), items: [
            .text(NSLocalizedString("Unfortunately, you can't do that right now. But we will make sure to update that feature in the future app update. Please stay tune with us.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to read the numeral notation in Song feature?", comment: ""), items: [
            .text(NSLocalizedString("Almost all of the number that shown in numeral notation song is same with the keyboard. However, you'll see some differences, there are:", comment: "")),
            .text(NSLocalizedString("- If you see '0' notation, just ignore it. The 0 notation means is tone beat.", comment: "")),
            .text(NSLocalizedString("- If you see 2 notation number that connected by a wave line above it, only pay attention to the first number, ignore the second number.", comment: "")),
            .text(NSLocalizedString("- If you see the number that has diagona strikethrough, it means # (in major chord). Example: '4̷' means '4#'", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("If I move to another iPad, will my progress saved?", comment: ""), items: [
            .text(NSLocalizedString("Unfortunately, you'll lose your progress because we didn't do any cloud system. But we will make sure to update that feature in the future app update. Please stay tune with us.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("Contact us for further assist!", comment: ""), items: [
            .text(NSLocalizedString("Email us on: appmelodissimo@gmail.com", comment: "")),
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

