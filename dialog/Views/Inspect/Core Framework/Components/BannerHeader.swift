//
//  BannerHeader.swift
//  dialog
//
//  Preset2's window header: a gradient, image or icon-only banner, then the window title.
//

import SwiftUI

struct BannerHeader: View {
    @ObservedObject var state: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let scaleFactor: CGFloat
    let windowWidth: CGFloat
    /// Pre-localized window title (assembly resolves via PresetLocalization).
    let title: String
    /// Pre-localized banner title; nil hides the chip/overlay.
    let bannerTitle: String?

    var body: some View {
        if state.uiConfiguration.bannerImage == "gradient" {
            gradientBanner
        } else if state.uiConfiguration.bannerImage != nil {
            imageBanner
        } else {
            iconHeader
        }
    }

    // MARK: - Gradient branch

    @ViewBuilder
    private var gradientBanner: some View {
        let bannerH = CGFloat(state.uiConfiguration.bannerHeight) * scaleFactor
        let gradientPalette = (state.config?.gradientPalette ?? ["#007AFF", "#5AC8FA"]).compactMap { Color(hex: $0) }
        let gradientSeed = state.uiConfiguration.windowTitle
        let gradientStyleStr = state.config?.gradientStyle ?? "ethereal"
        let gradientStyle = ProceduralGradientStyle(rawValue: gradientStyleStr) ?? .ethereal

        ZStack(alignment: .bottom) {
            // Gradient background — fills to top edge
            ProceduralGradientView(seed: gradientSeed, palette: gradientPalette, style: gradientStyle)

            LinearGradient(
                colors: [.clear, Color(NSColor.windowBackgroundColor).opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bannerH * 0.3)

            VStack(spacing: 8 * scaleFactor) {
                IconView(
                    image: iconCache.getMainIconPath(for: state),
                    overlay: iconCache.getOverlayIconPath(for: state),
                    defaultImage: "briefcase.fill",
                    defaultColour: "accent"
                )
                .frame(height: 160 * scaleFactor)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                if let bannerTitle {
                    Text(bannerTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
            }
            .padding(.bottom, 12 * scaleFactor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerH)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .onAppear { iconCache.cacheMainIcon(for: state) }

            // 6pt below the hero, 56pt side insets.
        Text(title)
            .font(.system(size: 26, weight: .bold))    // Setup Assistant title: 26pt bold
            .multilineTextAlignment(.center)
            .padding(.top, 6 * scaleFactor)
            .padding(.horizontal, 56 * scaleFactor)
    }

    // MARK: - Image branch

    @ViewBuilder
    private var imageBanner: some View {
        ZStack {
            if let bannerNSImage = iconCache.bannerImage {
                Image(nsImage: bannerNSImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: windowWidth, height: CGFloat(state.uiConfiguration.bannerHeight))
                    .clipped()

                if let bannerTitle {
                    Text(bannerTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)
                }
            }
        }
        .frame(width: windowWidth, height: CGFloat(state.uiConfiguration.bannerHeight))
        .ignoresSafeArea(edges: .top)
        .onAppear { iconCache.cacheBannerImage(for: state) }

            // 6pt below the hero, 56pt side insets.
        Text(title)
            .font(.system(size: 26, weight: .bold))    // Setup Assistant title: 26pt bold
            .multilineTextAlignment(.center)
            .padding(.top, 6 * scaleFactor)
            .padding(.horizontal, 56 * scaleFactor)
    }

    // MARK: - Icon-only branch

    private var iconHeader: some View {
        VStack(spacing: 16 * scaleFactor) {
            // Fixed height so the title below does not move with the icon's aspect. 104, not 140:
            // in the 860×600 window the hero took a third of the height and squeezed the cards.
            // No authored icon: this Mac's own icon (the `computer` keyword), not a generic symbol.
            let authored = iconCache.getMainIconPath(for: state)
            IconView(
                image: authored.isEmpty ? "computer" : authored,
                overlay: iconCache.getOverlayIconPath(for: state),
                defaultImage: "briefcase.fill",
                defaultColour: "accent"
            )
            .frame(height: 104 * scaleFactor)
            .onAppear { iconCache.cacheMainIcon(for: state) }

            Text(title)
                .font(.system(size: 26, weight: .bold))    // Setup Assistant title: 26pt bold
                .multilineTextAlignment(.center)
                .padding(.horizontal, 56 * scaleFactor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24 * scaleFactor)
    }
}
