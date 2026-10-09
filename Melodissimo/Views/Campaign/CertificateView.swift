//
//  CertificateView.swift
//  Melodissimo
//

import SwiftUI

/// The picture that is shared: a cream certificate with Alpanica, the stars and the date. It is
/// drawn at a fixed size so the shared image is the same on every iPad.
struct CertificateCard: View {
    static let size = CGSize(width: 880, height: 560)

    let stars: Int
    let maxStars: Int
    let date: Date
    let outfit: AlpanicaOutfit

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(Color.vanila)
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.yellow, lineWidth: 10)
                .padding(18)

            VStack(spacing: 14) {
                Text("Nusantara Tour")
                    .font(.custom("BalooDa-Regular", size: 30))
                    .foregroundColor(Color.darkGreen.opacity(0.7))
                Text("Tour Complete")
                    .font(.custom("BalooDa-Regular", size: 72))
                    .foregroundColor(Color.darkGreen)

                HStack(spacing: 30) {
                    Image(outfit.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 230, height: 230)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("You brought every song of Nusantara back, from Sabang to Merauke!")
                            .font(.custom("BalooDa-Regular", size: 30))
                            .foregroundColor(Color.darkGreen)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.yellow)
                            Text("\(stars) / \(maxStars) stars")
                        }
                        .font(.custom("BalooDa-Regular", size: 34))
                        .foregroundColor(Color.darkGreen)
                    }
                    .frame(maxWidth: 440, alignment: .leading)
                }

                Text(date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .foregroundColor(Color.darkGreen.opacity(0.8))
            }
            .padding(40)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// The Tour Complete screen over the map: the certificate, a share button and Done.
struct CertificateView: View {
    let progress: ProgressStore
    let onClose: () -> Void

    @State private var shareImage: Image?

    private var card: CertificateCard {
        CertificateCard(stars: progress.tourStars,
                        maxStars: CampaignCatalog.allStages.count * 3,
                        date: progress.tourCompletedAt ?? Date(),
                        outfit: .equipped)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                card
                    .scaleEffect(0.82)
                    .frame(width: CertificateCard.size.width * 0.82, height: CertificateCard.size.height * 0.82)

                HStack(spacing: 20) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Tour Complete", image: shareImage)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(width: 220, height: 64)
                                .background(Color.yellow)
                                .foregroundColor(Color.darkGreen)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }
                    }
                    Button(action: onClose) {
                        Text("Done")
                            .frame(width: 220, height: 64)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                }
            }
        }
        .task {
            // Render once at twice the size for a sharp picture.
            let renderer = ImageRenderer(content: card)
            renderer.scale = 2
            if let image = renderer.uiImage {
                shareImage = Image(uiImage: image)
            }
        }
    }
}
