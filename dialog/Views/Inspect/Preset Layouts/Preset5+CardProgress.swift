//
//  Preset5+CardProgress.swift
//  dialog
//
//  The progress arms: processing substeps with live monitoring, and the outro.
//

import SwiftUI

extension Preset5View {
    /// The processing card: one row per item with live status, or a single implicit row when
    /// the step has no items and waits on an external trigger.
    @ViewBuilder
    func cardProcessingStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let items = step.items ?? []
        let states: [CardSubstepState] = items.map { item in
            switch monitoringService.itemStatuses[item.id] ?? .pending {
            case .completed:  return .done
            case .active:     return .active
            case .failed:     return .failed
            case .pending:    return .pending
            // A skipped row is decided, so it counts as done, as in the progress accounting.
            case .skipped:    return .done
            }
        }
        let done = states.filter { $0 == .done }.count
        // Failed beats done: the engine records failed steps in completedProcessingSteps too.
        let stepFailed = failedSteps[step.id] != nil
        let stepDone = completedProcessingSteps.contains(step.id) && !stepFailed
        let allCompleted = items.isEmpty ? stepDone : done == items.count
        // Continue unlocks once every row has an outcome; auto-advance still waits for allCompleted.
        let allFinished = items.isEmpty ? (stepDone || stepFailed)
                                        : states.allSatisfy { $0 == .done || $0 == .failed }
        let title = localized("title", forStep: step, fallback: step.title) ?? ""
        let substeps: [(state: CardSubstepState, label: String)] = items.isEmpty
            ? [(stepDone ? .done : (stepFailed ? .failed : .active),
                localized("processingMessage", forStep: step,
                          fallback: step.processingMessage) ?? title)]
            : items.indices.map { (states[$0], items[$0].displayName) }
        // The override escalation (allowOverride + waiting-time tiers) opens the override picker.
        let showEscape = (step.allowOverride ?? false) && !stepDone && !stepFailed
            && (currentOverrideLevel == .small || currentOverrideLevel == .large)
        cardScreen(model: CardStepModel(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: title,
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            progress: items.isEmpty ? (stepDone ? 1.0 : nil)
                                    : Double(done) / Double(items.count),
            substeps: substeps,
            escape: showEscape ? RailEscapeModel(
                headline: localized("ui.overrideTitle", forStep: step,
                                    fallback: nil) ?? "Waiting longer than expected",
                consequence: localized("ui.overrideDescription", forStep: step, fallback: nil)
                    ?? "You can decide whether this step passed, failed, or should be skipped.",
                skipText: localized("ui.overrideButton", forStep: step,
                                    fallback: step.overrideButtonText) ?? "Override This Step",
                onSkip: {
                    // The picker resolves its step via pendingOverrideStepIndex.
                    pendingOverrideStepIndex = stepIndex
                    showOverridePicker = true
                }
            ) : (stepFailed && items.isEmpty ? RailEscapeModel(
                // Only an itemless step is retried whole; rows fail per row.
                headline: failedSteps[step.id] ?? ChromeCopy.stepFailed,
                consequence: "",
                skipText: localized("ui.tryAgain", forStep: step, fallback: nil) ?? ChromeCopy.tryAgain,
                onSkip: { retryProcessing(step: step, stepIndex: stepIndex) }
            ) : nil),
            panel: localizedCardPanel(step),
            // No back on a processing step; a failed row unlocks the primary without auto-advance.
            footer: cardFooter(for: step, index: stepIndex, showBack: false,
                               continueDisabled: !allFinished) {
                goToNextStep()
            }
        ), stepId: step.id)
        .onAppear {
            if !items.isEmpty {
                startInstallationMonitoring(for: step)
            } else if step.processingDuration != nil, !stepDone {
                // The countdown drives waitElapsed and the override escalation.
                startProcessingCountdown(for: step, stepIndex: stepIndex)
            }
        }
        .onChange(of: allCompleted) { _, completed in
            if completed && (step.autoAdvance ?? false) { goToNextStep() }
        }
        .overlay {
            if showOverridePicker {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showOverridePicker = false }
                    overridePickerSheet()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showOverridePicker)
        .sourceTag()
    }

    /// The outro card: badge, receipt, footnote instead of dots. Failed steps are listed and
    /// make the badge red.
    @ViewBuilder
    func cardOutroStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let failures: [(label: String, detail: String?)] = allSteps.compactMap { other in
            guard let reason = failedSteps[other.id] else { return nil }
            return (localized("title", forStep: other, fallback: other.title) ?? other.id, reason)
        }
        cardScreen(model: CardStepModel(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            titleBadge: true,
            titleBadgeFailed: !failures.isEmpty,
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            blocks: cardBlocks(step),
            failures: failures,
            // Receipt values read live selections, not the config's proposals.
            receipt: CardReceipt.rows(step.receipt ?? [],
                                      label: { localized("receipt.\($0.stepId).label", forStep: step,
                                                         fallback: $0.label) ?? $0.label },
                                      value: { receiptValue(for: $0) }),
            receiptChangeLabel: localizedUI("receiptChange", fallback: "Change"),
            onReceiptChange: { navigateToStep(stepId: $0) },
            recap: step.showCadenceRecap == true ? cadenceRecapModel() : nil,
            panel: localizedCardPanel(step),
            // The flow is over: no position, no back, and "Done" is the default label.
            footer: cardFooter(for: step, index: stepIndex, dots: false, showBack: false,
                               continueText: localized("continueButtonText", forStep: step,
                                                       fallback: step.continueButtonText) ?? ChromeCopy.done,
                               footnote: localized("footerNote", forStep: step, fallback: step.footerNote)) {
                goToNextStep()
            }
        ), stepId: step.id)
        // No hero here, so the ignored-key advisory is called directly.
        .onAppear { cardIgnoredKeyAdvisory(step) }
        .sourceTag()
    }

}
