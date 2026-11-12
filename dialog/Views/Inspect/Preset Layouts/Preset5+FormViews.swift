//
//  Preset5+FormViews.swift
//  dialog
//
//  Preset5View's shared content container, fixed UI strings, corner help button and step info button.
//

import SwiftUI

extension Preset5View {

    // MARK: - Form Element Views

    /// Constrains content to `maxWidth` and aligns it in the column. Split steps pass `.leading`
    /// so hugging content (a button) lines up with a flush title.
    @ViewBuilder
    func centeredContentContainer<Content: View>(
        maxWidth: CGFloat = 480,
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    /// A fixed UI string (`ui.*` keys in the language files) with an English fallback; follows the
    /// resolved language without step gating.
    func localizedUI(_ key: String, fallback: String) -> String {
        localizationService.uiString(key, language: selectedLanguageCode, fallback: fallback)
    }

    // MARK: - Corner Help Button

    /// The help glyph on a screen with no card header to seat it (`CardHeaderHelp` is the seat
    /// when there is one). Opens the global detailOverlay. The 48pt tap box gives the corner
    /// logic a fixed size to place.
    @ViewBuilder
    func cornerHelpButton(config: InspectConfig.HelpButtonConfig) -> some View {
        // The bottom belongs to the step's actions, so a bottom corner resolves to the top on the
        // same side; a corner logo already on that side pushes help below it.
        let requested = config.position ?? "bottomRight"
        let onLeft = requested.lowercased().contains("left")
        let position = onLeft ? "topLeft" : "topRight"

        // Only a corner mark that is drawn holds the side.
        let logoCorner: String? = drawsCornerLogo
            ? (self.config?.logoConfig?.position?.lowercased() ?? "topright")
            : nil
        let logoSharesThisSide = logoCorner.map { $0.contains(onLeft ? "left" : "right") } ?? false
        // BrandedLogoView's own padding and height, plus 16pt of air.
        let logoBand = CGFloat(self.config?.logoConfig?.padding ?? 16)
            + CGFloat(self.config?.logoConfig?.maxHeight ?? 40) + 16
        let topInset = logoSharesThisSide ? logoBand : 24

        VStack {
            HStack {
                if !onLeft {
                    Spacer()
                }

                Button(action: {
                    HelpGlyphButton.logPress(config.tooltip ?? ChromeCopy.getHelp)
                    showGlobalHelpOverlay = true
                }) {
                    Image(systemName: config.icon ?? "questionmark.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(branding.primaryColor)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(config.tooltip ?? ChromeCopy.getHelp)
                // Otherwise the accessible name is the SF Symbol's.
                .accessibilityLabel(config.tooltip ?? ChromeCopy.getHelp)

                if onLeft {
                    Spacer()
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, topInset)
        .padding(.bottom, 24)
        .accessibilityIdentifier("helpButton.\(position)")
    }

    // MARK: - Step Info Button

    /// The per-step overlay trigger, shown when the step has a visible `stepOverlay`.
    @ViewBuilder
    func stepInfoButton(for step: InspectConfig.IntroStep) -> some View {
        if let overlayConfig = step.stepOverlay, overlayConfig.isShown {
            Button(action: {
                currentStepOverlayConfig = overlayConfig
                showStepOverlay = true
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("More information")
        }
    }

    /// The hero symbol colour: the step's override, else the brand accent.
    func heroImageColor(step: InspectConfig.IntroStep) -> Color {
        if let colorHex = step.heroImageSFSymbolColor {
            return Color(hex: colorHex)
        }
        return branding.accentColor
    }

    /// Maps an authored weight name to `Font.Weight`; unknown names are medium.
    func sfSymbolWeight(from string: String?) -> Font.Weight {
        switch string {
        case "bold": return .bold
        case "regular": return .regular
        default: return .medium
        }
    }
}
