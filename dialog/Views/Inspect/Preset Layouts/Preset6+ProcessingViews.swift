//
//  Preset6+ProcessingViews.swift
//  dialog
//
//  Preset 6 extension: processing state view (countdown ring, override), result banner, completion view.
//

import SwiftUI

extension Preset6View {
    // MARK: - Processing State View

    @ViewBuilder
    func processingStateView(for item: InspectConfig.IntroStep) -> some View {
        // The step's own content blocks render above this view; only the ring column is drawn here.
        medallionColumn(for: item)
            .frame(maxWidth: .infinity)
            .padding(.vertical, metrics.topInset)
    }

    @ViewBuilder
    func medallionColumn(for item: InspectConfig.IntroStep) -> some View {
        VStack(spacing: metrics.sectionGap) {
            // The total comes from the processing state the countdown started with, not from the item.
            if case .countdown(_, let remaining, let total, _) = processingState {
                countdownRing(remaining: remaining, total: total)
            } else if case .waiting = processingState {
                IndeterminateRing(size: 36, color: highlightColor)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ChromeCopy.inProgress)
                    .padding()
                    .onTapGesture {
                        if currentOverrideLevel != .none {
                            showOverrideDialog = true
                        }
                    }
                    .help(currentOverrideLevel != .none ? "Click to override" : "Waiting for result…")
            }

            let rawMessage = localized("processingMessage", forItem: item, fallback: item.processingMessage) ?? "Processing..."
            let displayMessage: String = {
                if case .countdown(_, let remaining, _, _) = processingState {
                    return rawMessage.replacingOccurrences(of: "{countdown}", with: "\(remaining)")
                } else if case .waiting = processingState {
                    return rawMessage.replacingOccurrences(of: "{countdown}", with: "")
                        .replacingOccurrences(of: "  ", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                }
                return rawMessage
            }()
            if true {

                Text(displayMessage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Override option for long waits, shown at warning level and above.
            if currentOverrideLevel != .none, case .waiting = processingState {
                overrideBanner
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func countdownRing(remaining: Int, total: Int) -> some View {
        // labelSize is unscaled: the number stays 34 pt while the ring scales. The ring empties as time runs out.
        ProgressRing(
            fraction: CGFloat(max(0, remaining)) / CGFloat(max(1, total)),
            label: "\(max(0, remaining))",
            color: remaining <= 0 ? palette.warning : highlightColor,
            diameter: 104 * scaleFactor,
            labelSize: 34,
            animation: .linear(duration: 1.0),
            animationValue: remaining,
            unit: localizedProcessingText("secondsLeft", fallback: "seconds left")
        )
    }

    /// The long-wait state: explains the delay and offers options, each stating its consequence.
    @ViewBuilder
    var overrideBanner: some View {
        let waitTime = processingState.waitElapsed

        VStack(alignment: .leading, spacing: metrics.blockGap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(palette.warning)
                    .font(.system(size: 13))

                Text(localizedProcessingText(
                    "waitTimedOut",
                    fallback: "Still waiting after \(waitTime) seconds. Some settings haven't arrived yet."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(palette.warningBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(localizedProcessingText("yourOptions", fallback: "Your options").uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(palette.textFaint)

            optionRow(
                title: localizedProcessingText("keepWaitingTitle", fallback: "Wait another 60 seconds"),
                detail: localizedProcessingText("keepWaitingDetail",
                                                fallback: "Check again for another minute."),
                button: localizedProcessingText("keepWaiting", fallback: "Keep waiting"),
                prominent: true
            ) {
                // Restarts the same timer: elapsed goes back to zero and escalation starts again.
                if let stepId = processingState.stepId {
                    processingState = .waiting(stepId: stepId, waitElapsed: 0)
                }
            }

            optionRow(
                title: localizedProcessingText("skipTitle", fallback: "Continue without the pending items"),
                detail: localizedProcessingText("skipDetail",
                                                fallback: "You can continue now. This step is recorded as skipped."),
                button: localizedProcessingText("skipAndContinue", fallback: "Skip and continue"),
                prominent: false
            ) {
                showOverrideDialog = true
            }

            Text(localizedProcessingText("skipRecorded",
                                         fallback: "Skipping is recorded in the setup log."))
                .font(.system(size: 11))
                .foregroundStyle(palette.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func optionRow(title: String, detail: String, button: String,
                           prominent: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(button, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(prominent ? highlightColor : nil)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Result Banner

    @ViewBuilder
    func resultBanner(for item: InspectConfig.IntroStep) -> some View {
        let isCompleted = completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id)
        let hasFailed = failedSteps[item.id] != nil
        let wasSkipped = skippedSteps.contains(item.id)

        if isCompleted && !isProcessing {
            let sp = metrics
            let sizing = StepResultBanner.Sizing.inline(scale: scaleFactor, gap: sp.blockGap)
            if hasFailed {
                // Retry only the failed item; everything else the step applied stays applied.
                StepResultBanner(kind: .failure,
                                 title: localized("failureMessage", forItem: item, fallback: item.failureMessage)
                                     ?? ChromeCopy.stepFailed,
                                 detail: failedSteps[item.id], sizing: sizing,
                                 retryTitle: localizedProcessingText("tryAgain", fallback: ChromeCopy.tryAgain)) {
                    StepCompletion.reset(stepId: item.id, completed: &completedSteps, failed: &failedSteps,
                                         skipped: &skippedSteps, values: &inspectState.userValues)
                    inspectState.completedItems.remove(item.id)
                    startProcessing(for: item)
                }
            } else if wasSkipped {
                StepResultBanner(kind: .skipped,
                                 title: localizedProcessingText("stepSkipped", fallback: ChromeCopy.stepSkipped),
                                 sizing: sizing)
            } else if let successMessage = item.successMessage {
                StepResultBanner(kind: .success, title: successMessage, sizing: sizing, flat: true)
            }
        }
    }

    // MARK: - Completion View

    @ViewBuilder
    var completionView: some View {
        VStack(spacing: metrics.sectionGap) {
            Spacer()

            StatusIconView(.success, size: 60 * scaleFactor)

            Text(inspectState.config?.uiLabels?.completionMessage ?? "All Steps Complete")
                .font(.system(size: 24, weight: .bold))

            Text(inspectState.config?.uiLabels?.completionSubtitle ?? "Setup is complete.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
