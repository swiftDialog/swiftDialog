//
//  OnboardingFooter.swift
//  dialog
//
//  The onboarding footer bar shared by the phase container and Preset 3.
//

import SwiftUI

// MARK: - Footer

struct OnboardingFooter: View, InspectLayoutProtocol {
    @Environment(\.colorScheme) private var footerScheme
    /// Optional help control, seated first in the leading slot.
    @Environment(\.cardHeaderHelp) private var help
    @ObservedObject var inspectState: InspectState
    let accent: Color
    let showDetails: Bool
    var onButton1Action: (() -> Void)?
    let triggerFilePath: String

    private var allDone: Bool {
        !inspectState.trackedItems.isEmpty &&
        inspectState.trackedCompletedCount + inspectState.trackedFailedCount >= inspectState.trackedItems.count
    }

    private var hostLine: String { HostLine.current() }

    var body: some View {
        // The shared row, so intro and main phase show the same footer. `.over` paints the rule
        // on the band instead of shifting the row's contents.
        FooterRow(rail: FooterBandM.rail * scaleFactor, rule: .over,
                  fill: Color(NSColor.windowBackgroundColor).opacity(0.6)) {
            // `gate: .footer` keeps a corner-positioned mark out of the footer.
            if let path = BrandArtwork.resolve(inspectState.config?.logoConfig,
                                               isDark: footerScheme == .dark, gate: .footer) {
                FooterBrandSeat(path: path,
                                height: CGFloat(inspectState.config?.logoConfig?.maxHeight ?? 22),
                                clearSpace: inspectState.config?.logoConfig?.clearSpace ?? 0,
                                scale: scaleFactor, gap: 12)
            }
        } leading: {
            HStack(spacing: 12) {
            if let help {
                HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: accent,
                                action: help.action)
                    .preference(key: CardHeaderHelpSeatedKey.self, value: true)
            }
            if showDetails {
                HStack(spacing: 8) {
                    IconView(image: "computer")
                        .frame(width: 26 * scaleFactor, height: 26 * scaleFactor)
                    Text(hostLine)
                        .font(.system(size: 12 * scaleFactor, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .transition(.opacity)
            }
            }
        } trailing: {
            HStack(spacing: 12) {
                if !allDone, let footerText = inspectState.config?.footerText, !footerText.isEmpty {
                    Text(footerText)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
                PresetCommonViews.buttonArea(
                    state: inspectState,
                    tintColor: accent,
                    onButton1Action: onButton1Action,
                    config: inspectState.config,
                    triggerFilePath: triggerFilePath
                )
            }
        }
    }

}
