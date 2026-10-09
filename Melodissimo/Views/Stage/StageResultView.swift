//
//  StageResultView.swift
//  Melodissimo
//

import SwiftUI
import ConfettiSwiftUI

/// The results of a Perform run: stars popping in one by one, score, accuracy, combo and the
/// Perfect / Great / Good / Miss / Wrong breakdown, plus "New best!" and FULL COMBO badges.
struct StageResultView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let result: PlayResult
    let rewards: RewardSummary

    @State private var shownStars = 0
    @State private var confettiCounter = 0

    private var isSong: Bool {
        if case .song = result.request.kind { return true }
        return false
    }

    private var title: LocalizedStringKey {
        switch result.request.kind {
        case .song(let songId, _, _, _, _, _):
            return LocalizedStringKey(SongLibrary.song(id: songId)?.title ?? "")
        case .battle(let config):
            return config.isBoss ? "Boss Battle" : "Note Battle"
        case .classic(let levelNo):
            return "Level \(levelNo)"
        case .echo:
            return "Echo"
        case .rush:
            return "Melody Rush"
        case .daily:
            return "Daily Challenge"
        }
    }

    private var isBossSong: Bool {
        if case .song(_, _, _, let isBoss, _, _) = result.request.kind { return isBoss }
        return false
    }

    private var isRush: Bool {
        if case .rush = result.request.kind { return true }
        return false
    }

    /// Echo scores are rounds cleared, and an endless run can't be won, only extended.
    private var isEndlessEcho: Bool {
        if case .echo(let config) = result.request.kind { return config.roundsToClear == nil }
        return false
    }

    private var isEcho: Bool {
        if case .echo = result.request.kind { return true }
        return false
    }

    /// Modes that end with "Game over" and a high score instead of stars.
    private var isEndless: Bool { isRush || isEndlessEcho }

    private var isFullCombo: Bool {
        isSong && result.accuracy != nil && result.miss == 0 && result.wrong == 0
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            HStack(spacing: 32) {
                // She hops each time a star lands.
                AlpanicaView(mood: result.stars > 0 ? .happy : .sad, hopTrigger: shownStars, height: 380)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 18) {
                    Text(title)
                        .font(.custom("BalooDa-Regular", size: 36))
                        .foregroundColor(Color.darkGreen)
                        .lineLimit(1)

                    if isEndless {
                        // Endless modes have no winning, only how far you got.
                        Text("Game over")
                            .font(.custom("BalooDa-Regular", size: 28))
                            .foregroundColor(Color.darkGreen)
                    } else if !isSong {
                        Text(result.didWin ? "Victory!" : "Try again!")
                            .font(.custom("BalooDa-Regular", size: 28))
                            .foregroundColor(Color.darkGreen)
                    } else if isBossSong {
                        Text(result.didWin ? "Boss defeated!" : "Try again!")
                            .font(.custom("BalooDa-Regular", size: 28))
                            .foregroundColor(Color.darkGreen)
                    }

                    if !isEndless {
                        starsRow
                    }
                    badges
                    statsGrid
                    if isSong {
                        breakdown
                    } else if result.didWin {
                        heartsLeft
                    }
                    Spacer(minLength: 0)
                    buttons
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 36).fill(Color.white))
            }
            .padding(32)
        }
        .confettiCannon(counter: $confettiCounter, num: 30, confettiSize: 16, radius: 500, repetitions: 3)
        .onAppear(perform: popInStars)
    }

    // MARK: Pieces

    private var starsRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                let isShown = index < shownStars
                Image(systemName: isShown ? "star.fill" : "star")
                    .font(.custom("BalooDa-Regular", size: 64))
                    .foregroundColor(isShown ? Color.yellow : Color.darkGreen.opacity(0.3))
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.5)
                    .animation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.45), value: shownStars)
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        if rewards.isNewBest || isFullCombo {
            HStack(spacing: 12) {
                if rewards.isNewBest {
                    badge(isEndless ? "NEW HIGH SCORE" : "New best!", color: Color.green)
                }
                if isFullCombo {
                    badge("FULL COMBO", color: Color.red)
                }
            }
        }
    }

    private func badge(_ title: LocalizedStringKey, color: Color) -> some View {
        Text(title)
            .font(.custom("BalooDa-Regular", size: 22))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    private var statsGrid: some View {
        HStack(spacing: 28) {
            stat(isEcho ? "Rounds" : "Score", "\(result.score)")
            // Songs report timing accuracy; battles carry their first-try percentage elsewhere.
            if isSong, let accuracy = result.accuracy {
                stat("Accuracy", "\(Int(accuracy.rounded()))%")
            }
            if !isEcho {
                stat("Max combo", "\(result.maxCombo)")
            }
            if isRush {
                stat("High score", "\(ProgressStore.shared.rushHighScore)")
            } else if isEndlessEcho {
                stat("High score", "\(ProgressStore.shared.echoHighScore)")
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.darkGreen.opacity(0.8))
            Text(value)
                .font(.custom("BalooDa-Regular", size: 40))
                .foregroundColor(Color.darkGreen)
        }
    }

    private var breakdown: some View {
        HStack(spacing: 18) {
            breakdownItem("Perfect!", result.perfect, Color.yellow)
            breakdownItem("Great", result.great, Color.softGreen)
            breakdownItem("Good", result.good, Color.softBlue)
            breakdownItem("Miss", result.miss, Color.red)
            breakdownItem("Wrong", result.wrong, Color.gray)
        }
    }

    private func breakdownItem(_ title: LocalizedStringKey, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.custom("BalooDa-Regular", size: 30))
                .foregroundColor(Color.darkGreen)
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(title)
                    .font(.footnote)
                    .foregroundColor(Color.darkGreen)
            }
        }
    }

    /// Battles are won with hearts to spare: the stars are the hearts that were left.
    private var heartsLeft: some View {
        HStack(spacing: 10) {
            Text("Hearts left")
                .font(.subheadline)
                .foregroundColor(Color.darkGreen.opacity(0.8))
            HeartsView(hearts: result.stars, maxHearts: 3, size: 34)
        }
    }

    private var buttons: some View {
        HStack(spacing: 14) {
            resultButton("Retry", filled: false) {
                router.replaceTop(with: .play(result.request))
            }
            if result.request.campaignStageId != nil {
                // A campaign stage always goes back to the map, which moves Alpanica along.
                resultButton(result.didWin ? "Next" : "Map", filled: true) {
                    router.pop(to: .campaignMap)
                }
            } else {
                switch result.request.kind {
                case .song:
                    resultButton("Song menu", filled: true) { router.pop(to: .songRepositoryQuiz) }
                case .classic:
                    resultButton("Levels", filled: true) { router.pop(to: .notationLevelMenu) }
                default:
                    resultButton("Back", filled: true) { router.pop() }
                }
                if case .classic(let levelNo) = result.request.kind, result.didWin, levelNo < 100 {
                    resultButton("Next level", filled: true) {
                        router.replaceTop(with: .play(PlayRequest(kind: .classic(levelNo: levelNo + 1))))
                    }
                }
            }
        }
    }

    private func resultButton(_ title: LocalizedStringKey, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(width: 190, height: 64)
                .background(filled ? Color.darkGreen : Color.yellow)
                .foregroundColor(filled ? .white : Color.darkGreen)
                .cornerRadius(20)
                .font(Font.headline)
        }
    }

    // MARK: Animation

    /// Stars appear one by one; three stars also fire the confetti. A new Rush high score gets the confetti too.
    private func popInStars() {
        if isEndless, rewards.isNewBest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { confettiCounter += 1 }
        }
        guard result.stars > 0 else { return }
        for star in 1...result.stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + 0.45 * Double(star)) {
                shownStars = star
                if star == 3 { confettiCounter += 1 }
            }
        }
    }
}
