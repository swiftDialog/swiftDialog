//
// BentoStepViews.swift
// Modular components for the "bento" step type
//
// Created by Henry Stamerjohann, Declarative IT GmbH, 25/01/2026
//
// Two layout modes: grid (full-width) and split (sidebar + grid)
// Reusable across Preset5, Preset6, and other templates

import SwiftUI

// MARK: - Bento Step Configuration

/// All configuration needed to render a bento step, extracted from IntroStep
struct BentoStepConfig {
    let title: String?
    let subtitle: String?
    let heroImage: String?
    let heroImageShape: String?
    let heroImageSize: Double?
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    let columns: Int
    let rowHeight: CGFloat
    let gap: CGFloat
    let tintColor: Color?
    let sidebarContent: [InspectConfig.GuidanceContent]?
    let sidebarRatio: CGFloat
    let layout: String  // "grid" | "split"

    init(from step: InspectConfig.IntroStep, accentColor: Color) {
        self.title = step.title
        self.subtitle = step.subtitle
        self.heroImage = step.heroImage
        self.heroImageShape = step.heroImageShape
        self.heroImageSize = step.heroImageSize
        self.cells = step.bentoCells ?? []
        self.columns = step.bentoColumns ?? 4
        self.rowHeight = CGFloat(step.bentoRowHeight ?? 140)
        self.gap = CGFloat(step.bentoGap ?? 12)
        self.tintColor = step.bentoTintColor.flatMap { Color(hex: $0) }
        self.sidebarContent = step.bentoSidebarContent
        self.sidebarRatio = CGFloat(min(max(step.bentoSidebarRatio ?? 0.35, 0.25), 0.45))
        self.layout = step.bentoLayout ?? "grid"
    }
}

// MARK: - Bento Grid Step Layout (Full-Width)

/// Full-width bento grid with optional title/subtitle above.
/// Uses IntroStepContainer for consistent footer and progress dots.
struct BentoGridStepLayout: View {
    let config: BentoStepConfig
    let accentColor: Color
    let iconBasePath: String?
    @ObservedObject var inspectState: InspectState

    var body: some View {
        VStack(spacing: 16) {
            // Title
            if let title = config.title {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
            }

            // Subtitle
            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Bento grid — full width with horizontal padding
            BentoGridView(
                cells: config.cells,
                columns: config.columns,
                rowHeight: config.rowHeight,
                gap: config.gap,
                scaleFactor: 1.0,
                accentColor: accentColor,
                iconBasePath: iconBasePath,
                tintColor: config.tintColor,
                inspectState: inspectState,
                inlineExpansion: true
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
}

// MARK: - Bento Split Step Layout (Sidebar + Grid)

/// Two-panel layout: left sidebar with logo/title/content + right bento grid.
/// Sidebar ratio is configurable (0.25-0.45).
struct BentoSplitStepLayout: View {
    let config: BentoStepConfig
    let accentColor: Color
    let iconBasePath: String?
    let footerText: String?
    let backButtonText: String
    let continueButtonText: String
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    @ObservedObject var inspectState: InspectState

    var body: some View {
        VStack(spacing: 0) {
            // Accent ribbon is persistent at Preset5 root level

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left sidebar
                    bentoSidebar
                        .frame(width: geometry.size.width * config.sidebarRatio)
                        .background(sidebarBackground)

                    // Right panel: bento grid + footer
                    VStack(spacing: 0) {
                        // Bento grid
                        BentoGridView(
                            cells: config.cells,
                            columns: config.columns,
                            rowHeight: config.rowHeight,
                            gap: config.gap,
                            scaleFactor: 1.0,
                            accentColor: accentColor,
                            iconBasePath: iconBasePath,
                            tintColor: config.tintColor,
                            inspectState: inspectState,
                            inlineExpansion: true
                        )
                        .padding(24)

                        Spacer()

                        Divider()

                        // Footer with navigation
                        IntroFooterView(
                            footerText: nil,
                            backButtonText: backButtonText,
                            continueButtonText: continueButtonText,
                            accentColor: accentColor,
                            showBackButton: showBackButton,
                            onBack: onBack,
                            onContinue: onContinue
                        ) {
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width * (1.0 - config.sidebarRatio))
                }
            }
        }
    }

    // MARK: - Sidebar

    private var bentoSidebar: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            // Hero image / logo — use AsyncImageView with .fit to avoid clipping wide logos
            if let heroImage = config.heroImage {
                let heroSize = config.heroImageSize ?? 120
                AsyncImageView(
                    iconPath: heroImage,
                    basePath: iconBasePath,
                    maxWidth: heroSize * 2,
                    maxHeight: heroSize,
                    imageFit: .fit,
                    fallback: { EmptyView() }
                )
                .padding(.horizontal, 24)
            }

            // Title
            if let title = config.title {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Subtitle
            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Optional rich sidebar content
            if let sidebarContent = config.sidebarContent, !sidebarContent.isEmpty {
                GuidanceContentView(
                    contentBlocks: sidebarContent,
                    scaleFactor: 1.0,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    itemId: "bento-sidebar",
                    onOverlayTap: nil,
                    accentColor: accentColor,
                    contentAlignment: .center
                )
                .padding(.horizontal, 20)
            }

            Spacer()

            // Logo is a persistent overlay at Preset5 root level
        }
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [
                    accentColor.opacity(0.05),
                    Color(NSColor.windowBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
