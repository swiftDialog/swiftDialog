//
//  Preset6+Processing.swift
//  dialog
//
//  Preset 6 extension: processing steps (countdown and wait timers, completion triggers, external completions).
//

import SwiftUI

extension Preset6View {
    // MARK: - Processing

    func startProcessing(for item: InspectConfig.IntroStep) {
        // What the step does on start (`ProcessingFlow`): complete, wait, or count down.
        let duration: Int
        switch ProcessingFlow.start(item) {
        case .completeNow(let result):
            handleCompletionTrigger(stepId: item.id, result: result)
            return
        case .wait:
            processingState = .waiting(stepId: item.id, waitElapsed: 0)
            writeLog("Preset6: Processing step '\(item.id)' waiting for external trigger (no countdown)", logLevel: .info)
            startWaitingTimer(for: item)
            return
        case .countdown(let seconds):
            duration = seconds
        }

        processingCountdown = duration
        processingState = .countdown(stepId: item.id, remaining: duration, total: duration, waitElapsed: 0)

        // Scripts watch stdout for this line.
        print("[PRESET6_PROCESSING] step_started: \(item.id)")
        writeLog("Preset6: Processing started for step '\(item.id)'", logLevel: .info)
        writeInteractionLog("processing_started", step: item.id, data: ["duration": duration])
        logPreset6Event("processing_started", details: [
            "stepId": item.id,
            "duration": duration,
            "waitForTrigger": item.waitForExternalTrigger ?? false
        ])

        // The step is re-read by id when the clock fires; `IntroStep` is not `Sendable`.
        let clock = Countdown(seconds: duration)
        processingClock = clock
        clock.start(onTick: { [self] remaining in
            if case .countdown(let stepId, _, let total, let elapsed) = processingState, remaining > 0 {
                processingCountdown = remaining
                processingState = .countdown(stepId: stepId, remaining: remaining, total: total, waitElapsed: elapsed + 1)
            }
        }, onFire: { [self, itemId = item.id] in
            processingClock = nil
            guard let item = inspectState.steps.first(where: { $0.id == itemId }),
                  case .countdown(let stepId, _, _, _) = processingState else { return }

            // What the end of the countdown means (`ProcessingFlow`): wait, or the step's result.
            switch ProcessingFlow.afterCountdown(item) {
            case .wait:
                processingState = .waiting(stepId: stepId, waitElapsed: 0)
                startWaitingTimer(for: item)
            case .complete(let result):
                handleCompletionTrigger(stepId: stepId, result: result)
            }
        })
    }

    func startWaitingTimer(for item: InspectConfig.IntroStep) {
        processingClock?.cancel()
        processingClock = nil

        writeLog("Preset6: Starting waiting timer for step '\(item.id)'", logLevel: .debug)

        let clock = Poll(every: 1)
        processingClock = clock
        clock.start { [self] in
            if case .waiting(let stepId, let waitElapsed) = processingState {
                let newElapsed = waitElapsed + 1
                processingState = .waiting(stepId: stepId, waitElapsed: newElapsed)

                if newElapsed == 10 || newElapsed == 30 || newElapsed == 60 || newElapsed % 60 == 0 {
                    writeLog("Preset6: Waiting timer at \(newElapsed)s for step '\(stepId)'", logLevel: .debug)
                }
            }
        }
    }

    /// `confirmed`: the result is the user's own choice, so a `requireManualConfirm` step completes at once.
    func handleCompletionTrigger(stepId: String, result: CompletionResult, confirmed: Bool = false) {
        // Shared with Preset 5: records processingResult_<id> and the step's completed/failed/skipped state.
        let effect = StepCompletion.record(result, stepId: stepId, steps: inspectState.steps, confirmed: confirmed,
                                           completed: &completedSteps, failed: &failedSteps,
                                           skipped: &skippedSteps, values: &inspectState.userValues)
        switch effect {
        case .unknownStep:
            writeLog("Preset6: Cannot handle completion for unknown step: \(stepId)", logLevel: .error)
            return
        case .awaitingConfirm:
            // The step completes on the user's click (handleContinue); stop the clock so Continue can take it.
            writeLog("Preset6: Completion trigger for '\(stepId)' received but requireManualConfirm=true — waiting for user click", logLevel: .info)
            processingClock?.cancel()
            processingClock = nil
            processingState = .idle
            savePersistedState()
            return
        case .completed:
            break
        }

        processingClock?.cancel()
        processingClock = nil
        processingState = .idle

        // Triggers .onChange, then handleExternalCompletions after a delay.
        inspectState.completedItems.insert(stepId)

        switch result {
        case .success(let message):
            print("[PRESET6_PROCESSING] result: \(stepId) = success")
            writeInteractionLog("success", step: stepId, data: ["message": message ?? ""])
            logPreset6Event("step_success", details: ["stepId": stepId, "message": message ?? ""])

        case .failure(let message):
            print("[PRESET6_PROCESSING] result: \(stepId) = failed")
            writeInteractionLog("failure", step: stepId, data: ["message": message ?? "Step failed"])
            logPreset6Event("step_failure", details: ["stepId": stepId, "message": message ?? "Step failed"])

        case .warning(let message):
            print("[PRESET6_PROCESSING] result: \(stepId) = warning")
            writeInteractionLog("warning", step: stepId, data: ["message": message ?? ""])
            logPreset6Event("step_warning", details: ["stepId": stepId, "message": message ?? ""])

        case .cancelled:
            print("[PRESET6_PROCESSING] result: \(stepId) = skipped")
            writeInteractionLog("cancelled", step: stepId)
            logPreset6Event("step_cancelled", details: ["stepId": stepId])
        }

        writeLog("Preset6: Step '\(stepId)' completed with result: \(result)", logLevel: .info)
        savePersistedState()

        // Auto-advance only for the step on screen, when opted in and not failed.
        if let step = inspectState.steps.first(where: { $0.id == stepId }),
           inspectState.steps[safe: currentStep]?.id == stepId,
           ProcessingFlow.advancesAfterCompletion(step, result: result) {
            autoNavigationTask?.cancel()
            let delay = inspectState.config?.autoAdvanceDelay ?? 0.5
            autoNavigationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                if StepVisibility.next(after: currentStep, in: inspectState.steps, values: inspectState.userValues,
                                       isSatisfied: isStepSatisfied) == nil {
                    handleFinish()
                } else {
                    navigateToNextStep()
                }
            }
        }
    }

    func handleOverrideAction(action: OverrideDialogView.OverrideAction, stepId: String) {
        logPreset6Event("override_action", details: ["stepId": stepId, "action": "\(action)"])

        switch action {
        case .success:
            writeInteractionLog("override_success", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .success(message: nil), confirmed: true)
        case .failure:
            writeInteractionLog("override_failure", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .failure(message: localizedProcessingText("markedFailed", fallback: "Marked as failed by user")), confirmed: true)
        case .skip:
            writeInteractionLog("override_skip", step: stepId)
            handleCompletionTrigger(stepId: stepId, result: .cancelled, confirmed: true)
        case .cancel:
            writeInteractionLog("override_cancel", step: stepId)
        }
    }

    // MARK: - External Completions

    func handleExternalCompletions(_ newCompletedItems: Set<String>) {
        withAnimation(.spring()) {
            var shouldAutoNavigate = false
            var completedCurrentStep = false

            for item in inspectState.steps {
                if newCompletedItems.contains(item.id) && !completedSteps.contains(item.id) {
                    completedSteps.insert(item.id)

                    if let currentItem = inspectState.steps[safe: currentStep],
                       currentItem.id == item.id {
                        completedCurrentStep = true
                    }
                }
            }

            if completedCurrentStep {
                if let currentItem = inspectState.steps[safe: currentStep] {
                    let stepType = currentItem.resolvedStepType

                    if stepType == "processing" && processingState.isActive {
                        handleCompletionTrigger(stepId: currentItem.id, result: .success(message: currentItem.successMessage))
                        return
                    }

                    if currentStep < inspectState.steps.count - 1 {
                        let nextStepWaits = inspectState.steps[safe: currentStep + 1]?.waitForExternalTrigger ?? false
                        if !nextStepWaits {
                            shouldAutoNavigate = true
                        }
                    }
                }
            }

            if shouldAutoNavigate {
                autoNavigationTask?.cancel()
                let delay = inspectState.config?.autoAdvanceDelay ?? 0.5
                autoNavigationTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    navigateToNextStep()
                }
            }
        }
    }
}
