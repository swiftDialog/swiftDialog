//
//  IntroFooterView.swift
//  dialog
//
//  Footer for Preset 5's processing/completion steps and Preset 6's steps and outro, in `FooterRow`'s
//  slots: brand mark, step counter and claim, then the doors (deferral, back, skip, primary).

import SwiftUI

// MARK: - Footer View Component

/// The phase footer. Parameters are what each seat says and does; layout belongs to the band.
struct IntroFooterView: View {
    let footerText: String?
    /// Flow position, assembled by `StepCounter`; nil seats no counter.
    var stepCounter: StepCounter?
    let backButtonText: String
    let continueButtonText: String
    let accentColor: Color
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    let continueDisabled: Bool
    let skipButtonText: String?
    let onSkip: (() -> Void)?
    let inspectConfig: InspectConfig?
    let buttonControlSize: ControlSize
    let showDeferral: Bool

    // Declared in the body so it replaces the memberwise init; an extension init makes call sites ambiguous.
    init(
        footerText: String? = nil,
        backButtonText: String = "Back",
        continueButtonText: String = ChromeCopy.continue,
        accentColor: Color = .accentColor,
        showBackButton: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        continueDisabled: Bool = false,
        skipButtonText: String? = nil,
        onSkip: (() -> Void)? = nil,
        inspectConfig: InspectConfig? = nil,
        buttonControlSize: ControlSize = .large,
        showDeferral: Bool = true,
        stepCounter: StepCounter? = nil
    ) {
        self.footerText = footerText
        self.stepCounter = stepCounter
        self.backButtonText = backButtonText
        self.continueButtonText = continueButtonText
        self.accentColor = accentColor
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onContinue = onContinue
        self.continueDisabled = continueDisabled
        self.skipButtonText = skipButtonText
        self.onSkip = onSkip
        self.inspectConfig = inspectConfig
        self.buttonControlSize = buttonControlSize
        self.showDeferral = showDeferral
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.palette) private var palette
    /// The help control, seated first in the leading slot when the preset provides one.
    @Environment(\.cardHeaderHelp) private var help
    /// Where this step sits in the flow; gates the back button without each step threading it.
    @Environment(\.stepPosition) private var stepPosition

    /// Opts out of the flow-position gate (see `resolvedShowBackButton`). Substep pagers only;
    /// set through `managingOwnBackAffordance()`.
    private var managesOwnBackAffordance: Bool = false

    /// The authored `showBackButton` ANDed with the flow position (`stepPosition != .intro`).
    private var resolvedShowBackButton: Bool {
        // A substep pager's Back also goes to the previous substep, so it is real even on the first step.
        if managesOwnBackAffordance { return showBackButton }
        return showBackButton && stepPosition != .intro
    }

    /// The brand claim, drawn in one of two places depending on whether a step counter is seated.
    @ViewBuilder
    private var brandClaim: some View {
        if let footerText, !footerText.isEmpty {
            // 11.5pt muted, at most two lines; sizes come from `BrandSlotMetrics`. It wraps, never shrinks.
            OwnershipLine(text: footerText, ink: .secondary)
        }
    }

    /// The footer mark from the config (dark-aware, only when `position == .footer`).
    private var resolvedFooterLogoPath: String? {
        BrandArtwork.resolve(inspectConfig?.logoConfig,
                             isDark: colorScheme == .dark, gate: .footer)
    }

    /// The footer mark box: authored maxHeight, default 28, cap 88.
    private var footerLogoBox: BrandMarkBox {
        BrandMarkBox.fit(authored: inspectConfig?.logoConfig?.maxHeight, default: 28, cap: 88)
    }

    /// Opts out of the flow-position back gate. Substep pagers only; see `resolvedShowBackButton`.
    func managingOwnBackAffordance() -> Self {
        var copy = self
        copy.managesOwnBackAffordance = true
        return copy
    }

    /// The row's `gap` between the claim's span and the actions when a counter is seated.
    private static let claimToActionsGap: CGFloat = 24

    var body: some View {
        // A centred claim needs gap 0 so the centre is the span's centre.
        FooterRow(rail: FooterBandM.rail, rule: .none,
                  gap: stepCounter != nil ? Self.claimToActionsGap : (footerText != nil ? 0 : nil)) {
            if let logoPath = resolvedFooterLogoPath {
                BrandMark(path: logoPath, box: footerLogoBox,
                          clearSpace: inspectConfig?.logoConfig?.clearSpace ?? 0)
                    // `logoConfig.verticalOffset`, clamped to ±30pt (negative moves up).
                    .offset(y: max(-30, min(30, CGFloat(inspectConfig?.logoConfig?.verticalOffset ?? 0))))
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .padding(.trailing, 12)
            }
        } leading: {
            HStack(spacing: 12) {
                if let help {
                    HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: accentColor,
                                    action: help.action)
                        .preference(key: CardHeaderHelpSeatedKey.self, value: true)
                }
                // No counter: the claim centres between the mark and the doors.
                if stepCounter == nil, footerText != nil {
                    Spacer(minLength: 16)
                    brandClaim
                        .allowsHitTesting(false)
                    Spacer(minLength: 16)
                }
                // Rule, dots, then the count in words. The footer sets the tint so there is one accent.
                if let stepCounter {
                    stepCounter.tinted(accentColor)
                    // Spacers centre the claim between the counter and the actions.
                    Spacer(minLength: 16)
                    brandClaim
                        .allowsHitTesting(false)
                    Spacer(minLength: 16)
                }
            }
        } trailing: {
            HStack(spacing: 12) {
                if showDeferral && isDeferralEnabled(config: inspectConfig) {
                    DeferralMenuView(
                        config: inspectConfig,
                        accentColor: accentColor,
                        style: .bordered
                    )
                }
                if resolvedShowBackButton, let onBack = onBack {
                    Door.back(plate: .quaternary, ink: .secondary,
                              label: backButtonText, action: onBack)
                    .help(backButtonText)
                    .accessibilityLabel(backButtonText)
                }
                if let skipText = skipButtonText, let onSkip = onSkip {
                    Door.pill(buttonControlSize, label: skipText, action: onSkip)
                }
                // Shared primary: `.inspectButtonShape`, Return activates it, and `controlSize` is
                // passed explicitly because hosts resolve it differently (see `PrimaryActionButton.controlSize`).
                PrimaryActionButton(tint: accentColor,
                                    controlSize: buttonControlSize,
                                    action: onContinue) {
                    Text(continueButtonText)
                }
                .disabled(continueDisabled)
            }
        }
        .tint(accentColor)
    }
}

