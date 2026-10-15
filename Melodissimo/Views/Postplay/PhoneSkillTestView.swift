//
//  PhoneSkillTestView.swift
//  Melodissimo
//

import SwiftUI

/// The skill test on iPhone: the intro, the ten questions and the score, as one screen that swaps its own content.
///
/// The iPad versions (`OnboardPostplayView` → `PostplayView` → `PostplayScoreView`) each wrap themselves in a
/// `NavigationView` and push the next page. Reached from Home's `NavigationStack`, that nesting does not work on
/// iPhone (the "Next" button does nothing), so here there is no nested navigation at all: Back, "?" and the final
/// "Menu" go through the Home stack's `AppRouter`.
struct PhoneSkillTestView: View {
    enum Step: Equatable {
        case intro
        case quiz
        case score(Int)
    }

    @EnvironmentObject private var router: AppRouter
    @StateObject private var tiles = TilesViewModel()
    @State var step = Step.intro

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softGreen)
            switch step {
            case .intro: intro
            case .quiz: quiz
            case .score(let score): scorePage(score)
            }
        }
        .onChange(of: tiles.canNavigateToAfterQuizPage) { finished in
            if finished { step = .score(tiles.score) }
        }
        .onAppear {
            // A screen opened straight on the quiz (the screenshot scripts do) still needs its questions.
            if step == .quiz, tiles.currentLevel == nil { startQuiz() }
        }
    }

    // MARK: Intro

    private var intro: some View {
        PhoneStoryPage(art: "alpanica", buttonTitle: "Next",
                       onButton: startQuiz,
                       onHelp: { router.push(.help) },
                       onBack: { router.pop() }) {
            Text("Thank you for learn with Melodissimo! Now, let's test your skill again in Post-Play Quiz, it's similar when you do it on Pre-Play Quiz~")
                .phoneCard()
            Text("Pre-Play score: \(UserDefaults.standard.integer(forKey: "preplayScore"))\n Post-Play Score: \(UserDefaults.standard.integer(forKey: "postplayScore"))")
                .phoneCard()
        }
    }

    private func startQuiz() {
        tiles.getLevel(currentLevelNo: 1, currentLevelCat: "postplay")
        step = .quiz
    }

    // MARK: Quiz

    private var quiz: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    step = .intro
                } label: {
                    Text("< Back")
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(80), maxHeight: Sizing.tap(80))
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.headline)
                }
                Spacer()
                Button {
                    router.push(.help)
                } label: {
                    Text("?")
                        .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.title)
                }
            }

            Spacer()

            Text("\(tiles.currentLevel?.question[tiles.currentQuestionIndex] ?? "N/A")")
                .foregroundStyle(.black)
                .font(.custom("BalooDa-Regular", size: Sizing.f(70)))
                .frame(width: screenWidth * 0.5, height: max(screenHeight * 0.15, 64))
                .background(RoundedRectangle(cornerRadius: Sizing.s(40)).fill(.white))

            Spacer()

            // The answer counts when the finger lifts, so a player can slide to the right key first.
            PianoKeyboard(metrics: .full, showLabels: false, onNoteOff: { id, isRelease in
                if isRelease { tiles.addAnswer(id) }
            })

            Spacer()
        }
        .topBarScreenPadding(ipad: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Score

    private func scorePage(_ score: Int) -> some View {
        PhoneStoryPage(art: "alpanicaGlasses", buttonTitle: "Menu",
                       onButton: { finish(score) },
                       onHelp: { router.push(.help) }) {
            HStack(spacing: 8) {
                PhoneScoreCircle(score: score)
                Text("Thank you! Great job for finishing it and congratulations on your score!")
                    .phoneCard(alignment: .center)
            }
        }
    }

    /// Stores the score and goes back to Home, whatever the stack held.
    private func finish(_ score: Int) {
        UserDefaults.standard.set(score, forKey: "postplayScore")
        router.popToRoot()
    }
}
