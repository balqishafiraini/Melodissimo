//
//  CertificateView.swift
//  Melodissimo
//

import SwiftUI

/// The picture that is shared: a cream certificate with Alpanica, the stars and the date. It is
/// drawn at a fixed size so the shared image is the same on every iPhone and iPad.
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
                    // A fixed size, not `.headline` (which scales on iPhone): the shared picture is the same on every device.
                    .font(.custom("BalooDa-Regular", size: 30))
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

            if Sizing.isPhone {
                phoneLayout
            } else {
                VStack(spacing: 22) {
                    card
                        .scaleEffect(0.82)
                        .frame(width: CertificateCard.size.width * 0.82, height: CertificateCard.size.height * 0.82)

                    HStack(spacing: 20) {
                        shareButton
                        doneButton
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
                #if DEBUG
                // The shared picture must be the same size on every device (IPHONE_PLAN D12).
                NSLog("CERTIFICATE image %.0f x %.0f px", image.size.width * image.scale, image.size.height * image.scale)
                #endif
            }
        }
    }
    /// iPhone: the card is scaled to fit and the buttons stand beside it, which leaves the card the most room.
    /// Only this on-screen preview is scaled: the card that is rendered for sharing keeps its fixed size.
    private var phoneLayout: some View {
        GeometryReader { geo in
            let buttons: CGFloat = 130
            let scale = min((geo.size.width - buttons - 48) / CertificateCard.size.width,
                            (geo.size.height - 16) / CertificateCard.size.height)
            HStack(spacing: 16) {
                card
                    .scaleEffect(scale)
                    .frame(width: CertificateCard.size.width * scale, height: CertificateCard.size.height * scale)
                VStack(spacing: 14) {
                    shareButton
                    doneButton
                }
                .frame(width: buttons)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let shareImage {
            ShareLink(item: shareImage, preview: SharePreview("Tour Complete", image: shareImage)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .buttonFrame(width: 220, height: 64)
                    .background(Color.yellow)
                    .foregroundColor(Color.darkGreen)
                    .cornerRadius(Sizing.s(20))
                    .font(Font.headline)
            }
        }
    }

    private var doneButton: some View {
        SoundButton(action: onClose) {
            Text("Done")
                .buttonFrame(width: 220, height: 64)
                .background(Color.darkGreen)
                .foregroundColor(.white)
                .cornerRadius(Sizing.s(20))
                .font(Font.headline)
        }
    }
}
