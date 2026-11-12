//
//  Preset6+Navigation.swift
//  dialog
//
//  Preset 6 extension: step navigation, auto-start, window position, completion, reset and finish.
//

import SwiftUI

extension Preset6View {
    // MARK: - Navigation

    func handleStepSelection(_ index: Int) {
        guard !shouldBlockNavigation else {
            writeLog("Preset6: Navigation blocked during processing", logLevel: .debug)
            return
        }

        guard !isItemObserveOnly(inspectState.steps[safe: index], config: inspectState.config) else {
            writeLog("Preset6: Navigation blocked - step is observe-only", logLevel: .debug)
            return
        }

        guard let targetItem = inspectState.steps[safe: index] else { return }

        // Bookends (any phase other than `main`) are not reachable from the sidebar.
        if targetItem.resolvedPhase != "main" {
            return
        }

        navigationDirection = index > currentStep ? .forward : .backward
        withAnimation(InspectConstants.stepTransition) {
            currentStep = index
        }

        restartIntroStepMonitoring()
        writeLog("Preset6: Navigated to step \(index) (\(targetItem.id))", logLevel: .info)
    }

    /// Whether a step counts as satisfied for `skipIfComplete`: a chooser pick, or already completed.
    func isStepSatisfied(_ step: InspectConfig.IntroStep) -> Bool {
        StepVisibility.hasRecordedPick(step, userValues: inspectState.userValues,
                                       dockSelection: inspectState.dockSelection,
                                       wallpaperSelection: inspectState.wallpaperSelection)
            || completedSteps.contains(step.id)
    }

    func handleContinue() {
        guard let currentItem = inspectState.steps[safe: currentStep] else {
            handleFinish()
            return
        }

        DialogNotifications.postButtonClick(stepId: currentItem.id, label: "Continue", action: "continue")

        // requireManualConfirm: the click completes the step with the result already recorded.
        if currentItem.requireManualConfirm == true, !completedSteps.contains(currentItem.id),
           StepCompletion.confirm(stepId: currentItem.id, completed: &completedSteps, failed: &failedSteps,
                                  skipped: &skippedSteps, values: inspectState.userValues) {
            inspectState.completedItems.insert(currentItem.id)
            writeLog("Preset6: Step '\(currentItem.id)' confirmed by the user", logLevel: .info)
            savePersistedState()
        }

        if currentItem.stepType == "processing" && !completedSteps.contains(currentItem.id) {
            startProcessing(for: currentItem)
            return
        }

        handleStepCompletion(item: currentItem)

        // The last step is the last one that shows; steps whose showWhen does not match are skipped.
        if StepVisibility.next(after: currentStep, in: inspectState.steps, values: inspectState.userValues,
                               isSatisfied: isStepSatisfied) == nil {
            handleFinish()
        } else {
            navigateToNextStep()
        }
    }

    /// IPC `next`, as in Preset 5: marks the current step done without starting its processing
    /// (a running one is stopped), then moves to the next visible step or finishes.
    func advanceByCommand() {
        guard let current = inspectState.steps[safe: currentStep] else { return }
        if case .idle = processingState {} else {
            processingClock?.cancel()
            processingClock = nil
            processingState = .idle
        }
        autoNavigationTask?.cancel()
        autoNavigationTask = nil
        handleStepCompletion(item: current)
        if StepVisibility.next(after: currentStep, in: inspectState.steps, values: inspectState.userValues,
                               isSatisfied: isStepSatisfied) == nil {
            handleFinish()
        } else {
            navigateToNextStep()
        }
    }

    func navigateToNextStep() {
        guard let target = StepVisibility.next(after: currentStep, in: inspectState.steps,
                                               values: inspectState.userValues,
                                               isSatisfied: isStepSatisfied) else { return }

        let oldStep = currentStep
        for skipped in inspectState.steps[(oldStep + 1)..<target] {
            writeLog("Preset6: Skipping step '\(skipped.id)' (showWhen does not match, or skipIfComplete and satisfied)", logLevel: .info)
        }
        navigationDirection = .forward
        withAnimation(InspectConstants.stepTransition) {
            currentStep = target
        }

        writeLog("Preset6: Advanced to step \(currentStep)", logLevel: .info)
        writeInteractionLog("navigate_next", step: "step_\(currentStep)")
        logPreset6Event("step_transition", details: [
            "from": oldStep,
            "to": currentStep,
            "reason": "navigate_next"
        ])

        if let nextItem = inspectState.steps[safe: currentStep] {
            DialogNotifications.postStepChange(stepId: nextItem.id, action: "navigate_next")
        }

        restartIntroStepMonitoring()

        if let nextItem = inspectState.steps[safe: currentStep] {
            autoStartProcessingIfNeeded(for: nextItem)
        }
    }

    /// Starts processing when the step is a processing step with autoAdvance and its required fields are filled.
    func autoStartProcessingIfNeeded(for item: InspectConfig.IntroStep) {
        guard item.stepType == "processing" else { return }

        guard !completedSteps.contains(item.id) else { return }

        guard item.autoAdvance == true else { return }

        if let guidanceContent = item.content {
            let hasFormInputs = guidanceContent.contains { block in
                ["textfield", "dropdown", "slider", "toggle", "checkbox", "radio"].contains(block.type)
            }

            if hasFormInputs {
                if let formState = inspectState.guidanceFormInputs[item.id] {
                    for block in guidanceContent where block.required == true {
                        let fieldId = block.id ?? "field_\(guidanceContent.firstIndex(where: { $0.id == block.id }) ?? 0)"

                        let hasValue: Bool
                        switch block.type {
                        case "textfield":
                            hasValue = formState.textfields[fieldId]?.isEmpty == false
                        case "dropdown":
                            hasValue = formState.dropdowns[fieldId]?.isEmpty == false
                        case "slider":
                            hasValue = formState.sliders[fieldId] != nil
                        case "toggle":
                            hasValue = formState.toggles[fieldId] == true
                        case "checkbox":
                            hasValue = formState.checkboxes[fieldId] == true
                        case "radio":
                            hasValue = formState.radios[fieldId]?.isEmpty == false
                        default:
                            hasValue = true
                        }

                        if !hasValue {
                            writeLog("Preset6: Auto-start blocked - required field '\(fieldId)' not filled", logLevel: .debug)
                            return
                        }
                    }
                } else {
                    writeLog("Preset6: Auto-start blocked - no form input state for step '\(item.id)'", logLevel: .debug)
                    return
                }
            }
        }

        logPreset6Event("auto_start_processing", details: ["stepId": item.id])
        startProcessing(for: item)
    }

    func goToPreviousStep() {
        guard canGoBack else { return }

        let oldStep = currentStep
        // Backing out of a running processing step cancels it; otherwise isProcessing would keep
        // Continue disabled on every screen. Re-entering the step restarts it via handleContinue.
        if case .idle = processingState {} else {
            processingClock?.cancel()
            processingClock = nil
            processingState = .idle
            writeLog("Preset6: Back cancelled in-flight processing at step \(oldStep)", logLevel: .info)
        }
        navigationDirection = .backward
        let target = StepVisibility.previous(before: currentStep, in: inspectState.steps,
                                             values: inspectState.userValues,
                                             isSatisfied: isStepSatisfied) ?? currentStep - 1
        withAnimation(InspectConstants.stepTransition) {
            currentStep = target
        }

        restartIntroStepMonitoring()
        writeLog("Preset6: Went back to step \(currentStep)", logLevel: .info)
        writeInteractionLog("navigate_previous", step: "step_\(currentStep)")
        logPreset6Event("step_transition", details: [
            "from": oldStep,
            "to": currentStep,
            "reason": "navigate_previous"
        ])
    }

    /// Moves the window when a step declares `windowPosition`, using the shared WindowAnchoring engine.
    func applyWindowPosition(for item: InspectConfig.IntroStep?) {
        didMoveWindow = applyWindowAnchor(position: item?.windowPosition,
                                          offset: item?.windowPositionOffset,
                                          didMoveWindow: didMoveWindow,
                                          label: "Preset6", stepId: item?.id ?? "?")
    }

    func handleStepCompletion(item: InspectConfig.IntroStep) {
        completedSteps.insert(item.id)
        savePersistedState()
        writeLog("Preset6: Step '\(item.id)' marked as completed", logLevel: .info)
        writeInteractionLog("completed_step", step: item.id)
        logPreset6Event("step_completed", details: [
            "stepId": item.id,
            "stepIndex": inspectState.steps.firstIndex(where: { $0.id == item.id }) ?? -1
        ])
        DialogNotifications.postStepChange(stepId: item.id, action: "completed")
    }

    /// Resets all progress (the "reset" command or Option-click).
    func resetSteps() {
        processingClock?.cancel()
        processingClock = nil

        let previouslyCompleted = completedSteps.count

        withAnimation(.spring()) {
            completedSteps.removeAll()
            failedSteps.removeAll()
            skippedSteps.removeAll()
            currentStep = 0
            processingState = .idle
            inspectState.completedItems.removeAll()
        }

        dynamicState.clearAllState()

        persistenceService.clearState()

        if FileManager.default.fileExists(atPath: triggerFilePath) {
            try? "".write(toFile: triggerFilePath, atomically: false, encoding: .utf8)
        }

        writeLog("Preset6: All progress reset", logLevel: .info)
        writeInteractionLog("reset", step: "all")
        logPreset6Event("steps_reset", details: [
            "previouslyCompleted": previouslyCompleted,
            "totalSteps": inspectState.steps.count
        ])
    }

    func handleFinish() {
        if ButtonExit.minimizeInsteadOfExiting(inspectState.config?.button1Action, label: "Preset6") { return }
        finish(exitCode: appDefaults.exit0.code)
    }

    /// The single exit path: final trigger file, persisted state, result file, readiness cleanup, quit.
    /// Continue exits 0; a supervised `close` / `quit:` exits 5.
    func finish(exitCode: Int32) {
        writeFinalTriggerFile()
        savePersistedState()

        let stepInfos = inspectState.steps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }

        // Secure text fields are never written to disk.
        let allFormValues = flattenedGuidanceFormValues(inspectState.guidanceFormInputs,
                                                        excludingFieldIds: secureStepFieldIds)

        writeResultFile(
            config: inspectState.config, exitCode: Int(exitCode),
            steps: stepInfos, completedSteps: completedSteps,
            failedSteps: failedSteps, skippedSteps: skippedSteps,
            currentStepIndex: currentStep,
            formValues: allFormValues
        )
        cleanupReadinessFile(config: inspectState.config, triggerFilePath: triggerFilePath,
                             exitCode: Int(exitCode),
                             completedCount: completedSteps.count,
                             failedCount: failedSteps.count,
                             totalSteps: inspectState.steps.count)

        writeLog("Preset6: Completing with exit code \(exitCode)", logLevel: .info)
        quitDialog(exitCode: exitCode)
    }
}
