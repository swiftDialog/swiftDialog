//
//  PresetPhaseViews.swift
//  dialog
//
//  Intro and summary screens for the Preset1/2 phase flow: each resolves its strings through the
//  sidecar and token pipeline, then hands them to `BookendScreenView`.
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
struct PresetIntroScreenView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetIntroScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: Context
    var userName: String?  // nil = no {userName} substitution
    var localize: ((String) -> String?)?  // sidecar lookup; nil = config strings as written
    // Pre-scale; P3 passes 28 so the action button holds one position across intro, main and outro.
    var footerHorizontalPadding: CGFloat?
    let onContinue: () -> Void

    private func locText(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        resolveLocalizedPhaseText(key: key, config: configValue, default: defaultText,
                                  localize: localize, userName: userName,
                                  itemCount: inspectState.items.count)
    }

    var body: some View {
        BookendScreenView(
            role: .intro,
            layout: config.layout ?? "centered",
            heroPath: config.heroImage,
            heroShape: config.heroImageShape ?? "none",
            heroSize: config.heroImageSize,
            title: locText("introScreen.title", config.title),
            subtitle: locText("introScreen.subtitle", config.subtitle),
            contentBlocks: config.content ?? [],
            accentColor: highlightColor,
            scaleFactor: scaleFactor,
            iconBasePath: basePath,
            itemId: "preset-intro-screen",
            inspectState: inspectState,
            intro: config,
            userName: userName,
            localize: localize,
            footerHorizontalPadding: footerHorizontalPadding,
            primaryButtonText: localizedPhaseValue("introScreen.buttonText", localize: localize,
                                                   config: config.buttonText, default: "Get Started") ?? "Get Started",
            onAction: onContinue
        )
    }
}

// MARK: - Summary Screen View

/// Full-screen summary/bento view shown after items complete in Preset1/2.
struct PresetSummaryScreenView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let config: InspectConfig.PresetSummaryScreen
    let highlightColor: Color
    let scaleFactor: CGFloat
    let basePath: String?
    @ObservedObject var inspectState: Context
    var userName: String?  // nil = no {userName} substitution
    var localize: ((String) -> String?)?  // sidecar lookup; nil = config strings as written
    var footerHorizontalPadding: CGFloat?  // pre-scale
    let onClose: () -> Void

    private func locText(_ key: String, _ configValue: String?, default defaultText: String? = nil) -> String? {
        resolveLocalizedPhaseText(key: key, config: configValue, default: defaultText,
                                  localize: localize, userName: userName,
                                  itemCount: inspectState.items.count)
    }

    var body: some View {
        BookendScreenView(
            role: .outro,
            layout: config.layout ?? "centered",
            heroPath: config.heroImage,
            heroShape: config.heroImageShape ?? "none",
            heroSize: config.heroImageSize,
            title: locText("summaryScreen.title", config.title),
            subtitle: locText("summaryScreen.subtitle", config.subtitle),
            contentBlocks: config.content ?? [],
            // Same grid defaults as the step and block arms, so one grid has one geometry.
            bento: config.bentoCells.map {
                BookendScreenView<Context>.BentoBody(
                    cells: $0,
                    columns: config.bentoColumns ?? 2,
                    rowHeight: CGFloat(config.bentoRowHeight ?? 140),
                    gap: CGFloat(config.bentoGap ?? 12)
                )
            },
            accentColor: highlightColor,
            scaleFactor: scaleFactor,
            iconBasePath: basePath,
            itemId: "preset-summary-screen",
            inspectState: inspectState,
            summary: config,
            userName: userName,
            localize: localize,
            footerHorizontalPadding: footerHorizontalPadding,
            primaryButtonText: localizedPhaseValue("summaryScreen.buttonText", localize: localize,
                                                   config: config.buttonText, default: "Close") ?? "Close",
            onAction: onClose
        )
    }
}
