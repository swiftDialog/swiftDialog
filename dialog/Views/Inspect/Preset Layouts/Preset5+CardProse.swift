//
//  Preset5+CardProse.swift
//  dialog
//
//  The prose arm: intro / guide / assistant / standard, with screens[] sub-paging,
//  receipt, recap and the auto-advance monitor.
//

import SwiftUI

extension Preset5View {
    /// The intro and guide cards. With `screens`, the header holds still while each screen
    /// brings its own title, blocks and panel, paged from the action bar.
    @ViewBuilder
    func cardIntroStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let flowBack = canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? true)
        let screens = step.screens ?? []
        let subIndex = screens.isEmpty ? 0
            : min(max(0, inspectState.cardSubStepIndex[step.id] ?? 0), screens.count - 1)
        let sub: InspectConfig.IntroStep.CardScreen? = screens.isEmpty ? nil : screens[subIndex]
        let isLastSub = subIndex >= screens.count - 1
        let canBack = flowBack || subIndex > 0
        cardScreen(model: CardStepModel(
            // An authored step eyebrow wins over the flow title (3.1.1's `guideStepBadge` arrives here).
            eyebrow: localized("eyebrow", forStep: step, fallback: step.eyebrow) ?? config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            // Sub-screens carry no hero and no step overlay.
            hero: sub == nil ? cardHero(step) : nil,
            title: sub.map { $0.title ?? step.title ?? "" }
                ?? localized("title", forStep: step, fallback: step.title) ?? "",
            onTitleInfo: (sub == nil && step.stepOverlay?.isShown == true) ? { [self] in
                currentStepOverlayConfig = step.stepOverlay
                showStepOverlay = true
            } : nil,
            subtitle: sub.map(\.subtitle)
                ?? localized("subtitle", forStep: step, fallback: step.subtitle),
            blocks: sub.map { $0.content ?? [] } ?? cardBlocks(step),
            // A receipt may be authored on any step, not only the outro.
            receipt: sub == nil ? CardReceipt.rows(step.receipt ?? [],
                                                   label: { localized("receipt.\($0.stepId).label",
                                                                      forStep: step,
                                                                      fallback: $0.label) ?? $0.label },
                                                   value: { receiptValue(for: $0) }) : [],
            receiptChangeLabel: localizedUI("receiptChange", fallback: "Change"),
            onReceiptChange: { navigateToStep(stepId: $0) },
            // The recap renders nothing unless a cadence run completed in this launch.
            recap: (sub == nil && step.showCadenceRecap == true) ? cadenceRecapModel() : nil,
            panel: sub.map(\.cardPanel) ?? selectAwareCardPanel(step),
            // Back walks screens[] before it leaves the step, so the gate is the sub-flow's.
            footer: cardFooter(
                for: step, index: stepIndex,
                showBack: canBack,
                // Only a screen's own label is passed; the step's label is cardFooter's default.
                continueText: sub?.continueButtonText,
                // Required-field gating, as on the standard intro step; the guide picker holds Finish.
                continueDisabled: standardContinueDisabled(step: step)
                    || (isLastSub && stepIndex >= allSteps.count - 1 && !guidePickerAllowsFinish),
                // The step's footer line (3.1.1's `footerLink` arrives here), as on the card progress step.
                footnote: localized("footerNote", forStep: step, fallback: step.footerNote),
                // A selectable guide step seats Select in the secondary slot unless it authors its own.
                secondaryText: localized("secondaryButtonText", forStep: step,
                                         fallback: step.secondaryButtonText)
                    ?? (isGuidePickable(step)
                        ? (guideSelections.contains(step.id) ? localizedUI("guideSelected", fallback: "✓ Selected")
                                                             : localizedUI("guideSelect", fallback: "Select"))
                        : nil),
                onSecondary: step.secondaryButtonText == nil
                    ? (isGuidePickable(step) ? { [self] in toggleGuideSelection(step) } : nil)
                    : { [self] in
                    if step.secondaryAction?.lowercased() == "next" { goToNextStep() } else { goToPreviousStep() }
                },
                subStepper: screens.count > 1 ? CardSubStepperModel(
                    current: subIndex,
                    total: screens.count,
                    onPrev: subIndex > 0
                        ? { inspectState.cardSubStepIndex[step.id] = subIndex - 1 } : nil,
                    onNext: !isLastSub
                        ? { inspectState.cardSubStepIndex[step.id] = subIndex + 1 } : nil
                ) : nil,
                onBack: {
                    if subIndex > 0 { inspectState.cardSubStepIndex[step.id] = subIndex - 1 } else { goToPreviousStep() }
                }
            ) {
                openCardContinueActionURL(sub?.continueAction ?? step.continueAction)
                if isLastSub {
                    inspectState.cardSubStepIndex[step.id] = 0
                    goToNextStep()
                } else {
                    inspectState.cardSubStepIndex[step.id] = subIndex + 1
                }
            }
        ), stepId: step.id)
        .onAppear {
            initializeFormDefaults(for: step)
            // Start only: the monitor is shared across steps, and stopping on disappear would
            // cancel the incoming step's timer.
            introStepMonitor.startMonitoring(step: step) { [self] triggerStepId, result in
                guard step.requireManualConfirm != true else {
                    writeLog("Preset5 card: completion trigger for '\(triggerStepId)' ignored — "
                             + "requireManualConfirm=true", logLevel: .debug)
                    return
                }
                guard step.autoAdvanceOnComplete == true else {
                    writeLog("Preset5 card: completion trigger for '\(triggerStepId)' ignored — "
                             + "autoAdvanceOnComplete is not enabled", logLevel: .debug)
                    return
                }
                if case .success = result {
                    writeLog("Preset5 card: auto-advancing from '\(triggerStepId)' on completion trigger",
                             logLevel: .info)
                    goToNextStep()
                }
            }
        }
        .sourceTag()
    }
}
