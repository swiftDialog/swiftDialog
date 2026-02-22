//
//  PresetPhaseViews.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Shared intro/summary screen views for Preset1/2 multi-screen flow.
//  Reuses GuidanceContentView, BentoGridView, and IntroHeroImage.
//

import SwiftUI

// MARK: - Phase Enum

/// Three-phase flow for Preset1/2: optional intro → items → optional summary
enum PresetPhase: Equatable {
    case intro
    case main
    case summary
}

// MARK: - Intro Screen View

/// Full-screen intro view shown before the items view in Preset1/2.
/// Renders hero image, title, subtitle, and rich content blocks via GuidanceContentView.
struct PresetIntroScreenView: View {
    let config: InspectConfig.PresetIntroScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: InspectState
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40 * scaleFactor)

            // Hero image
            if let heroPath = config.heroImage, !heroPath.isEmpty {
                IntroHeroImage(
                    path: heroPath,
                    shape: config.heroImageShape ?? "none",
                    size: config.heroImageSize ?? 200,
                    accentColor: highlightColor,
                    basePath: basePath
                )
                .padding(.bottom, 20 * scaleFactor)
            }

            // Title
            if let title = config.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 28 * scaleFactor, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scaleFactor)
            }

            // Subtitle
            if let subtitle = config.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scaleFactor)
                    .padding(.top, 6 * scaleFactor)
            }

            // Rich content blocks
            if let contentBlocks = config.content, !contentBlocks.isEmpty {
                ScrollView {
                    GuidanceContentView(
                        contentBlocks: contentBlocks,
                        scaleFactor: scaleFactor,
                        iconBasePath: basePath,
                        inspectState: inspectState,
                        itemId: "preset-intro-screen",
                        accentColor: highlightColor,
                        contentAlignment: .center
                    )
                    .padding(.horizontal, 40 * scaleFactor)
                }
                .padding(.top, 20 * scaleFactor)
            }

            Spacer()

            // Continue button
            HStack {
                Spacer()
                Button(action: onContinue) {
                    Text(config.buttonText ?? "Get Started")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(highlightColor)
            }
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.bottom, 24 * scaleFactor)
        }
    }
}

// MARK: - Summary Screen View

/// Full-screen summary/bento view shown after items complete in Preset1/2.
/// Supports both GuidanceContentView content blocks and BentoGridView layouts.
struct PresetSummaryScreenView: View {
    let config: InspectConfig.PresetSummaryScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: InspectState
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40 * scaleFactor)

            // Hero image
            if let heroPath = config.heroImage, !heroPath.isEmpty {
                IntroHeroImage(
                    path: heroPath,
                    shape: config.heroImageShape ?? "none",
                    size: config.heroImageSize ?? 120,
                    accentColor: highlightColor,
                    basePath: basePath
                )
                .padding(.bottom, 16 * scaleFactor)
            }

            // Title
            if let title = config.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 28 * scaleFactor, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scaleFactor)
            }

            // Subtitle
            if let subtitle = config.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scaleFactor)
                    .padding(.top, 6 * scaleFactor)
            }

            // Content area: bento grid or rich content
            if let cells = config.bentoCells, !cells.isEmpty {
                // Bento grid layout
                BentoGridView(
                    cells: cells,
                    columns: config.bentoColumns ?? 2,
                    rowHeight: CGFloat(config.bentoRowHeight ?? 120),
                    gap: CGFloat(config.bentoGap ?? 12),
                    scaleFactor: scaleFactor,
                    accentColor: highlightColor,
                    iconBasePath: basePath,
                    tintColor: nil,
                    inspectState: inspectState
                )
                .padding(.horizontal, 40 * scaleFactor)
                .padding(.top, 20 * scaleFactor)
            } else if let contentBlocks = config.content, !contentBlocks.isEmpty {
                // Rich content blocks
                ScrollView {
                    GuidanceContentView(
                        contentBlocks: contentBlocks,
                        scaleFactor: scaleFactor,
                        iconBasePath: basePath,
                        inspectState: inspectState,
                        itemId: "preset-summary-screen",
                        accentColor: highlightColor,
                        contentAlignment: .center
                    )
                    .padding(.horizontal, 40 * scaleFactor)
                }
                .padding(.top, 20 * scaleFactor)
            }

            Spacer()

            // Close button
            HStack {
                Spacer()
                Button(action: onClose) {
                    Text(config.buttonText ?? "Close")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(highlightColor)
            }
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.bottom, 24 * scaleFactor)
        }
    }
}
