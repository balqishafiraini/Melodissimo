//
//  ContentView.swift
//  Melodissimo
//
//  Created by Balqis on 30/09/23.
//

import SwiftUI
import Foundation

/// The welcome scene, drawn in code so it fills any iPad or iPhone screen.
/// Every size is derived from the screen height, so the composition keeps its
/// proportions while the hills and fence stretch to the full width.
struct SplashscreenView: View {
    @Binding var isActive: Bool
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let melodicaWidth = min(w * 0.6, h * 1.05)

            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.50, green: 0.66, blue: 0.92),
                                        Color(red: 0.12, green: 0.36, blue: 0.81)],
                               startPoint: .top, endPoint: .bottom)

                // Ground
                HillShape(peaks: [0.55, 0.25, 0.45, 0.2, 0.5])
                    .fill(Color(red: 0.22, green: 0.62, blue: 0.40))
                    .frame(height: h * 0.25)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                HillShape(peaks: [0.35, 0.6, 0.4, 0.7, 0.3])
                    .fill(Color(red: 0.04, green: 0.42, blue: 0.31))
                    .frame(height: h * 0.15)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // Scenery
                Text("🌲")
                    .font(.custom("BalooDa-Regular", size: h * 0.3))
                    .position(x: max(h * 0.14, w * 0.1), y: h * 0.86)
                Text("🌵")
                    .font(.custom("BalooDa-Regular", size: h * 0.12))
                    .position(x: w * 0.5, y: h * 0.94)
                ForEach([0.25, 0.34, 0.4], id: \.self) { x in
                    Text("🌱")
                        .font(.custom("BalooDa-Regular", size: h * 0.04))
                        .position(x: w * x, y: h * (0.9 + (x - 0.3) * 0.2))
                }
                FenceView()
                    .frame(width: w * 0.46, height: h * 0.14)
                    .position(x: w * 0.77, y: h * 0.94)

                // Title + melodica
                VStack(alignment: .leading, spacing: h * 0.03) {
                    Text("Welcome to")
                        .font(.custom("BalooDa-Regular", size: h * 0.06))
                        .foregroundColor(.white)
                        .padding(.leading, h * 0.04)

                    Text("MELODISSIMO")
                        .font(.custom("BalooDa-Regular", size: h * 0.1))
                        .foregroundColor(.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, h * 0.06)
                        .padding(.vertical, h * 0.015)
                        .background(Capsule().fill(.white))
                        .scaleEffect(appeared ? 1 : 0.85)

                    MelodicaIllustrationView(showsBrand: true)
                        .frame(width: melodicaWidth, height: melodicaWidth * 0.28)
                }
                .padding(.leading, max(h * 0.06, geo.safeAreaInsets.leading + 16))
                .padding(.top, h * 0.08)

                // Alpaca with swirling notes
                ZStack {
                    MusicSwirlView(isAnimating: appeared)
                        .frame(width: h * 0.42, height: h * 0.42)
                        .offset(x: -h * 0.08, y: -h * 0.02)
                    Image("alpanica")
                        .resizable()
                        .scaledToFit()
                        .frame(height: h * 0.5)
                        .offset(y: appeared ? 0 : h * 0.02)
                }
                .position(x: w - max(h * 0.24, geo.safeAreaInsets.trailing + h * 0.2), y: h * 0.62)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            #if DEBUG
            if QARoutes.skipsSplash {
                isActive = true
                return
            }
            #endif
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

/// Rolling hills; `peaks` are relative heights (0 = top of the frame) across the width.
struct HillShape: Shape {
    var peaks: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * (peaks.first ?? 0.5)))
        let step = rect.width / CGFloat(max(peaks.count - 1, 1))
        for i in 1..<peaks.count {
            let prev = CGPoint(x: step * CGFloat(i - 1), y: rect.height * peaks[i - 1])
            let next = CGPoint(x: step * CGFloat(i), y: rect.height * peaks[i])
            path.addCurve(to: next,
                          control1: CGPoint(x: prev.x + step / 2, y: prev.y),
                          control2: CGPoint(x: next.x - step / 2, y: next.y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A wooden picket fence.
private struct FenceView: View {
    private let wood = LinearGradient(colors: [Color(red: 0.85, green: 0.62, blue: 0.25),
                                               Color(red: 0.62, green: 0.42, blue: 0.13)],
                                      startPoint: .leading, endPoint: .trailing)

    var body: some View {
        GeometryReader { geo in
            let pickets = 5
            let picketWidth = geo.size.width / CGFloat(pickets) * 0.5
            let gap = (geo.size.width - picketWidth * CGFloat(pickets)) / CGFloat(pickets - 1)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(wood)
                    .frame(width: geo.size.width, height: geo.size.height * 0.16)
                    .offset(y: geo.size.height * 0.55)
                ForEach(0..<pickets, id: \.self) { i in
                    PicketShape()
                        .fill(wood)
                        .frame(width: picketWidth, height: geo.size.height)
                        .offset(x: CGFloat(i) * (picketWidth + gap))
                }
            }
        }
    }
}

private struct PicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = rect.width * 0.5
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + tip))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tip))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Colourful notes arranged on an arc behind the alpaca.
private struct MusicSwirlView: View {
    var isAnimating: Bool

    private let colors: [Color] = [.pink, .purple, .orange, .yellow, .green, .teal, .blue, .red]

    var body: some View {
        GeometryReader { geo in
            let r = geo.size.width / 2
            ZStack {
                Image(systemName: "music.note.list")
                    .font(.custom("BalooDa-Regular", size: r * 0.4))
                    .foregroundColor(.pink)
                    .position(x: r * 0.15, y: r * 1.2)
                ForEach(0..<8, id: \.self) { i in
                    let angle = Angle.degrees(200 + Double(i) * 22)
                    Image(systemName: i.isMultiple(of: 2) ? "music.note" : "music.quarternote.3")
                        .font(.custom("BalooDa-Regular", size: r * 0.18))
                        .foregroundColor(colors[i])
                        .position(x: r + r * 0.85 * CGFloat(cos(angle.radians)),
                                  y: r + r * 0.85 * CGFloat(sin(angle.radians)))
                        .offset(y: isAnimating ? -r * 0.04 : r * 0.04)
                }
            }
        }
    }
}

#Preview {
    SplashscreenView(isActive: .constant(false))
}
