//
//  Preset5+Showcase.swift
//  dialog
//
//  Preset5View's showcase step on the card contract (`ShowcaseStage`, `CardShowcaseView`).
//

import SwiftUI

extension Preset5View {

    // MARK: - Showcase Step View (Card Contract)

    /// The showcase step, rendered the same under every chrome; the stage is a fraction of the
    /// card, not a per-window layout.
    @ViewBuilder
    func cardShowcaseStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        // The live `set:heroImage:` override wins over the authored key.
        let hero = dynamicState.heroImageOverrides[step.id] ?? step.heroImage
        let heroMark = ShowcaseStage.mark(hero: hero)
        CardShowcaseView(
            model: CardShowcaseModel(
                title: localized("title", forStep: step, fallback: step.title),
                subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
                mark: heroMark.mark,
                artworkPath: heroMark.artwork,
                fill: ShowcaseStage.fill(heroBackground: step.heroBackgroundColor,
                                         stepGradient: step.showcaseGradientColors,
                                         configGradient: config?.gradientColors,
                                         brand: branding.primaryColor),
                stageFraction: ShowcaseStage.fraction(step.showcaseImageHeight),
                accent: branding.primaryColor,
                stepIndex: stepIndex,
                totalSteps: totalSteps,
                // No dots: the strip above states position.
                footer: cardFooter(for: step, index: stepIndex, dots: false,
                                   onContinue: { goToNextStep() })
            ),
            blocks: cardBlocks(step),
            inspectState: inspectState,
            iconBasePath: effectiveIconBasePath,
            stepId: step.id,
            scaleFactor: scaleFactor
        )
        .onAppear { showcaseIgnoredKeyAdvisory(step) }
        .sourceTag()
    }

    private static var warnedShowcaseKeyStepIds: Set<String> = []

    /// Logs the authored keys this route ignores, once per step id per session.
    private func showcaseIgnoredKeyAdvisory(_ step: InspectConfig.IntroStep) {
        let ignored = CardShowcaseAdvice.ignoredKeys(
            assistantImageHeight: step.assistantImageHeight,
            heroImageShape: step.heroImageShape,
            heroImageSize: step.heroImageSize,
            heroImagePadding: step.heroImagePadding,
            heroBadge: step.heroBadge,
            showProgressDots: step.showProgressDots,
            heroImageSFSymbolWeight: step.heroImageSFSymbolWeight,
            heroImageSFSymbolColor: step.heroImageSFSymbolColor,
            contentAnchor: step.contentAnchor,
            showcaseTextColor: step.showcaseTextColor)
        guard !ignored.isEmpty, !Self.warnedShowcaseKeyStepIds.contains(step.id) else { return }
        Self.warnedShowcaseKeyStepIds.insert(step.id)
        writeLog("showcase: \(ignored.joined(separator: ", ")) ignored on '\(step.id)' — one stage "
                 + "means one fraction (`showcaseImageHeight`; `assistantImageHeight` sized the "
                 + "vertical layout that no longer exists); the hero band is a fixed 88pt mark, "
                 + "not the legacy centred circle the geometry/badge/dots keys size, shape and "
                 + "overlay; the mark's weight (.thin) and colour are the measured render, "
                 + "fixed rather than authored, because the stage paints its own ground and an "
                 + "authored ink can draw the mark invisible on it; the card payload column owns "
                 + "its own content anchoring; and the overlay text colour is fixed the same way "
                 + "the mark's ink is.", logLevel: .info)
    }
}
