//
//  Preset5+Commands.swift
//  dialog
//
//  Preset 5 extension: IPC handlers (item status, navigation, step control), CommandRouter wiring,
//  trigger-file monitoring and preferences setup. Also defines `ListItemCommand`.
//

import SwiftUI

extension Preset5View {

    // MARK: - Command Handlers

    /// Handles an item status command from the trigger file.
    func handleItemStatusCommand(itemId: String, status: String, message: String?) {
        // The shared item vocabulary (`StepStatus(itemCommand:)`) applied to this preset's store.
        guard let monitoringStatus = StepStatus(itemCommand: status), monitoringStatus != .skipped else {
            writeLog("Preset5: Unknown item status '\(status)' for '\(itemId)'", logLevel: .debug)
            return
        }
        monitoringService.setItemStatus(itemId, status: monitoringStatus)
        if let message = message {
            monitoringService.setStatusMessage(itemId, message: message)
        }
        writeLog("Preset5: Item '\(itemId)' → \(status)\(message.map { ": \($0)" } ?? "")", logLevel: .info)
    }

    /// Moves the current step's rows from a narration line ("Installing Example App…"). Used by the
    /// cadence and progresstext commands; `handleListItemCommand` instead matches row names exactly.
    func narrateToRows(_ text: String) {
        let items: [any MonitoredItem] = currentStep?.items ?? []
        guard !items.isEmpty else {
            DetectionLog.trace("narration ignored: step '\(currentStep?.id ?? "-")' has no rows — \(text)")
            return
        }
        guard let subject = InstallNarration.subject(of: text) else {
            DetectionLog.trace("narration not a narration: \(text)")
            return
        }
        guard let update = InstallNarration.rowUpdate(for: text, items: items) else {
            // Log the name received and every name compared, so a mismatch can be fixed with a `logAliases` entry.
            let names = items.map { "\($0.id)/\($0.displayName)" }.joined(separator: ", ")
            DetectionLog.trace("narration UNMATCHED subject='\(subject)' against rows: " + names)
            InspectDebugMeter.shared.trace("UNMATCHED '\(subject)' vs \(names)",
                                           source: "cadence:message")
            return
        }
        monitoringService.setItemStatus(update.id, status: update.status)
        monitoringService.setStatusMessage(update.id, message: update.message)
        writeLog("Preset5: narration '\(text)' → row '\(update.id)' \(update.status.rawValue)",
                 logLevel: .info)
        // Record which command moved this row.
        DetectionLog.note(itemId: update.id, from: "cadence:message",
                          to: update.status.rawValue, by: .command)
        InspectDebugMeter.shared.record(source: "cadence:message", itemId: update.id,
                                        detail: "→ \(update.status.rawValue)")
    }

    /// Applies a `listitem:` line via `ListItemCommand`. Writes to `monitoringService`, the only store
    /// the provisioning rows read. The 2 s poller re-derives status for rows with `paths`, so a pushed
    /// status persists only on rows without `paths` or `requirements`.
    func handleListItemCommand(_ remainder: String) {
        let stepId = currentStep?.id ?? "-"
        let items: [any MonitoredItem] = currentStep?.items ?? []
        switch ListItemCommand.resolve(remainder, items: items) {
        case .add(let itemId, let title, let icon, let status, let message, let step):
            addRow(id: itemId, title: title, icon: icon, step: step)
            if let status { monitoringService.setItemStatus(itemId, status: status) }
            if let message { monitoringService.setStatusMessage(itemId, message: message) }
            writeLog("Preset5: listitem added '\(itemId)' (\(title))", logLevel: .info)
        case .order(let ids):
            reorderStepRows(ids)
        case .delete(let itemId):
            removeRow(itemId)
            writeLog("Preset5: listitem deleted '\(itemId)'", logLevel: .info)
        case .update(let itemId, let status, let message):
            if let status { monitoringService.setItemStatus(itemId, status: status) }
            if let message { monitoringService.setStatusMessage(itemId, message: message) }
            // Record which command moved this row (see `narrateToRows`).
            DetectionLog.note(itemId: itemId, from: "listitem",
                              to: status?.rawValue ?? "message-only", by: .command)
            InspectDebugMeter.shared.record(source: "listitem", itemId: itemId,
                                            detail: "→ \(status?.rawValue ?? "message-only")")
            writeLog("Preset5: listitem '\(itemId)' → \(status?.rawValue ?? "-")\(message.map { ": \($0)" } ?? "")",
                     logLevel: .info)
        case .unresolved(let target):
            writeLog("Preset5: listitem '\(target)' names no item on step '\(stepId)' — ignored",
                     logLevel: .debug)
            DetectionLog.trace("listitem UNMATCHED target='\(target)' against rows: "
                               + items.map { "\($0.id)/\($0.displayName)" }.joined(separator: ", "))
        case .unknownStatus(let word):
            writeLog("Preset5: Unknown listitem status '\(word)' on step '\(stepId)' — ignored",
                     logLevel: .debug)
            DetectionLog.trace("listitem UNKNOWN STATUS '\(word)' — accepted words are "
                               + "wait, success, fail, error, pending, progress")
        case .empty:
            writeLog("Preset5: listitem carried nothing to apply: \(remainder)", logLevel: .debug)
        }
    }

    /// `listitem: add`: appends a row through the runtime steps overlay, decoded like an authored row.
    /// Counted only when its step was deployed empty; an id already on any step is not added again.
    /// Placement: `step:` if given, else the installation step holding rows of the same kind, else the
    /// last installation step, else the step on screen.
    func addRow(id: String, title: String, icon: String?, step: String?) {
        var steps = allSteps
        guard let (at, counted) = ListItemCommand.placement(of: id, in: steps, named: step, current: currentStep?.id,
                                                            deployed: inspectState.config?.introSteps ?? []) else { return }
        var fields: [String: Any] = ["id": id, "displayName": title]
        if let icon { fields["icon"] = icon }
        guard let data = try? JSONSerialization.data(withJSONObject: fields),
              let row = try? JSONDecoder().decode(InspectConfig.ListItem.self, from: data) else { return }
        steps[at].items = (steps[at].items ?? []) + [row]
        if !counted { inspectState.addedItemIDs.insert(id) }
        inspectState.runtimeSteps = steps
    }

    /// `listitem: delete`: removes the row from whichever step holds it. Unknown ids are a no-op.
    func removeRow(_ id: String) {
        var steps = allSteps
        var changed = false
        for index in steps.indices where (steps[index].items ?? []).contains(where: { $0.id == id }) {
            steps[index].items?.removeAll { $0.id == id }
            changed = true
        }
        guard changed else { return }
        inspectState.addedItemIDs.remove(id)
        inspectState.runtimeSteps = steps
    }

    /// `listitem: order`: reorders rows within every step that holds them, not only the step on screen.
    func reorderStepRows(_ ids: [String]) {
        guard let steps = ListItemCommand.reorderingRows(of: allSteps, by: ids) else { return }
        inspectState.runtimeSteps = steps
        writeLog("Preset5: step rows put in Fleet's order", logLevel: .info)
    }

    /// Navigates to a step by id.
    func navigateToStep(stepId: String) {
        if let index = allSteps.firstIndex(where: { $0.id == stepId }) {
            writeLog("Preset5: Navigating to step '\(stepId)' at index \(index)", logLevel: .info)
            withAnimation(InspectConstants.stepCrossfade) {
                currentStepIndex = index
            }
            writeStepEvent("step_started", stepId: stepId)
            return
        }

        // "portal" navigates to the first portal step.
        if stepId == "portal" {
            if let index = allSteps.firstIndex(where: { $0.stepType == "portal" }) {
                writeLog("Preset5: Navigating to portal step at index \(index)", logLevel: .info)
                withAnimation(InspectConstants.stepCrossfade) {
                    currentStepIndex = index
                }
                writeStepEvent("step_started", stepId: allSteps[index].id)
                return
            }
        }

        writeLog("Preset5: Step '\(stepId)' not found for navigation", logLevel: .error)
    }

    /// Whether a step's choice is already satisfied: its selection key has a value (option, dock,
    /// wallpaper), or a prior run completed it. Lets an orchestrator pre-answer steps.
    func isStepSatisfied(_ step: InspectConfig.IntroStep) -> Bool {
        StepVisibility.hasRecordedPick(step, userValues: inspectState.userValues,
                                       dockSelection: inspectState.dockSelection,
                                       wallpaperSelection: inspectState.wallpaperSelection)
            || completedNavigatedSteps.contains(step.id)
    }

    /// A step is skipped when its showWhen does not match, or when it sets `skipIfComplete`, is not
    /// `revisitable`, and is already satisfied (`StepVisibility`).
    func shouldSkipStep(_ step: InspectConfig.IntroStep) -> Bool {
        StepVisibility.isSkipped(step, values: inspectState.userValues, isSatisfied: isStepSatisfied)
    }

    /// The first non-skipped step from `start` (inclusive), marking skipped steps and emitting
    /// `step_skipped` events. Returns `allSteps.count` if none remain.
    func nextVisibleIndex(from start: Int) -> Int {
        var idx = start
        while idx < allSteps.count && shouldSkipStep(allSteps[idx]) {
            let skipped = allSteps[idx]
            skippedSteps.insert(skipped.id)
            writeStepEvent("step_skipped", stepId: skipped.id)
            writeLog("Preset5: Auto-skipping step '\(skipped.id)' (satisfied, or showWhen does not match)", logLevel: .info)
            idx += 1
        }
        return idx
    }

    /// Moves the window when a step declares `windowPosition`, using WindowAnchoring.
    func applyWindowPosition(for step: InspectConfig.IntroStep?) {
        didMoveWindow = applyWindowAnchor(position: step?.windowPosition,
                                          offset: step?.windowPositionOffset,
                                          didMoveWindow: didMoveWindow,
                                          label: "Preset5", stepId: step?.id ?? "?")
    }

    /// Schedules a step's auto-advance after a short delay. The task is cancelled on every navigation
    /// (`.onChange(of: currentStepIndex)`), and it only advances if `stepId` is still the current step,
    /// since a task already past its sleep cannot be cancelled. Each caller keeps its own delay.
    func scheduleAutoAdvance(after delay: Double, from stepId: String) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard currentStep?.id == stepId else {
                writeLog("Preset5: auto-advance from '\(stepId)' dropped — flow already moved to '\(currentStep?.id ?? "-")'",
                         logLevel: .debug)
                return
            }
            goToNextStep()
        }
    }

    /// Cancels any pending auto-advance. Safe to call unconditionally, including from the advance itself.
    func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    /// The store a `select:<key>:…` command writes: the picker that owns the key. Pure, for tests.
    enum SelectStore: Equatable { case userValues, dock, wallpaper, form(stepId: String), grid }

    static func selectStore(for key: String, in steps: [InspectConfig.IntroStep]) -> SelectStore {
        for step in steps {
            if SplashPick.defaultValue(for: step) != nil, SplashPick.key(for: step) == key { return .userValues }
            if step.stepType == "review",
               let reviewKey = OptionPlan.followedKey(explicit: step.reviewSelectionKey, in: steps),
               OptionPlan.acknowledgedKey(reviewKey) == key { return .userValues }
            switch step.stepType {
            case "options":
                if (step.optionKey ?? step.id) == key { return .userValues }
            case "dock":
                if (step.dockSelectionKey ?? step.id) == key { return .dock }
            default:
                if step.wallpaperCategories != nil, (step.wallpaperSelectionKey ?? step.id) == key { return .wallpaper }
            }
            // A dropdown/radio block (the language picker among them): its form state is what it draws.
            if step.content?.contains(where: { $0.id == key && ["dropdown", "radio", "segmented"].contains($0.type) }) == true {
                return .form(stepId: step.id)
            }
        }
        return .grid
    }

    func goToNextStep() {
        // `continueAction: "minimize"` hides the window instead of advancing. The last step uses the root
        // `button1Action`, where Continue finishes the flow.
        let isLastStep = currentStepIndex >= allSteps.count - 1
        // Guide picker: Finish waits for a selection, then writes the selections plist (3.1.1).
        if isLastStep, isGuidePickerMode {
            guard guidePickerAllowsFinish else {
                writeLog("Preset5: Finish held — guide picker needs a selection", logLevel: .info)
                return
            }
            writeGuideSelectionsToOutput()
        }
        let continueAction = currentStep?.continueAction ?? (isLastStep ? config?.button1Action : nil)
        if ButtonExit.minimizes(continueAction) {
            minimizeDialogWindow()
            writeLog("Preset5: continueAction=minimize — window miniaturized", logLevel: .info)
            return
        }

        // Record a cadence run's outcome before the step event carries the values.
        if let step = currentStep, step.stepType == "cadence" {
            recordCadenceOutcome(stepId: step.id)
        }

        if let step = currentStep {
            completedNavigatedSteps.insert(step.id)
            writeStepEvent("step_completed", stepId: step.id)
            writeStepOutput(stepId: step.id, action: "completed")
            writeStepData(for: step)
        }

        // Advance to the next visible step, skipping satisfied ones.
        let nextIndex = nextVisibleIndex(from: currentStepIndex + 1)
        if nextIndex < allSteps.count {
            withAnimation(InspectConstants.stepCrossfade) {
                currentStepIndex = nextIndex
            }
            writeStepEvent("step_started", stepId: allSteps[currentStepIndex].id)
            writeLog("Preset5: Advanced to step \(currentStepIndex)", logLevel: .info)
        } else {
            writeLog("Preset5: All steps completed, finishing", logLevel: .info)
            handleCompletion()
        }
    }

    /// Goes to the previous step, skipping satisfied steps but never step 0.
    func goToPreviousStep() {
        guard currentStepIndex > 0 else { return }
        var prevIndex = currentStepIndex - 1
        while prevIndex > 0 && shouldSkipStep(allSteps[prevIndex]) {
            prevIndex -= 1
        }
        withAnimation(InspectConstants.stepCrossfade) {
            currentStepIndex = prevIndex
        }
        writeLog("Preset5: Moved back to step \(currentStepIndex)", logLevel: .info)
    }

    /// Alias for goToPreviousStep.
    func goToPrevStep() {
        goToPreviousStep()
    }

    /// All selections for the result file: grid, wallpaper, option picker and dock, as sets.
    /// Dock paths stay one joined string to keep their order.
    var mergedResultSelections: [String: Set<String>] {
        var merged = gridSelections.mapValues { $0 }
        for (key, path) in inspectState.wallpaperSelection {
            merged[key] = [path]
        }
        for (key, value) in inspectState.userValues {
            merged[key] = Set(value.components(separatedBy: ",").filter { !$0.isEmpty })
        }
        for (key, value) in inspectState.dockSelection {
            merged[key] = [value]
        }
        return merged
    }

    /// Writes a step's selections and form values.
    func writeStepData(for step: InspectConfig.IntroStep) {
        if let selectionKey = step.gridSelectionKey,
           let selections = gridSelections[selectionKey] {
            writeSelectionOutput(key: selectionKey, selections: Array(selections))

            // Write to the preferences service when a preferenceKey is configured.
            if let preferenceKey = step.gridPreferenceKey ?? step.gridSelectionKey {
                let selectionArray = Array(selections).sorted()
                let isMultiSelect = (step.gridSelectionMode ?? "single") == "multiple"
                let selectedValue = isMultiSelect ? selectionArray.joined(separator: ",") : (selectionArray.first ?? "")
                preferencesService?.setValue(selectedValue, forKey: preferenceKey)
                writeLog("Preset5: Wrote preference '\(preferenceKey)' = '\(selectedValue)'", logLevel: .info)
            }
        }

        if let wallpaperKey = step.wallpaperSelectionKey {
            let preferenceKey = step.wallpaperPreferenceKey ?? wallpaperKey
            if let wallpaperPath = inspectState.wallpaperSelection[wallpaperKey] {
                preferencesService?.setValue(wallpaperPath, forKey: preferenceKey)
                writeLog("Preset5: Wrote wallpaper preference '\(preferenceKey)' = '\(wallpaperPath)'", logLevel: .info)
            }
        }

        // Option picker selection (browser, email, PDF, appearance).
        let optionKey = step.optionKey ?? (step.optionCards != nil ? step.id : nil)
        if let optionKey, let value = inspectState.userValues[optionKey] {
            let preferenceKey = step.optionPreferenceKey ?? optionKey
            preferencesService?.setValue(value, forKey: preferenceKey)
            writeLog("Preset5: Wrote option preference '\(preferenceKey)' = '\(value)'", logLevel: .info)
        }

        // Dock selection: ordered app paths, comma-joined.
        let dockKey = step.dockSelectionKey ?? ((step.dockFlavors != nil || step.dockItems != nil) ? step.id : nil)
        if let dockKey, let value = inspectState.dockSelection[dockKey] {
            let preferenceKey = step.dockPreferenceKey ?? dockKey
            preferencesService?.setValue(value, forKey: preferenceKey)
            writeLog("Preset5: Wrote dock preference '\(preferenceKey)' = '\(value)'", logLevel: .info)
        }

        // The splash pick, so the launching script can open the matching flow.
        if SplashPick.defaultValue(for: step) != nil {
            let key = SplashPick.key(for: step)
            if let value = inspectState.userValues[key] {
                writeSelectionOutput(key: key, selections: [value])
                preferencesService?.setValue(value, forKey: key)
            }
        }

        // Form values as flat strings.
        if let content = step.content {
            let stepValues = legacyFormValues(for: step)
            for block in content where Self.formValueTypes.contains(block.type) {
                if let fieldId = block.id, let value = stepValues[fieldId] {
                    preferencesService?.setValue(value, forKey: fieldId)
                    writeLog("Preset5: Persisted form value '\(fieldId)' = '\(value)'", logLevel: .debug)
                }
            }
            if content.contains(where: { Self.formValueTypes.contains($0.type) }) {
                preferencesService?.writeToPlist()
            }
        }
    }

    /// Handles completion of all steps.
    func handleCompletion() {
        saveCompletionState()
        writeFinalOutput()
        handleButton1()
    }

    /// Saves completion state to UserDefaults when resumable.
    func saveCompletionState() {
        guard config?.resumable == true else { return }

        stateDefaults.set(true, forKey: "stepsCompleted")
        stateDefaults.set(Date(), forKey: "stepsCompletedAt")
        stateDefaults.set(currentStepIndex, forKey: "lastStepIndex")
        stateDefaults.synchronize()
        writeLog("Preset5: Saved completion state to UserDefaults domain: \(stateDomain)", logLevel: .info)
    }
    // MARK: - Command Router Setup

    /// Wires the shared CommandRouter to Preset 5's handlers, then starts file monitoring.
    func setupCommandRouter() {
        commandRouter.presetLabel = "Preset5"
        commandRouter.acknowledgmentLogPath = "/var/tmp/dialog-ack.log"
        commandRouter.itemCount = allSteps.count

        // Exposes step status through InspectState.status(for:). Precedence: failed, completed (navigated or
        // processing), skipped, active, pending. Unknown ids return nil.
        inspectState.stepStatusProvider = { [self] id in
            if failedSteps[id] != nil { return .failed }
            if completedNavigatedSteps.contains(id) || completedProcessingSteps.contains(id) { return .completed }
            if skippedSteps.contains(id) { return .skipped }
            if currentStep?.id == id { return .active }
            return allSteps.contains(where: { $0.id == id }) ? .pending : nil
        }
        inspectState.stepSnapshotProvider = { [self] in
            allSteps.map { (id: $0.id, stepType: $0.resolvedStepType) }
        }

        commandRouter.onNavigateByID = { [self] stepId in navigateToStep(stepId: stepId) }
        commandRouter.onNavigateByIndex = { [self] index in
            if index >= 0, index < allSteps.count {
                withAnimation(InspectConstants.stepCrossfade) {
                    currentStepIndex = index
                }
                writeStepEvent("step_started", stepId: allSteps[index].id)
            }
        }
        commandRouter.onNext = { [self] in goToNextStep() }
        // `continue` presses the primary button: goToNextStep, as `next`.
        commandRouter.onContinue = { [self] in goToNextStep() }
        // `override:` records and completes exactly as the override picker does.
        commandRouter.onOverride = { [self] stepId, result in
            guard allSteps.contains(where: { $0.id == stepId }) else { return }
            if case .cancelled = result {} else {
                let word: String = { if case .failure = result { return "failed" }; return "success" }()
                lastOverrideResult = word
                lastOverrideStepId = stepId
                inspectState.userValues["overrideResult"] = word
                inspectState.userValues["overrideStepId"] = stepId
            }
            showOverridePicker = false
            stopProcessingCountdown()
            handleCompletionTrigger(stepId: stepId, result: result, confirmed: true)
        }
        commandRouter.onPrev = { [self] in goToPrevStep() }
        commandRouter.isFlowHeld = { [self] in
            guard currentStepIndex >= 0, currentStepIndex < allSteps.count else { return false }
            return journeyHoldsItsDoor(step: allSteps[currentStepIndex])
        }
        commandRouter.onClose = { [self] in
            // Supervised close: writes the result file, posts the exit event and removes readiness/session files.
            // Exit 5 distinguishes it from a user close (0) or timeout (4).
            writeLog("Preset5: supervised close", logLevel: .info)
            let allCompleted = completedNavigatedSteps.union(completedProcessingSteps)
            let stepInfos = allSteps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }
            writeResultFile(
                config: config, exitCode: Int(appDefaults.exit5.code), steps: stepInfos,
                completedSteps: allCompleted, failedSteps: failedSteps,
                skippedSteps: skippedSteps, currentStepIndex: currentStepIndex,
                formValues: exportedFormValues, selections: mergedResultSelections,
                selectedBrand: selectedBrandId
            )
            cleanupReadinessFile(config: config, triggerFilePath: triggerFilePath,
                                 exitCode: Int(appDefaults.exit5.code),
                                 completedCount: allCompleted.count,
                                 failedCount: failedSteps.count,
                                 totalSteps: allSteps.count)
            quitDialog(exitCode: appDefaults.exit5.code)
        }
        commandRouter.onReset = { [self] in
            withAnimation(.spring()) {
                currentStepIndex = 0
                completedProcessingSteps.removeAll()
                failedSteps.removeAll()
                skippedSteps.removeAll()
                completedNavigatedSteps.removeAll()
                processingState = .idle
            }
            dynamicState.clearAllState()
            resetState()
            writeLog("Preset5: Full reset — all progress and overrides cleared", logLevel: .info)
        }

        // `cadence:satisfy:<id>`, `cadence:advance`, `cadence:goto:<index>` drive the cadence sequence.
        commandRouter.onCadence = { [self] remainder in
            let parts = remainder.split(separator: ":", maxSplits: 1).map(String.init)
            switch parts.first {
            case "satisfy":
                if parts.count > 1 { cadenceMonitor.satisfyExternally(id: parts[1]) }
            case "advance":
                cadenceMonitor.advance()
            case "fail":
                if parts.count > 1 { cadenceMonitor.failExternally(id: parts[1]) }
            case "goto":
                if parts.count > 1, let index = Int(parts[1]) { cadenceMonitor.goto(index: index) }
            case "message":
                // `cadence:message:<index>:<text>` overrides the message with the app actually installing.
                if parts.count > 1 {
                    let mp = parts[1].split(separator: ":", maxSplits: 1).map(String.init)
                    if let index = Int(mp[0]), mp.count > 1 {
                        cadenceMonitor.setMessage(index: index, text: mp[1])
                        // The same line also moves matching rows, so a carousel step follows cadence narration too.
                        narrateToRows(mp[1])
                    }
                }
            default:
                writeLog("Preset5: unknown cadence subcommand '\(remainder)'", logLevel: .info)
            }
        }

        commandRouter.onComplete = { [self] stepId in
            if !completedProcessingSteps.contains(stepId) {
                completedProcessingSteps.insert(stepId)
                writeStepEvent("step_completed", stepId: stepId)
            }
        }
        commandRouter.onSuccess = { [self] stepId, message in
            handleCompletionTrigger(stepId: stepId, result: .success(message: message))
        }
        commandRouter.onFailure = { [self] stepId, reason in
            handleCompletionTrigger(stepId: stepId, result: .failure(message: reason))
        }
        commandRouter.onWarning = { [self] stepId, message in
            handleCompletionTrigger(stepId: stepId, result: .warning(message: message))
        }

        commandRouter.onUpdateGuidance = { [self] command in
            handleUpdateGuidanceCommand(command)
        }
        commandRouter.onUpdateMessage = { [self] stepId, message in
            dynamicState.updateMessage(stepId: stepId, message: message)
        }
        commandRouter.onProgress = { [self] stepId, pct in
            dynamicState.updateProgress(stepId: stepId, percentage: pct)
            // Also moves the bar of the row with that id, as `progress:` does on Presets 1–3.
            monitoringService.setProgress(stepId, percent: Double(pct))
        }
        commandRouter.onBatchUpdate = { [self] jsonString in
            processBatchUpdate(jsonString)
        }
        commandRouter.onDisplayData = { [self] stepId, key, value, color in
            dynamicState.updateDisplayData(stepId: stepId, key: key, value: value, color: color)
        }

        commandRouter.onRecheck = { [self] targetItemId in
            if let itemId = targetItemId {
                inspectState.recheckPlistMonitorsForItem(itemId) { itemId, blockIndex, property, newValue in
                    dynamicState.updateGuidanceProperty(stepId: itemId, blockIndex: blockIndex, property: property, value: newValue)
                }
            } else {
                inspectState.recheckAllPlistMonitors { itemId, blockIndex, property, newValue in
                    dynamicState.updateGuidanceProperty(stepId: itemId, blockIndex: blockIndex, property: property, value: newValue)
                }
            }
        }

        commandRouter.onSelect = { [self] key, values in
            // Route to the store that owns the key: options and splash → userValues, dock → dockSelection,
            // wallpaper → wallpaperSelection, a dropdown/radio block → its step's form state,
            // grid and unmatched keys → gridSelections.
            let store = Self.selectStore(for: key, in: allSteps)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                switch store {
                case .userValues:
                    inspectState.userValues[key] = values.joined(separator: ",")
                    // A scripted multi-pick resolves its plan like a tapped one.
                    if let cards = multiOptionCards(forKey: key) {
                        storeOptionPlan(key: key, cards: cards, picked: Set(values))
                    }
                case .dock:
                    inspectState.dockSelection[key] = values.joined(separator: ",")
                case .wallpaper:
                    if let first = values.first { inspectState.wallpaperSelection[key] = first } else { gridSelections[key] = Set(values) }
                case .form(let stepId):
                    if inspectState.guidanceFormInputs[stepId] == nil {
                        inspectState.initializeGuidanceFormState(for: stepId)
                    }
                    if let block = allSteps.first(where: { $0.id == stepId })?.content?.first(where: { $0.id == key }),
                       let value = values.first {
                        seedFormValue(stepId: stepId, block: block, fieldId: key, rawValue: value)
                    }
                case .grid:
                    gridSelections[key] = Set(values)
                }
            }
            writeSelectionOutput(key: key, selections: values)
            // Also write to preferences when a step has this gridSelectionKey.
            if let step = allSteps.first(where: { $0.gridSelectionKey == key }),
               let preferenceKey = step.gridPreferenceKey ?? step.gridSelectionKey {
                let isMultiSelect = (step.gridSelectionMode ?? "single") == "multiple"
                let selectedValue = isMultiSelect ? values.sorted().joined(separator: ",") : (values.first ?? "")
                preferencesService?.setValue(selectedValue, forKey: preferenceKey)
            }
            writeLog("Preset5: External select '\(key)' = \(values)", logLevel: .info)
        }

        commandRouter.onSetCommand = { [self] targetType, value, extra in
            handleSetCommand(targetType: targetType, value: value, extra: extra)
        }
        commandRouter.onItemStatus = { [self] itemId, status, message in
            handleItemStatusCommand(itemId: itemId, status: status, message: message)
        }
        commandRouter.onItemIcon = { [self] itemId, icon in
            inspectState.itemIconOverrides[itemId] = icon.isEmpty ? nil : icon
        }
        commandRouter.onListItem = { [self] remainder in
            handleListItemCommand(remainder)
        }

        // Steps change through the runtimeSteps overlay; the cursor is fixed up in the same transaction so
        // the mounted step keeps its identity.
        commandRouter.onAddStep = { [self] payload in
            let outcome = StepListMutation.add(payload: payload, to: allSteps, cursor: currentStepIndex, label: "Preset5")
            if case .applied(let steps, _, let cursor, _) = outcome {
                inspectState.runtimeSteps = steps
                currentStepIndex = cursor
                commandRouter.itemCount = steps.count
            }
            StepListMutation.announce(outcome, added: true, label: "Preset5")
            return outcome.result
        }
        commandRouter.onRemoveStep = { [self] stepId in
            let outcome = StepListMutation.remove(id: stepId, from: allSteps, cursor: currentStepIndex)
            if case .applied(let steps, _, let cursor, _) = outcome {
                inspectState.runtimeSteps = steps
                currentStepIndex = cursor
                commandRouter.itemCount = steps.count
            }
            StepListMutation.announce(outcome, added: false, label: "Preset5")
            return outcome.result
        }
        commandRouter.onStepList = { [self] path in
            // Secure text field values are excluded from the snapshot.
            let formValues = exportedFormValues
            if let error = writeStepListResponse(
                path: path, preset: "5", steps: inspectState.stepSnapshot(),
                state: inspectState, currentIndex: currentStepIndex,
                progress: dynamicState.progressPercentages,
                formValues: formValues,
                selections: mergedResultSelections.mapValues { Array($0).sorted() }
            ) { return .rejected(id: nil, message: error) }
            return .ok(id: "_")
        }

        // Monitoring is hosted on the CommandRouter object.
        if !FileManager.default.fileExists(atPath: triggerFilePath) {
            FileManager.default.createFile(atPath: triggerFilePath, contents: nil, attributes: nil)
        }
        commandRouter.startMonitoring(
            triggerFilePath: triggerFilePath,
            notificationHandler: { command in
                writeLog("Preset5: Received notification command: \(command)", logLevel: .info)
            }
        )

        print("[SWIFTDIALOG] trigger_mode: \(triggerMode)")
        print("[PRESET11_PROCESSING] command_file_monitoring_started: \(triggerFilePath)")
    }

    /// Creates the preferences service from config.
    func initializePreferencesService() {
        guard let config = config,
              let prefsOutput = config.preferencesOutput else {
            writeLog("Preset5: No preferencesOutput config, preferences service disabled", logLevel: .debug)
            return
        }

        let outputConfig = PreferencesOutputConfig(
            plistPath: prefsOutput.plistPath,
            writeOnStepComplete: prefsOutput.writeOnStepComplete,
            writeOnDialogExit: prefsOutput.writeOnDialogExit,
            mergeWithExisting: prefsOutput.mergeWithExisting,
            staticValues: prefsOutput.staticValues?.mapValues { AnyCodable($0) }
        )

        preferencesService = PreferencesService(config: outputConfig, userDefaultsSuite: stateDomain)
        writeLog("Preset5: Initialized PreferencesService with plist path: \(prefsOutput.plistPath)", logLevel: .info)
    }
}
