//
//  Preset5+CardBento.swift
//  dialog
//
//  Preset 5's bento card arm: hero, summary and grid layouts inside the card shell.
//

import SwiftUI

extension Preset5View {
    /// The section gap from the token table; internal so the other card arm files can read it.
    var cardMetricsSectionGap: CGFloat { InspectMetrics.unit.sectionGap }

    // MARK: - Bento arm
    // grid wraps BentoFillGrid; hero/summary wrap BentoModule; `"split"` has no renderer and falls to grid.
    // Not `@ViewBuilder`: nested heterogeneous `_ConditionalContent` crashes the Swift runtime when SwiftUI
    // copies it, and erasing one arm does not help. Each arm returns its own `AnyView`; keep it that way.
    func cardBentoStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> AnyView {
        let continueText = localized("continueButtonText", forStep: step, fallback: nil)
            ?? step.continueButtonText ?? ChromeCopy.continue
        // The card shell draws the heading on every arm, so the module omits its own.
        let bentoConfig = BentoStepConfig(from: step, accentColor: branding.primaryColor,
                                          stance: stance(for: step),
                                          omitHeading: true)
        switch bentoConfig.layout {
        case "hero", "summary":
            // Logged once per process: this router runs on every body evaluation (`logBentoColumnsAdvisoryOnce`).
            logBentoColumnsAdvisoryOnce(layout: bentoConfig.layout,
                                        bentoColumns: step.bentoColumns)
            let kind: BentoArrangementKind = bentoConfig.layout == "summary" ? .heroColumn : .heroRow
            return AnyView(cardBentoHeroArm(step: step, stepIndex: stepIndex, kind: kind,
                                            continueText: continueText)
                .sourceTag())
        default:
            return AnyView(cardBentoGridArm(step: step, stepIndex: stepIndex,
                                            bentoConfig: bentoConfig,
                                            continueText: continueText)
                .sourceTag())
        }
    }

    /// hero/summary: the card shell around a `BentoModule` arrangement. A separate function keeps the
    /// router a flat `switch` of returns.
    private func cardBentoHeroArm(step: InspectConfig.IntroStep, stepIndex: Int,
                                  kind: BentoArrangementKind,
                                  continueText: String) -> some View {
        CardStepShell(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            hero: cardHero(step),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            footer: cardFooter(for: step, index: stepIndex,
                               continueText: continueText) { goToNextStep() }
        ) {
            // No ScrollView: BentoModule sizes cells from the container, which a scroll leaves unbounded.
            // AnyView is required: the shell's generic copy crashes on this payload without it.
            // Band insets are applied here, once for both arrangements. Without them the payload has 46 pt of
            // space above (`cardBodyTop`, sized for prose) and none below, since `CardFooterBar` has no top padding.
            // The top inset is negative: the band's top minus what the shell already spent (`bandTopAdjustment`).
            AnyView(BentoModule(
                cells: step.bentoCells ?? [],
                kind: kind,
                accent: branding.primaryColor,
                iconBasePath: effectiveIconBasePath,
                inspectState: inspectState,
                onAction: { cell in
                    // Label and itemId are used for logging and result-file rows.
                    handleRowAction(action: cell.action, url: cell.url,
                                    requestId: cell.requestId,
                                    label: cell.actionLabel ?? "",
                                    itemId: cell.id, inspectState: inspectState)
                }
            )
            .padding(.top, BentoHeroArrangement.bandTopAdjustment(
                shellInset: cardShellPayloadInset(for: step)))
            .padding(.bottom, BentoHeroArrangement.bandBottom))
        }
    }

    /// Process-lifetime latch for the `bentoColumns` advisory, like `topBandAdvisoryLogged`. `@State`
    /// would not work: the async insert loses to SwiftUI's double body evaluation at launch.
    static var bentoColumnsAdvisoryLogged = false

    /// Logs the advisory at most once per process; `BentoHeroArrangement.bentoColumnsAdvisory` stays pure.
    /// The latch is set only when an advisory exists, so a valid earlier step cannot silence a later one.
    private func logBentoColumnsAdvisoryOnce(layout: String, bentoColumns: Int?) {
        guard !Self.bentoColumnsAdvisoryLogged,
              let advisory = BentoHeroArrangement.bentoColumnsAdvisory(
                layout: layout, bentoColumns: bentoColumns) else { return }
        Self.bentoColumnsAdvisoryLogged = true
        writeLog(advisory, logLevel: .info)
    }

    /// The inset CardStepShell applies above the payload (`cardBandBodyTop` under a top band, else
    /// `cardBodyTop`), decided by the same `cardTopBandFor(step)` the shell uses.
    private func cardShellPayloadInset(for step: InspectConfig.IntroStep) -> CGFloat {
        return cardTopBandFor(step) != nil ? InspectMetrics.unit.cardBandBodyTop : InspectMetrics.unit.cardBodyTop
    }

    /// grid (default): the card shell around `BentoFillGrid`. Compact header row, every track 1fr, no
    /// overflow fade (the grid is sized to the band), standard card footer.
    private func cardBentoGridArm(step: InspectConfig.IntroStep, stepIndex: Int,
                                  bentoConfig: BentoStepConfig,
                                  continueText: String) -> some View {
        CardStepShell(
            bodyTopInset: BentoFillM.headerToGrid,
            compactHeader: true,
            fadesOverflow: false,
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            // Read for its advisories; the compact header draws no hero band.
            hero: cardHero(step),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            footer: cardFooter(for: step, index: stepIndex,
                               continueText: continueText) { goToNextStep() }
        ) {
            // No scroll shell: the grid sizes its rows from the band. AnyView is required: the shell's generic
            // copy of this payload can crash the Swift runtime without it.
            AnyView(BentoFillGrid(
                cells: bentoConfig.cells,
                columns: bentoConfig.columns,
                gap: bentoConfig.gap,
                accent: branding.primaryColor,
                iconBasePath: effectiveIconBasePath,
                tintColor: bentoConfig.tintColor,
                showSlots: bentoConfig.showSlots,
                inspectState: inspectState
            ))
        }
    }
}
