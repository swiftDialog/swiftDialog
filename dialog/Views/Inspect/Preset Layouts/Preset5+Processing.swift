//
//  Preset5+Processing.swift
//  dialog
//
//  Preset 5 extension: processing steps (countdown ring, result banners, override escalation, timers).
//

import SwiftUI

extension Preset5View {

    /// Processing step: a countdown while running, then a result banner and Continue.
    @ViewBuilder
    func processingStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let backText = BackDoor.label(localized: localized("backButtonText", forStep: step, fallback: nil),
                                    step: step.backButtonText, branding: branding.button2Text)
        let isCompleted = completedProcessingSteps.contains(step.id)
        let hasFailed = failedSteps[step.id] != nil

        VStack(spacing: 0) {
            // Banded mode (see StepAnchor.bands): hero, title and subtitle in a fixed 184 pt header band,
            // the rest centred below. Horizontal padding stays outside the shell.
            AnchoredStepContent(
                bands: metrics,
                alignment: stance(for: step).align,
                horizontalPadding: stance(for: step).isLeading ? metrics.contentPadH : 0
            ) {
                // The header takes its alignment from the stance, like the payload, so both share one grid.
                VStack(alignment: stance(for: step).align, spacing: metrics.sectionGap) {
                        if let heroImage = dynamicState.heroImageOverrides[step.id] ?? step.heroImage {
                            IntroHeroImage(
                                path: heroImage,
                                shape: step.heroImageShape ?? "none",
                                // 64 pt, overriding an authored heroImageSize so the band holds.
                                size: StepBandMetrics.hero,
                                accentColor: heroImageColor(step: step),
                                sfSymbolColor: step.heroImageSFSymbolColor.map { Color(hex: $0) },
                                sfSymbolWeight: sfSymbolWeight(from: step.heroImageSFSymbolWeight),
                                basePath: effectiveIconBasePath,
                                padding: step.heroImagePadding
                            )
                        }

                        // Stance alignment: a short subtitle is placed by its parent, not by `multilineTextAlignment`.
                        VStack(alignment: stance(for: step).align, spacing: metrics.titleSubtitle) {
                            if let title = localized("title", forStep: step, fallback: step.title) {
                                Text(title)
                                    .font(metrics.stepTitle)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(stance(for: step).textAlignment)
                            }

                            if let subtitle = localized("subtitle", forStep: step, fallback: step.subtitle) {
                                Text(subtitle)
                                    .font(metrics.stepSubtitle)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(stance(for: step).textAlignment)
                            }
                        }
                        .frame(maxWidth: metrics.contentMaxW,
                               alignment: stance(for: step).frameAlignment)
                }
            } payload: {
                // Stance alignment also places the ring, banner and override buttons.
                VStack(alignment: stance(for: step).align, spacing: metrics.sectionGap) {
                        if let content = step.content {
                            VStack(spacing: metrics.blockGap) {
                                ForEach(content.indices, id: \.self) { index in
                                    let block = localizedContentBlock(content[index], stepId: step.id, blockIndex: index)
                                    introContentBlock(block, blockIndex: index)
                                }
                            }
                            // No .id: the step root is already keyed per step, and dynamic state re-renders through
                            // observation.
                        }

                        if isCompleted {
                            processingResultBanner(for: step, stepIndex: stepIndex, hasFailed: hasFailed)
                        } else if step.waitForExternalTrigger != true {
                            // Countdown ring and message (not used with an external trigger).
                            countdownRing(for: step)

                            // Processing message with {countdown} substituted.
                            if let message = step.processingMessage {
                                let displayMessage = message.replacingOccurrences(
                                    of: "{countdown}",
                                    with: "\(processingCountdown)"
                                )
                                Text(displayMessage)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(stance(for: step).textAlignment)
                            }

                            overrideButtons(for: step, stepIndex: stepIndex)
                        }
                }
            }
            .padding(.horizontal, metrics.contentPadH)

            // Continue appears once completed.
            IntroFooterView(
                footerText: footerClaim,
                backButtonText: backText,
                continueButtonText: isCompleted ? (hasFailed ? ChromeCopy.continueAnyway : (localized("continueButtonText", forStep: step, fallback: nil) ?? step.continueButtonText ?? ChromeCopy.continue)) : (localized("actionButtonText", forStep: step, fallback: nil) ?? step.actionButtonText ?? "Processing\u{2026}"),
                accentColor: branding.primaryColor,
                // Back must be possible (`canGoBack`) and authored. The default here is `false`, unlike other read
                // sites, because work is running.
                showBackButton: canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? false),
                onBack: { stopProcessingCountdown(); goToPreviousStep() },
                onContinue: { goToNextStep() },
                continueDisabled: !isCompleted,  // enabled only once completed
                inspectConfig: config,
                buttonControlSize: metrics.buttonControlSize,
            )
        }
        .onAppear {
            if !completedProcessingSteps.contains(step.id) {
                // Scripts watch stdout for this line.
                print("[PRESET11_PROCESSING] step_started: \(step.id)")
                writeLog("Preset5: Processing step started: '\(step.id)'", logLevel: .info)

                startProcessingCountdown(for: step, stepIndex: stepIndex)

                // Completion comes from IPC only; path monitoring is not started here.

                // Plist monitoring lets external processes signal completion, as on Preset 6.
                introStepMonitor.startMonitoring(step: step) { [self] triggerStepId, triggerResult in
                    writeLog("Preset5: Plist monitor triggered for processing step '\(triggerStepId)' with result: \(triggerResult)", logLevel: .info)
                    let completionResult: CompletionResult
                    switch triggerResult {
                    case .success(let message):
                        completionResult = .success(message: message)
                    case .failure(let message):
                        completionResult = .failure(message: message)
                    }
                    handleCompletionTrigger(stepId: triggerStepId, result: completionResult)
                }
            }
        }
        .onDisappear {
            stopProcessingCountdown()
            introStepMonitor.stopMonitoring()
        }
        .overlay {
            if showOverridePicker {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showOverridePicker = false
                        }

                    overridePickerSheet()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showOverridePicker)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .sourceTag()
    }

    /// Result banner after processing completes (success, failure or skipped).
    @ViewBuilder
    func processingResultBanner(for step: InspectConfig.IntroStep, stepIndex: Int, hasFailed: Bool) -> some View {
        if hasFailed {
            StepResultBanner(kind: .failure,
                             title: localized("failureMessage", forStep: step, fallback: step.failureMessage)
                                 ?? ChromeCopy.stepFailed,
                             detail: failedSteps[step.id],
                             retryTitle: localized("ui.tryAgain", forStep: step, fallback: nil) ?? ChromeCopy.tryAgain,
                             onRetry: { retryProcessing(step: step, stepIndex: stepIndex) })
                .padding(.horizontal, 20)
        } else if skippedSteps.contains(step.id) {
            StepResultBanner(kind: .skipped, title: localized("stepSkipped", forStep: step, fallback: nil)
                                 ?? ChromeCopy.stepSkipped)
                .padding(.horizontal, 20)
        } else {
            StepResultBanner(kind: .success,
                             title: localized("successMessage", forStep: step, fallback: step.successMessage)
                                 ?? ChromeCopy.stepCompleted)
                .padding(.horizontal, 20)
        }
    }

    /// Retries a failed step, as on Preset 6: clears its outcome and result (`StepCompletion.reset`) and restarts it.
    func retryProcessing(step: InspectConfig.IntroStep, stepIndex: Int) {
        StepCompletion.reset(stepId: step.id, completed: &completedProcessingSteps, failed: &failedSteps,
                             skipped: &skippedSteps, values: &inspectState.userValues)
        writeLog("Preset5: Retrying processing step '\(step.id)'", logLevel: .info)
        startProcessingCountdown(for: step, stepIndex: stepIndex)
    }

    /// Countdown ring for processing steps.
    @ViewBuilder
    func countdownRing(for step: InspectConfig.IntroStep) -> some View {
        // `duration` is the total the running countdown started with, not `step.processingDuration`.
        if case .countdown(_, let remaining, let duration, _) = processingState {
            let text = Self.countdownLabel(remaining: max(0, remaining), duration: duration)
            ProgressRing(
                fraction: CGFloat(remaining) / CGFloat(duration),
                label: text,
                color: branding.primaryColor,
                labelSize: Self.countdownLabelSize(for: text),
                animation: .linear(duration: 1.0),
                animationValue: remaining
            )
            .padding(.vertical, 16)
        } else if case .waiting = processingState {
            IndeterminateRing(size: 36, color: branding.primaryColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ChromeCopy.inProgress)
                .padding(.vertical, 32)
        } else if let duration = step.processingDuration, duration > 0 {
            // Before the countdown starts: a full static ring with the authored duration. No duration, no ring,
            // as in `startProcessingCountdown`.
            let text = Self.countdownLabel(remaining: duration, duration: duration)
            ProgressRing(
                fraction: 1.0,
                label: text,
                color: branding.primaryColor,
                labelSize: Self.countdownLabelSize(for: text)
            )
            .padding(.vertical, 16)
        }
    }

    /// The countdown's centre label: raw seconds under a minute, `m:ss` from a minute up. Chosen from the
    /// authored duration, not `remaining`, so the format never changes mid-count.
    static func countdownLabel(remaining: Int, duration: Int) -> String {
        guard duration >= 60 else { return "\(remaining)" }
        return "\(remaining / 60):" + String(format: "%02d", remaining % 60)
    }

    /// `ProgressRing` label size that fits the ring. Estimated (digits ~0.55 em, colon ~0.30 em,
    /// 72% of the diameter usable) rather than measured, to avoid a layout pass per tick.
    static func countdownLabelSize(for text: String, diameter: CGFloat = 100) -> CGFloat {
        let base: CGFloat = 48
        let ems = 0.55 * CGFloat(text.filter(\.isNumber).count)
                + 0.30 * CGFloat(text.filter { $0 == ":" }.count)
        guard ems > 0 else { return base }
        return min(base, (diameter * 0.72) / ems)
    }

    /// Warning banner shown during long waits, as on Preset 6.
    @ViewBuilder
    func warningLevelBanner() -> some View {
        if case .warning = currentOverrideLevel {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.warning)

                Text("This step is taking longer than expected…")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(palette.warningBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.warning.opacity(0.3), lineWidth: 1)
            )
            .padding(.top, 8)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    /// Override buttons for processing steps, escalating by the shared OverrideLevel.
    @ViewBuilder
    func overrideButtons(for step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let allowOverride = step.allowOverride ?? false
        let overrideText = step.overrideButtonText ?? ChromeCopy.skip

        if allowOverride {
            VStack(spacing: 8) {
                // Warning banner at the .warning level (10–15 s).
                warningLevelBanner()

                Group {
                    switch currentOverrideLevel {
                    case .large:
                        // Large override button (60 s and up).
                        Button(action: {
                            pendingOverrideStepIndex = stepIndex
                            showOverridePicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.forward.circle.fill")
                                    .font(.system(size: 14))
                                Text(overrideText)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(palette.warning)
                            .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                    case .small:
                        // Small override link (15–60 s).
                        Button(action: {
                            pendingOverrideStepIndex = stepIndex
                            showOverridePicker = true
                        }) {
                            Text(overrideText)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.warning)
                                .underline()
                        }
                        .buttonStyle(.plain)

                    case .warning:
                        // Warning level (10–15 s): the banner only.
                        EmptyView()

                    case .none:
                        // No override yet (0–10 s).
                        EmptyView()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentOverrideLevel)
            .padding(.top, 8)
        }
    }

    /// Localized override-picker copy: `<stepId>.ui.<key>`, the same keys as Preset 6's override sheet.
    func overridePickerText(_ key: String, fallback: String) -> String {
        guard let step = allSteps[safe: pendingOverrideStepIndex] else { return fallback }
        return localized("ui.\(key)", forStep: step, fallback: nil) ?? fallback
    }

    /// Override result picker sheet.
    @ViewBuilder
    func overridePickerSheet() -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(palette.warning)

                Text(overridePickerText("overrideTitle", fallback: "Skip this step?"))
                    .font(.system(size: 18, weight: .semibold))

                Text(overridePickerText("overrideDescription", fallback: "Choose how to record this step's result"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()

            VStack(spacing: 12) {
                Button(action: {
                    let step = allSteps[safe: pendingOverrideStepIndex]
                    let stepId = step?.id ?? "unknown"
                    lastOverrideResult = "success"
                    lastOverrideStepId = stepId
                    // Available to templates.
                    inspectState.userValues["overrideResult"] = "success"
                    inspectState.userValues["overrideStepId"] = stepId
                    showOverridePicker = false
                    stopProcessingCountdown()
                    // Completed with success; the user clicks Continue to advance.
                    if let step = step {
                        markProcessingCompleted(step: step, result: .success, confirmed: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.success)
                        Text(overridePickerText("markSuccess", fallback: "Mark as completed"))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.successBackground)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    let step = allSteps[safe: pendingOverrideStepIndex]
                    let stepId = step?.id ?? "unknown"
                    lastOverrideResult = "failed"
                    lastOverrideStepId = stepId
                    inspectState.userValues["overrideResult"] = "failed"
                    inspectState.userValues["overrideStepId"] = stepId
                    showOverridePicker = false
                    stopProcessingCountdown()
                    // Completed with failure; the user clicks Continue Anyway to advance.
                    if let step = step {
                        markProcessingCompleted(step: step, result: .failure(reason: step.failureMessage ?? overridePickerText("markedFailed", fallback: "Marked as failed by user")), confirmed: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.error)
                        Text(overridePickerText("markFailed", fallback: "Mark as failed"))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.errorBackground)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    let step = allSteps[safe: pendingOverrideStepIndex]
                    showOverridePicker = false
                    stopProcessingCountdown()
                    // Skipped; the user clicks Continue to advance.
                    if let step = step {
                        markProcessingCompleted(step: step, result: .skipped, confirmed: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "forward.fill")
                            .foregroundStyle(palette.warning)
                        Text(overridePickerText("skipStep", fallback: "Skip without a result"))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.warningBackground)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Divider()

            Button(action: {
                showOverridePicker = false
            }) {
                Text(overridePickerText("cancelButton", fallback: "Cancel"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(radius: 20)
    }

    /// Starts the countdown for a processing step.
    func startProcessingCountdown(for step: InspectConfig.IntroStep, stepIndex: Int) {
        // What the step does on start (`ProcessingFlow`): complete, wait, or count down.
        let duration: Int
        switch ProcessingFlow.start(step) {
        case .wait:
            // The waiting clock drives the override, so a step whose script never reports still has a way out.
            processingWaitElapsed = 0
            processingState = .waiting(stepId: step.id, waitElapsed: 0)
            writeLog("Preset5: Processing step '\(step.id)' waiting for external trigger (no countdown)", logLevel: .info)
            startWaitingTimer(for: step, stepIndex: stepIndex)
            return
        case .completeNow(let result):
            handleCompletionTrigger(stepId: step.id, result: result)
            return
        case .countdown(let seconds):
            duration = seconds
        }

        let hasWaitForTrigger = step.waitForExternalTrigger == true
        let mode = step.processingMode ?? "simple"

        if mode == "progressive" && !hasWaitForTrigger && step.autoResult == nil {
            writeLog("⚠️  WARNING: Step '\(step.id)' has processingMode='progressive' but waitForExternalTrigger is not set.", logLevel: .error)
            writeLog("    Step may complete unexpectedly. Recommended: Add \"waitForExternalTrigger\": true to config.", logLevel: .error)
        }

        processingCountdown = duration
        processingWaitElapsed = 0  // for override escalation
        processingState = .countdown(stepId: step.id, remaining: duration, total: duration, waitElapsed: 0)

        // The step is re-read when the clock fires: `IntroStep` is not `Sendable`, and steps may be replaced mid-run.
        let clock = Countdown(seconds: duration)
        processingClock = clock
        clock.start(onTick: { [self] remaining in
            processingWaitElapsed += 1
            if case .countdown(let stepId, _, let total, let elapsed) = processingState, remaining > 0 {
                processingCountdown = remaining
                processingState = .countdown(stepId: stepId, remaining: remaining, total: total, waitElapsed: elapsed + 1)
            } else if case .waiting(let stepId, let waitElapsed) = processingState {
                processingState = .waiting(stepId: stepId, waitElapsed: waitElapsed + 1)
            }
        }, onFire: { [self, stepID = step.id] in
            processingClock = nil
            processingCountdown = 0
            // Look up in `allSteps` by id; Preset 5 never populates `inspectState.steps`.
            guard let step = allSteps.first(where: { $0.id == stepID }) else {
                writeLog("Preset5: countdown fired for step '\(stepID)' but it is no longer in the flow — idling", logLevel: .error)
                processingState = .idle
                return
            }
            guard case .countdown(let stepId, _, _, _) = processingState else {
                processingState = .idle
                markProcessingCompleted(step: step, result: .success)
                return
            }
            // Scripts watch stdout for this line.
            print("[PRESET11_PROCESSING] countdown_complete: \(stepId)")
            writeLog("Preset5: Countdown complete for step '\(stepId)'", logLevel: .info)

            // What the end of the countdown means (`ProcessingFlow`): wait for a trigger, or the
            // step's own result.
            switch ProcessingFlow.afterCountdown(step) {
            case .wait:
                processingState = .waiting(stepId: stepId, waitElapsed: 0)
                writeLog("Preset5: Step '\(stepId)' transitioned to waiting state (waitForExternalTrigger=\(step.waitForExternalTrigger == true), progressive=\(step.processingMode == "progressive"))", logLevel: .info)
                startWaitingTimer(for: step, stepIndex: stepIndex)
            case .complete(let result):
                // Without waitForExternalTrigger, complete immediately.
                processingState = .idle
                handleCompletionTrigger(stepId: step.id, result: result)

                // Auto-advance only when requested.
                if step.autoAdvance == true && step.requireManualConfirm != true {
                    scheduleAutoAdvance(after: 0.8, from: step.id)
                }
            }
        })
    }
}
