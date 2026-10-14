//
//  HelpPageView.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import SwiftUI

struct HelpPageView: View {
    @State private var isExpanded: [Bool]
    
    /// One section per mode, then the common questions. Every string is an English key in `Localizable.strings`.
    var sections = [
        ExpandableSectionData(title: NSLocalizedString("How to play the Nusantara Tour?", comment: ""), items: [
            .text(NSLocalizedString("- Tap Start (or Continue) on Home. The map shows six islands, from Sumatra to Maluku and Papua.", comment: "")),
            .text(NSLocalizedString("- Tap a stage to play it. Earn at least 1 star to open the next stage.", comment: "")),
            .text(NSLocalizedString("- Each island ends with a boss song. Beat it to sail on to the next island.", comment: "")),
            .text(NSLocalizedString("- Finish the last stage, Indonesia Raya, to complete the tour and get your certificate.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to play Song Stage?", comment: ""), items: [
            .text(NSLocalizedString("- Pick a song, then choose Listen, Practice or Perform.", comment: "")),
            .text(NSLocalizedString("- Listen: watch the song play by itself to learn how it goes.", comment: "")),
            .text(NSLocalizedString("- Practice: the song waits for you. Play the key under the note. After a few tries the right key glows.", comment: "")),
            .text(NSLocalizedString("- Perform: play in time. Press the key when the note touches the line. Perfect, Great and Good earn points; a Miss or a wrong key loses them.", comment: "")),
            .text(NSLocalizedString("- Finish Practice once to unlock Perform. Your stars depend on how accurate you are, and slower speeds earn fewer stars.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to play Note Battle?", comment: ""), items: [
            .text(NSLocalizedString("- Fals shows a note in a speech bubble. Play that note on the keyboard.", comment: "")),
            .text(NSLocalizedString("- A right answer hurts the monster. A wrong answer (or running out of time) costs a heart, the right key glows and the same note comes back.", comment: "")),
            .text(NSLocalizedString("- Your answer counts when you lift your finger, so you can slide to the right key before letting go.", comment: "")),
            .text(NSLocalizedString("- You have 3 hearts. Win by emptying the monster's health bar. The hearts you keep become your stars.", comment: "")),
            .text(NSLocalizedString("- Melody Rush is the endless version: the notes come faster and faster. How long can you last?", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to play Echo?", comment: ""), items: [
            .text(NSLocalizedString("- Listen to a short melody, then play it back in the same order.", comment: "")),
            .text(NSLocalizedString("- On Easy the keys glow while it plays. On Hard they don't, so listen carefully!", comment: "")),
            .text(NSLocalizedString("- A wrong key costs a heart and the melody plays again. Every round the melody gets longer.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("What is the Daily Challenge?", comment: ""), items: [
            .text(NSLocalizedString("- A new challenge every day, the same for everyone: Echo, Note Battle or Song Sprint.", comment: "")),
            .text(NSLocalizedString("- Win it once a day to earn coins. Playing on following days earns a bigger bonus.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("What are coins for?", comment: ""), items: [
            .text(NSLocalizedString("- You earn coins from stars, first clears, bosses, practice, Melody Rush, Echo and the Daily Challenge.", comment: "")),
            .text(NSLocalizedString("- Spend them in the Shop on keyboard colours, falling-note colours and outfits for Alpanica. Nothing costs real money.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to play the skill test?", comment: ""), items: [
            .text(NSLocalizedString("- In the skill test, you must press the tiles that belong to the numeral notation that's shown in the question box.", comment: "")),
            .text(NSLocalizedString("- The questions will appear only ONCE and change automatically once you pressed the answer tiles.", comment: "")),
            .text(NSLocalizedString("- Your answer counts when you lift your finger, so you can slide to the right tile before letting go.", comment: "")),
            .text(NSLocalizedString("- Remember, you CAN'T undo the answer.", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("How do I change the speed, labels or sound?", comment: ""), items: [
            .text(NSLocalizedString("Open Settings (the gear on Home). You can change how fast the notes fall, show key labels in Perform, fix the timing of your taps and switch sound effects on or off.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("Why my tiles won’t make sound?", comment: ""), items: [
            .text(NSLocalizedString("Make sure your device's volume is turned up. Each tile plays as soon as you touch it.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("Can I pressed more than one tiles in one time?", comment: ""), items: [
            .text(NSLocalizedString("Yes! You can press several tiles at the same time with different fingers, and you can also slide your finger from one tile to the next.", comment: "")),
        ]),
        ExpandableSectionData(title: NSLocalizedString("How to read the numeral notation in Song feature?", comment: ""), items: [
            .text(NSLocalizedString("Almost all of the number that shown in numeral notation song is same with the keyboard. However, you'll see some differences, there are:", comment: "")),
            .text(NSLocalizedString("- If you see '0' notation, just ignore it. The 0 notation means is tone beat.", comment: "")),
            .text(NSLocalizedString("- If you see 2 notation number that connected by a wave line above it, only pay attention to the first number, ignore the second number.", comment: "")),
            .text(NSLocalizedString("- If you see the number that has diagona strikethrough, it means # (in major chord). Example: '4̷' means '4#'", comment: ""))
        ]),
        ExpandableSectionData(title: NSLocalizedString("If I move to another device, will my progress be saved?", comment: ""), items: [
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
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 120, minHeight: 80, maxHeight: 80)
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

