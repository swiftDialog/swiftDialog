//
//  Preset6+Persistence.swift
//  dialog
//
//  Preset 6 extension: resumable state, final trigger/result files and interaction logging.
//

import SwiftUI

extension Preset6View {
    // MARK: - Persistence

    func loadPersistedState() {
        guard inspectState.config?.resumable == true else {
            // Without resumable, clear any stale state file so it cannot skip a fresh run.
            // DIALOG_KEEP_STALE_STATE=1 keeps it for debugging.
            if ProcessInfo.processInfo.environment["DIALOG_KEEP_STALE_STATE"] != "1" {
                persistenceService.clearState()
                writeLog("Preset6: resumable != true, cleared stale persistence file", logLevel: .info)
            } else {
                writeLog("Preset6: Resumable mode not enabled, starting fresh (stale state preserved via DIALOG_KEEP_STALE_STATE=1)", logLevel: .debug)
            }
            return
        }

        guard let state = persistenceService.loadState() else {
            writeLog("Preset6: No persisted state found", logLevel: .debug)
            return
        }

        completedSteps = state.completedSteps
        currentStep = min(state.currentStep, inspectState.steps.count - 1)

        for (itemId, formState) in state.guidanceFormInputs {
            inspectState.guidanceFormInputs[itemId] = formState
        }

        writeLog("Preset6: Restored state - step \(currentStep), \(completedSteps.count) completed", logLevel: .info)
    }

    func savePersistedState() {
        guard inspectState.config?.resumable == true else { return }

        let state = Preset6State(
            completedSteps: completedSteps,
            currentStep: currentStep,
            guidanceFormInputs: inspectState.guidanceFormInputs,
            timestamp: Date()
        )

        persistenceService.saveState(state)
        writeLog("Preset6: Saved state", logLevel: .debug)
    }

    func writeFinalTriggerFile() {
        var output: [String] = []
        output.append("preset6_completed")
        output.append("completed_steps:\(completedSteps.joined(separator: ","))")
        output.append("failed_steps:\(failedSteps.keys.joined(separator: ","))")
        output.append("skipped_steps:\(skippedSteps.joined(separator: ","))")
        output.append("timestamp:\(ISO8601DateFormatter().string(from: Date()))")

        let content = output.joined(separator: "\n")
        try? content.write(toFile: finalTriggerFilePath, atomically: true, encoding: .utf8)

        writeFinalStatePlist()

        writeLog("Preset6: Wrote final trigger file", logLevel: .info)
        logPreset6Event("workflow_completed", details: [
            "completedSteps": completedSteps.count,
            "failedSteps": failedSteps.count,
            "skippedSteps": skippedSteps.count
        ])
        writeInteractionLog("completed", step: "all_steps")
    }

    func writeFinalStatePlist() {
        var finalState: [String: Any] = [
            "completed": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "completedSteps": Array(completedSteps),
            "failedSteps": failedSteps,
            "skippedSteps": Array(skippedSteps),
            "currentStep": currentStep,
            "totalSteps": inspectState.steps.count
        ]

        if !inspectState.guidanceFormInputs.isEmpty {
            var formData: [String: Any] = [:]
            for (itemId, formState) in inspectState.guidanceFormInputs {
                var itemData: [String: Any] = [:]
                // Secure text fields are never written to disk.
                for (fieldId, value) in formState.textfields where !secureStepFieldIds.contains(fieldId) {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.dropdowns {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.radios {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.toggles {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.checkboxes {
                    itemData[fieldId] = value
                }
                for (fieldId, value) in formState.sliders {
                    itemData[fieldId] = value
                }
                formData[itemId] = itemData
            }
            finalState["formInputs"] = formData
        }

        if let plistData = try? PropertyListSerialization.data(fromPropertyList: finalState,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: interactionPlistPath), options: .atomic)
        }
    }

    // MARK: - Interaction Logging

    func logPreset6Event(_ event: String, details: [String: Any] = [:]) {
        var logDetails = details
        logDetails["preset"] = "6"
        logDetails["currentStep"] = currentStep
        logDetails["totalSteps"] = inspectState.steps.count
        logDetails["completedSteps"] = completedSteps.count

        let detailsString = logDetails.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        writeLog("Preset6: \(event) - \(detailsString)", logLevel: .info)

        // Scripts watch stdout for this line.
        print("[PRESET6_EVENT] \(event) \(detailsString)")
    }

    func writeInteractionLog(_ event: String, step: String) {
        writeInteractionLog(event, step: step, data: [:])
    }

    func writeInteractionLog(_ event: String, step: String, data: [String: Any]) {
        print("[PRESET6_INTERACTION] event=\(event) step=\(step) current=\(currentStep) completed=\(completedSteps.count)")

        var interaction: [String: Any] = [
            "timestamp": Date(),
            "event": event,
            "step": step,
            "currentStep": currentStep,
            "completedSteps": Array(completedSteps),
            "completedCount": completedSteps.count
        ]

        interaction.merge(data) { (_, new) in new }

        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interaction,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: interactionPlistPath), options: .atomic)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        var extraFields = ""
        for (key, value) in data {
            extraFields += " \(key)=\(value)"
        }

        let logEntry = "\(timestamp) event=\(event) step=\(step) current=\(currentStep) completed=\(Array(completedSteps).joined(separator: ","))\(extraFields)\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: interactionLogPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: interactionLogPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: interactionLogPath))
            }
        }
    }
}
