//
//  Preset5+Persistence.swift
//  dialog
//
//  Preset5View's resumable state in UserDefaults, trigger-file paths, launch initialization and
//  the step/selection outputs scripts read.
//

import SwiftUI

extension Preset5View {

    // MARK: - State Persistence (UserDefaults)

    /// The UserDefaults domain for resumable state (default com.swiftdialog.preset5).
    var stateDomain: String {
        portalConfig?.stateDomain ?? "com.swiftdialog.preset5"
    }

    var stateDefaults: UserDefaults {
        UserDefaults(suiteName: stateDomain) ?? .standard
    }

    var stepsAlreadyCompleted: Bool {
        stateDefaults.bool(forKey: "stepsCompleted")
    }

    var lastCompletedStepIndex: Int {
        stateDefaults.integer(forKey: "lastStepIndex")
    }

    var savedSelections: [String: [String]] {
        stateDefaults.dictionary(forKey: "selections") as? [String: [String]] ?? [:]
    }

    // MARK: - Trigger File Configuration

    /// The shared trigger-file ladder: custom, dev, PID-scoped.
    var triggerFilePath: String {
        presetTriggerFilePath(config: config)
    }

    /// The `_final` trigger file, written with the completion state.
    var finalTriggerFilePath: String {
        presetFinalTriggerFilePath(config: config)
    }

    /// The trigger mode named in logs.
    var triggerMode: String {
        if config?.triggerFile != nil {
            return "custom"
        }
        return appArguments.inspectMode.present ? "dev" : "prod"
    }
    /// Clears all persisted state, including the brand selection and legacy keys.
    func resetState() {
        stateDefaults.removeObject(forKey: "stepsCompleted")
        stateDefaults.removeObject(forKey: "stepsCompletedAt")
        stateDefaults.removeObject(forKey: "lastStepIndex")
        stateDefaults.removeObject(forKey: "selections")
        let brandKey = config?.brandSelectionKey ?? "selectedBrand"
        stateDefaults.removeObject(forKey: brandKey)
        selectedBrandId = nil
        stateDefaults.removeObject(forKey: "introCompleted")
        stateDefaults.removeObject(forKey: "outroCompleted")
        stateDefaults.removeObject(forKey: "introCompletedAt")
        stateDefaults.removeObject(forKey: "outroCompletedAt")
        stateDefaults.synchronize()
        writeLog("Preset5: Reset state in UserDefaults domain: \(stateDomain)", logLevel: .info)
    }
    /// Picks the starting step at launch: resume, skip-completed, or step 0; then starts services.
    func initializePhase() {
        writeLog("Preset5.initializePhase: config=\(config != nil), allSteps count=\(allSteps.count)", logLevel: .debug)

        // Without resumable, stale state from a prior run must not short-circuit this launch.
        // DIALOG_KEEP_STALE_STATE=1 keeps it for debugging.
        if config?.resumable != true
            && ProcessInfo.processInfo.environment["DIALOG_KEEP_STALE_STATE"] != "1" {
            resetState()
            writeLog("Preset5: resumable != true, cleared stale UserDefaults suite '\(stateDomain)'", logLevel: .info)
        }

        initializePreferencesService()

        if let locConfig = config?.localization {
            localizationService.loadLanguages(from: locConfig, iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                               configPath: inspectState.configPath)
        }

        // A saved brand is restored only while it is still an allowed brand.
        let brandKey = config?.brandSelectionKey ?? "selectedBrand"
        if let saved = stateDefaults.string(forKey: brandKey),
           resolvedAvailableBrands.contains(where: { $0.id == saved }) {
            selectedBrandId = saved
            writeLog("Preset5: Restored brand selection '\(saved)'", logLevel: .info)
        } else {
            stateDefaults.removeObject(forKey: brandKey)
        }

        // shouldSkipCompletedSteps is false in debug mode (debugMode or DIALOG_DEBUG_MODE).
        if inspectState.shouldSkipCompletedSteps && stateDefaults.bool(forKey: "stepsCompleted") {
            writeLog("Preset5: Steps already completed, closing", logLevel: .info)
            handleButton1()
            return
        }

        let savedStepIndex = stateDefaults.integer(forKey: "lastStepIndex")
        if inspectState.shouldSkipCompletedSteps && savedStepIndex > 0 && savedStepIndex < allSteps.count {
            writeLog("Preset5: Resuming from saved step index \(savedStepIndex)", logLevel: .info)
            currentStepIndex = savedStepIndex
        } else if hasSteps {
            if !inspectState.shouldSkipCompletedSteps {
                writeLog("Preset5: Debug mode active, starting from step 0", logLevel: .info)
            } else {
                writeLog("Preset5: Starting with first step", logLevel: .info)
            }
            currentStepIndex = 0
        } else {
            writeLog("Preset5: No steps configured, closing", logLevel: .info)
            handleButton1()
            return
        }

        // Leading steps an orchestrator pre-answered are skipped.
        if hasSteps {
            let firstVisible = nextVisibleIndex(from: currentStepIndex)
            if firstVisible >= allSteps.count {
                writeLog("Preset5: All steps already satisfied at launch, finishing", logLevel: .info)
                handleCompletion()
                return
            }
            currentStepIndex = firstVisible
        }

        if currentStepIndex < allSteps.count {
            writeStepEvent("step_started", stepId: allSteps[currentStepIndex].id)
        }

        if isPortalStep {
            setupPortal()
        }

        if let plistSources = config?.plistSources, !plistSources.isEmpty {
            writeLog("Preset5: Starting ComplianceAggregatorService with \(plistSources.count) sources", logLevel: .info)
            complianceService.startMonitoring(sources: plistSources, refreshInterval: 5.0)
        } else {
            writeLog("Preset5: No plistSources configured, compliance service not started", logLevel: .info)
        }

        setupCommandRouter()

        // Signals readiness to external launchers.
        writeReadinessFile(config: config, triggerFilePath: triggerFilePath,
                           preset: "5", itemCount: allSteps.count,
                           itemIDs: allSteps.map { $0.id })
    }
    // MARK: - Output Functions

    /// Prints `intro_step: <id> - <action>` for scripts and posts the distributed notification.
    func writeStepOutput(stepId: String, action: String) {
        let output = "intro_step: \(stepId) - \(action)"
        writeLog("Preset5 Output: \(output)", logLevel: .info)
        print(output)
        // Not mirrored to the event file: writeStepEvent already appends the richer line.
        DialogNotifications.postStepChange(stepId: stepId, action: action, mirrorToFile: false)
    }

    /// Prints `selection: <key> = a,b` for scripts and posts the distributed notification.
    func writeSelectionOutput(key: String, selections: [String]) {
        let selectionsString = selections.joined(separator: ",")
        let output = "selection: \(key) = \(selectionsString)"
        writeLog("Preset5 Output: \(output)", logLevel: .info)
        print(output)
        DialogNotifications.postSelection(key: key, values: selections)
    }

    /// Prints the final selections and form values, then `preset5_complete: true`.
    /// Wallpaper selections are already in the interaction log.
    func writeFinalOutput() {
        for (key, values) in gridSelections {
            let selectionsString = Array(values).joined(separator: ",")
            print("final_selection: \(key) = \(selectionsString)")
        }

        for (key, value) in legacyFormValues {
            print("form_value: \(key) = \(value)")
        }

        print("preset5_complete: true")
    }

    /// Appends a step event to the JSONL event file: explicit `eventFile`, else `readinessFile`
    /// with its extension replaced by `.events`. `step_completed` carries the merged form values.
    func writeStepEvent(_ event: String, stepId: String) {
        let eventPath: String? = config?.eventFile ?? config?.readinessFile.map {
            (($0 as NSString).deletingPathExtension) + ".events"
        }
        guard let path = eventPath else { return }

        var entry: [String: Any] = [
            "event": event,
            "stepId": stepId,
            "stepIndex": currentStepIndex,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if event == "step_completed" {
            let flattenedFormValues = exportedFormValues
            writeLog("writeStepEvent: formValues=\(flattenedFormValues) wallpaperSelection=\(inspectState.wallpaperSelection) dockSelection=\(inspectState.dockSelection)", logLevel: .debug)
            var mergedValues = flattenedFormValues
            for (key, path) in inspectState.wallpaperSelection {
                mergedValues[key] = path
            }
            for (key, value) in inspectState.userValues {
                mergedValues[key] = value
            }
            // Dock choices are ordered app paths, comma-joined.
            for (key, value) in inspectState.dockSelection {
                mergedValues[key] = value
            }
            if !mergedValues.isEmpty {
                entry["formValues"] = mergedValues
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8) else { return }

        let expandedPath = (path as NSString).expandingTildeInPath
        let lineData = (line + "\n").data(using: .utf8)!
        if let handle = FileHandle(forWritingAtPath: expandedPath) {
            handle.seekToEndOfFile()
            handle.write(lineData)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: expandedPath, contents: lineData)
        }
    }
}
