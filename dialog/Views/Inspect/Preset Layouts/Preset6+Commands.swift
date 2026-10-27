//
//  Preset6+Commands.swift
//  dialog
//
//  Preset 6 extension: monitor startup, CommandRouter wiring, trigger-file monitoring and IPC handlers.
//

import SwiftUI

extension Preset6View {

    // MARK: - Service Initialization

    /// Starts compliance aggregation from the `plistSources` config.
    func startComplianceMonitoring() {
        if let plistSources = inspectState.config?.plistSources, !plistSources.isEmpty {
            writeLog("Preset6: Starting ComplianceAggregatorService with \(plistSources.count) sources", logLevel: .info)
            complianceService.startMonitoring(sources: plistSources, refreshInterval: 5.0)
        }
    }

    /// Starts step monitors for dynamic content (phase-tracker, status-badge, comparison-table).
    func startIntroStepMonitoring() {
        guard let currentItem = inspectState.steps[safe: currentStep] else { return }
        introStepMonitor.startMonitoring(step: currentItem) { triggerItemId, result in
            writeLog("Preset6: Step monitor triggered for '\(triggerItemId)' with result: \(result)", logLevel: .info)
        }
    }

    /// Restarts step monitoring after navigating to a new step.
    func restartIntroStepMonitoring() {
        introStepMonitor.stopMonitoring()
        startIntroStepMonitoring()
    }

    // MARK: - Command Router Setup

    /// Wires the shared CommandRouter to Preset 6's handlers, then starts file monitoring.
    func setupCommandRouter() {
        commandRouter.presetLabel = "Preset6"
        commandRouter.acknowledgmentLogPath = acknowledgmentLogPath
        commandRouter.itemCount = inspectState.steps.count

        // Exposes step status through InspectState.status(for:): completedSteps unioned with
        // completedItems, as every render site reads it. Unknown ids return nil.
        inspectState.stepStatusProvider = { [self] id in
            if failedSteps[id] != nil { return .failed }
            if completedSteps.contains(id) || inspectState.completedItems.contains(id) { return .completed }
            if skippedSteps.contains(id) { return .skipped }
            if inspectState.steps[safe: currentStep]?.id == id { return .active }
            return inspectState.steps.contains(where: { $0.id == id }) ? .pending : nil
        }
        inspectState.stepSnapshotProvider = { [self] in
            inspectState.steps.map { (id: $0.id, stepType: $0.resolvedStepType) }
        }

        commandRouter.onNavigateByID = { [self] stepId in
            if let index = inspectState.steps.firstIndex(where: { $0.id == stepId }) {
                handleStepSelection(index)
                writeInteractionLog("navigate", step: stepId)
            }
        }
        commandRouter.onNavigateByIndex = { [self] index in
            guard inspectState.steps.indices.contains(index) else {
                writeLog("Preset6: navigate index \(index) out of range 0..<\(inspectState.steps.count)", logLevel: .error)
                return
            }
            autoNavigationTask?.cancel()
            autoNavigationTask = nil
            withAnimation(.spring()) { currentStep = index }
        }
        commandRouter.onNext = { [self] in advanceByCommand() }
        commandRouter.onContinue = { [self] in handleContinue() }
        commandRouter.onOverride = { [self] stepId, result in
            guard inspectState.steps.contains(where: { $0.id == stepId }) else { return }
            handleCompletionTrigger(stepId: stepId, result: result, confirmed: true)
        }
        commandRouter.onPrev = { [self] in goToPreviousStep() }
        commandRouter.onReset = { [self] in resetSteps() }
        // `close` / `quit:`: a supervised close, as on every preset: result file, exit 5.
        commandRouter.onClose = { [self] in finish(exitCode: appDefaults.exit5.code) }

        commandRouter.onComplete = { [self] stepId in
            if !completedSteps.contains(stepId),
               inspectState.steps.contains(where: { $0.id == stepId }) {
                withAnimation(.spring()) {
                    completedSteps.insert(stepId)
                    inspectState.completedItems.insert(stepId)
                }
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
        }
        commandRouter.onBatchUpdate = { [self] jsonString in
            processBatchUpdate(jsonString)
        }
        commandRouter.onDisplayData = { [self] stepId, key, value, color in
            dynamicState.updateDisplayData(stepId: stepId, key: key, value: value, color: color)
            logPreset6Event("display_data_update", details: ["stepId": stepId, "key": key, "value": value])
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
            // Update form state (dropdowns/radios) for the step that hosts this selection key.
            if let item = inspectState.steps.first(where: { item in
                item.content?.contains { $0.id == key } ?? false
            }) {
                var formState = inspectState.guidanceFormInputs[item.id] ?? GuidanceFormInputState()
                if let value = values.first {
                    formState.dropdowns[key] = value
                    formState.radios[key] = value
                }
                inspectState.guidanceFormInputs[item.id] = formState
            }
            // Record the value every preset reads (showWhen, StepLanguage, outcomes), comma-joined as on Preset 5.
            inspectState.userValues[key] = values.joined(separator: ",")
            DialogNotifications.postSelection(key: key, values: values)
            // Written to the interaction plist so external readers see it immediately.
            writeInteractionLog("selection:\(key):\(values.joined(separator: ","))", step: "external")
            writeLog("Preset6: External select '\(key)' = \(values)", logLevel: .info)
        }

        commandRouter.onSetCommand = { [self] targetType, value, extra in
            handleSetCommand(targetType: targetType, value: value, extra: extra)
        }
        commandRouter.onItemStatus = { [self] itemId, status, message in
            handleItemStatusCommand(itemId: itemId, status: status, message: message)
        }
        commandRouter.onListItem = { [self] remainder in
            handleListItemCommand(remainder)
        }

        // Steps are spliced directly into the @Published list; guiIndex only sets the initial order.
        // The cursor and index-keyed side stores are fixed up in the same transaction.
        commandRouter.onAddStep = { [self] payload in
            let outcome = StepListMutation.add(payload: payload, to: inspectState.steps, cursor: currentStep, label: "Preset6")
            if case .applied(let steps, let insertIndex, let cursor, _) = outcome {
                inspectState.steps = steps
                currentStep = cursor
                commandRouter.itemCount = steps.count
                // Shift the index-keyed list item icons so rows keep their icons.
                dynamicState.itemStatusIcons = Dictionary(uniqueKeysWithValues:
                    dynamicState.itemStatusIcons.map { key, value in
                        (key >= insertIndex ? key + 1 : key, value)
                    })
            }
            StepListMutation.announce(outcome, added: true, label: "Preset6")
            return outcome.result
        }
        commandRouter.onRemoveStep = { [self] stepId in
            let outcome = StepListMutation.remove(id: stepId, from: inspectState.steps, cursor: currentStep)
            if case .applied(let steps, let index, let cursor, _) = outcome {
                inspectState.steps = steps
                currentStep = cursor
                commandRouter.itemCount = steps.count
                dynamicState.itemStatusIcons = Dictionary(uniqueKeysWithValues:
                    dynamicState.itemStatusIcons.compactMap { key, value -> (Int, String)? in
                        if key == index { return nil }
                        return (key > index ? key - 1 : key, value)
                    })
            }
            StepListMutation.announce(outcome, added: false, label: "Preset6")
            return outcome.result
        }
        commandRouter.onStepList = { [self] path in
            // Secure text field values are excluded from the snapshot.
            let formValues = flattenedGuidanceFormValues(inspectState.guidanceFormInputs,
                                                         excludingFieldIds: secureStepFieldIds)
            if let error = writeStepListResponse(
                path: path, preset: "6", steps: inspectState.stepSnapshot(),
                state: inspectState, currentIndex: currentStep,
                progress: dynamicState.progressPercentages,
                formValues: formValues
            ) { return .rejected(id: nil, message: error) }
            return .ok(id: "_")
        }

        startFileMonitoring()

        print("[SWIFTDIALOG] trigger_mode: \(triggerMode)")
    }

    /// Starts trigger-file monitoring. The monitor lives on the CommandRouter object,
    /// so it survives copies of this view struct.
    func startFileMonitoring() {
        if !FileManager.default.fileExists(atPath: triggerFilePath) {
            FileManager.default.createFile(atPath: triggerFilePath, contents: nil, attributes: nil)
        }

        commandRouter.startMonitoring(
            triggerFilePath: triggerFilePath,
            notificationHandler: { command in
                writeLog("Preset6: Received notification command: \(command)", logLevel: .info)
            }
        )

        print("[SWIFTDIALOG] trigger_file: \(triggerFilePath)")
        print("[SWIFTDIALOG] distributed_notifications: enabled")
        writeLog("Preset6: File monitoring started at \(triggerFilePath)", logLevel: .info)
    }

    /// Handles `update_guidance:` via `GuidanceUpdateCommand` and InspectDynamicState, as on Preset 5.
    func handleUpdateGuidanceCommand(_ command: String) {
        switch GuidanceUpdateCommand.resolve(command, steps: inspectState.steps,
                                             currentStep: inspectState.steps[safe: currentStep]) {
        case .failure(let failure):
            writeLog("Preset6: update_guidance not applied (\(failure)): \(command)", logLevel: .error)
        case .success(let update):
            dynamicState.apply(update)
            logPreset6Event("guidance_update", details: ["stepId": update.stepId, "index": update.blockIndex,
                                                          "operation": "\(update.operation)"])
        }
    }

    /// Applies a classic `listitem:` line via `ListItemCommand`, as on Preset 5. Rows are steps here,
    /// so `title:` names a step title or id.
    func handleListItemCommand(_ remainder: String) {
        let rows = inspectState.steps.map { (id: $0.id, name: $0.title ?? $0.id) }
        switch ListItemCommand.resolve(remainder, rows: rows) {
        case .update(let itemId, let status, let message):
            if let status { applyItemStatus(itemId: itemId, resolved: status, message: message) }
            writeLog("Preset6: listitem '\(itemId)' → \(status?.rawValue ?? "-")\(message.map { ": \($0)" } ?? "")",
                     logLevel: .info)
        case .order:
            break  // rows are steps; their order is the flow's
        case .delete(let itemId):
            writeLog("Preset6: listitem delete '\(itemId)' — rows are steps here; a step is not deleted", logLevel: .debug)
        case .add(let itemId, _, _, _, _, _):
            // Rows are steps here; adding one means `addstep:`.
            writeLog("Preset6: listitem add '\(itemId)' — rows are steps here; use addstep", logLevel: .debug)
        case .unresolved(let target):
            writeLog("Preset6: listitem '\(target)' names no step — ignored", logLevel: .debug)
        case .unknownStatus(let word):
            writeLog("Preset6: Unknown listitem status '\(word)' — ignored", logLevel: .debug)
        case .empty:
            writeLog("Preset6: listitem carried nothing to apply: \(remainder)", logLevel: .debug)
        }
    }

    /// Applies a batch update JSON payload (`GuidanceBatchUpdate`) in a single @Published change
    /// via `updateGuidancePropertiesBatch()`.
    func processBatchUpdate(_ jsonString: String) {
        let resolved: GuidanceBatchUpdate.Resolved
        switch GuidanceBatchUpdate.resolve(jsonString, in: inspectState.steps) {
        case .failure(.invalidJSON):
            writeLog("Preset6: batch_update: invalid JSON — \(jsonString.prefix(200))", logLevel: .error)
            return
        case .failure(.unknownStep(let step)):
            writeLog("Preset6: batch_update: cannot resolve step '\(step)'", logLevel: .error)
            return
        case .success(let value):
            resolved = value
        }
        guard !resolved.blocks.isEmpty else { return }
        dynamicState.updateGuidancePropertiesBatch(stepId: resolved.stepId, blocks: resolved.blocks)
        logPreset6Event("batch_update", details: ["stepId": resolved.stepId, "blocks": resolved.blocks.count])
    }

    /// Handles `set:` via `DynamicSetCommand`, as on Preset 5.
    func handleSetCommand(targetType: String, value: String, extra: String?) {
        if let line = DynamicSetCommand.apply(type: targetType, value: value, extra: extra, steps: inspectState.steps,
                                              currentStepId: inspectState.steps[safe: currentStep]?.id, state: dynamicState) {
            writeLog("Preset6: set:\(targetType) — \(line)", logLevel: .info)
        } else {
            writeLog("Preset6: Unknown set command type: \(targetType)", logLevel: .debug)
        }
    }

    /// Applies an item status command (`ItemStatusCommand.swift`) to Preset 6's stores: a step with an outcome
    /// is in `completedSteps`, failures also go to `failedSteps`, success is mirrored to completedItems,
    /// and working maps to `downloadingItems`.
    func handleItemStatusCommand(itemId: String, status: String, message: String?) {
        guard let resolved = StepStatus(itemCommand: status) else { return }
        applyItemStatus(itemId: itemId, resolved: resolved, message: message)
    }

    func applyItemStatus(itemId: String, resolved: StepStatus, message: String?) {
        guard resolved != .skipped else { return }
        let failedIds = Set(failedSteps.keys)
        var lifecycle = ItemLifecycle(completed: completedSteps.subtracting(failedIds), failed: failedIds,
                                      active: downloadingItems)
        lifecycle.apply(itemId, resolved)
        withAnimation(.spring()) {
            if lifecycle.completed.contains(itemId) || lifecycle.failed.contains(itemId) {
                completedSteps.insert(itemId)
            } else {
                completedSteps.remove(itemId)
            }
            if lifecycle.completed.contains(itemId) {
                inspectState.completedItems.insert(itemId)
            } else {
                inspectState.completedItems.remove(itemId)
            }
            if lifecycle.failed.contains(itemId) {
                failedSteps[itemId] = message ?? ChromeCopy.failed
            } else {
                failedSteps.removeValue(forKey: itemId)
            }
            downloadingItems = lifecycle.active
        }
    }

    /// Every `secure: true` text field id across the steps; excluded from every file written.
    var secureStepFieldIds: Set<String> {
        inspectState.steps.reduce(into: Set<String>()) { $0.formUnion(secureFieldIds(in: $1.content)) }
    }

    func stopFileMonitoring() {
        commandRouter.stopMonitoring()
    }
}
