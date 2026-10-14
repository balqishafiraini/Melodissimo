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

    private var isDaily: Bool { result.request.dailyDateKey != nil }

    private var title: LocalizedStringKey {
        if isDaily { return "Daily Challenge" }
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
        if Sizing.isPhone { phoneBody } else { ipadBody }
    }

    /// The line under the title: "Victory!", "Boss defeated!", "Game over"…, or `nil` for a plain song.
    private var statusLine: LocalizedStringKey? {
        if isEndless { return "Game over" }
        if !isSong { return result.didWin ? "Victory!" : "Try again!" }
        if isBossSong { return result.didWin ? "Boss defeated!" : "Try again!" }
        return nil
    }

    /// iPhone: Alpanica on the left and one compact card on the right (title and status on a line, stars and badges on a
    /// line, the stats, coins and any new achievement on a line, the hit breakdown, the buttons). The card scrolls only
    /// if it ever needs more than the screen has.
    private var phoneBody: some View {
        ZStack {
            ScreenBackdrop(color: Color.yellow)

            HStack(spacing: 10) {
                // She hops each time a star lands.
                AlpanicaView(mood: result.stars > 0 ? .happy : .sad, outfit: .equipped, hopTrigger: shownStars, height: 170,
                             keepsOutfit: true)
                    .frame(width: 130)

                ViewThatFits(in: .vertical) {
                    phoneCard
                    ScrollView(showsIndicators: false) { phoneCard }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(10)
        }
        .confettiCannon(counter: $confettiCounter, num: 30, confettiSize: 16, radius: 500, repetitions: 3)
        .onAppear(perform: popInStars)
    }

    private var phoneCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.custom("BalooDa-Regular", size: 24))
                    .foregroundColor(Color.darkGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let statusLine {
                    Text(statusLine)
                        .font(.custom("BalooDa-Regular", size: 18))
                        .foregroundColor(Color.darkGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            HStack(spacing: 12) {
                if !isEndless {
                    starsRow
                }
                badges
            }

            statsGrid

            HStack(spacing: 12) {
                if rewards.coins > 0 {
                    CoinCountUp(total: rewards.coins, delay: 0.8 + 0.45 * Double(result.stars))
                }
                if !rewards.newAchievements.isEmpty {
                    AchievementBanner(titles: rewards.newAchievements)
                }
            }

            if isSong {
                breakdown
            } else if result.didWin {
                heartsLeft
            }

            buttons
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
    }

    /// iPad: the v2 layout, unchanged.
    private var ipadBody: some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            HStack(spacing: 32) {
                // She hops each time a star lands.
                AlpanicaView(mood: result.stars > 0 ? .happy : .sad, outfit: .equipped, hopTrigger: shownStars, height: 380,
                             keepsOutfit: true)
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
                    if rewards.coins > 0 {
                        // Counts up once the stars have landed.
                        CoinCountUp(total: rewards.coins, delay: 0.8 + 0.45 * Double(result.stars))
                    }
                    if !rewards.newAchievements.isEmpty {
                        AchievementBanner(titles: rewards.newAchievements)
                    }
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
        HStack(spacing: Sizing.s(12)) {
            ForEach(0..<3, id: \.self) { index in
                let isShown = index < shownStars
                // The empty star stays; the gold one stamps down on top of it, big and tilted, then settles.
                // With Reduce Motion it only fades in.
                ZStack {
                    Image(systemName: "star")
                        .foregroundColor(Color.darkGreen.opacity(0.3))
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.yellow)
                        .scaleEffect(isShown || reduceMotion ? 1 : 2.4)
                        .rotationEffect(.degrees(isShown || reduceMotion ? 0 : -25))
                        .opacity(isShown ? 1 : 0)
                }
                .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 36 : 64))
                .animation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.5), value: shownStars)
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        if rewards.isNewBest || isFullCombo {
            HStack(spacing: Sizing.s(12)) {
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
            .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 14 : 22))
            .foregroundColor(.white)
            .padding(.horizontal, Sizing.s(16))
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    private var statsGrid: some View {
        HStack(spacing: Sizing.s(28)) {
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
                .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 24 : 40))
                .foregroundColor(Color.darkGreen)
        }
    }

    private var breakdown: some View {
        HStack(spacing: Sizing.s(18)) {
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
                .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 20 : 30))
                .foregroundColor(Color.darkGreen)
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: Sizing.isPhone ? 8 : 12, height: Sizing.isPhone ? 8 : 12)
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
            HeartsView(hearts: result.stars, maxHearts: 3, size: Sizing.isPhone ? 30 : 34)
        }
    }

    private var buttons: some View {
        HStack(spacing: Sizing.s(14)) {
            resultButton("Retry", filled: false) {
                router.replaceTop(with: .play(result.request))
            }
            if isDaily {
                // The day's challenge started from Home, so it ends there.
                resultButton("Menu", filled: true) { router.popToRoot() }
            } else if result.request.campaignStageId != nil {
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
        SoundButton(action: action) {
            Text(title)
                .buttonFrame(width: 190, height: 64)
                .background(filled ? Color.darkGreen : Color.yellow)
                .foregroundColor(filled ? .white : Color.darkGreen)
                .cornerRadius(Sizing.s(20))
                .font(Font.headline)
        }
    }

    // MARK: Animation

    /// Stars appear one by one; three stars also fire the confetti. A new Rush high score gets the confetti too.
    private func popInStars() {
        if isEndless, rewards.isNewBest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { confettiCounter += 1 }
        }
        // The coins start counting once the stars have landed, and a badge or a high score gets its fanfare after.
        let landed = 0.4 + 0.45 * Double(result.stars)
        if rewards.coins > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + landed + 0.4) { SFX.play(.coin) }
        }
        if !rewards.newAchievements.isEmpty || (isEndless && rewards.isNewBest) {
            DispatchQueue.main.asyncAfter(deadline: .now() + landed + 0.9) { SFX.play(.unlock) }
        }
        guard result.stars > 0 else { return }
        for star in 1...result.stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + 0.45 * Double(star)) {
                shownStars = star
                SFX.play(.star)
                if star == 3 { confettiCounter += 1 }
            }
        }
    }
}
