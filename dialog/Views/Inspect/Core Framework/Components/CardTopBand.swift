//
//  CardTopBand.swift
//  dialog
//
//  The full-bleed top band of a card step: device render, claim, or brand mark.
//

import SwiftUI

/// The full-bleed top band: device render, claim, or brand mark. The claim paints a full-strength gradient
/// and absorbs the title and subtitle; device and logo use the 0.16 wash. A missing image falls back to the wash.
struct CardTopBand: View {
    let band: InspectConfig.TopBandConfig
    /// Claim flavour: the step's title/subtitle, absorbed into the band.
    var title: String?
    var subtitle: String?
    let accent: Color
    var gradientPalette: [String]?          // config.gradientPalette — the wash/claim colors
    var logoPath: String?                   // resolved brand mark for the logo flavour
    var iconBasePath: String?

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    private var flavor: String { band.flavor.lowercased() }

    private var bandHeight: CGFloat {
        cardTopBandResolvedHeight(flavor: flavor, override: band.height)
    }

    private var colors: [Color] {
        let hexes = band.groundPalette ?? gradientPalette ?? ["#2BD07A", "#2FB6D9", "#5B6EF5"]
        let mapped = hexes.map { Color(hex: $0) }
        return mapped.count >= 2 ? mapped : mapped + mapped
    }

    var body: some View {
        ZStack {
            ground
            content
        }
        .frame(height: bandHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .ignoresSafeArea(edges: .top)   // flush to the window top, like the bookend band
    }

    @ViewBuilder private var ground: some View {
        if flavor == "claim" {
            // Full strength; the band paints its text white for contrast.
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if band.ground?.lowercased() == "image", let path = band.groundImage,
                  let img = InspectImageCache.shared.image(atPath: path) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()   // cover the measured box, never letterbox
        } else {
            // The clamped wash: the card's ground with the palette at atmosphere strength.
            ZStack {
                CardChromeGround()
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.16)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch flavor {
        case "claim":
            VStack(spacing: 9) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, InspectMetrics.unit.cardEdge)
        case "device":
            if let path = band.image, !path.isEmpty {
                IntroHeroImage(path: path, shape: "none",
                               size: Double(bandHeight * 0.8),
                               accentColor: accent, basePath: iconBasePath)
            }
        default:   // logo
            if let logo = band.image ?? logoPath {
                BrandMark(path: logo, box: BrandMarkBox(height: bandHeight * 0.34, maxWidth: nil))
                    .accessibilityHidden(true)
            }
        }
    }
}
