//
//  Preset5+Actions.swift
//  dialog
//
//  Preset 5 extension: form state, compliance helpers and navigation actions.
//

import SwiftUI

extension Preset5View {

    // MARK: - Form State Management
    // Forms write the shared guidanceFormInputs store (keyed by step id) with Preset 5's wire format
    // via `FormWire(dialect: .step3Part)`: `type:fieldId:value` log lines and flat string exports.

    /// Current step id used as the guidanceFormInputs store key.
    var formStoreStepId: String { currentStep?.id ?? "" }

    /// Every block type that holds a form value; the outputs, the preferences plist and the required-field
    /// gate all read this one list. The last seven store their value in `textfields`.
    static let formValueTypes: Set<String> = ["checkbox", "dropdown", "radio", "toggle", "textfield", "slider", "segmented",
                                              "drop-zone", "color-picker", "stepper", "search",
                                              "multi-select", "select-list", "select-grid"]

    /// Whether all required fields in a step are filled (shared validation, as on Preset 6).
    func allRequiredFieldsFilled(step: InspectConfig.IntroStep) -> Bool {
        guard let content = step.content else { return true }

        // Until onAppear seeds the store, any required field counts as unfilled.
        if inspectState.guidanceFormInputs[step.id] == nil {
            return !content.contains { $0.required == true && Self.formValueTypes.contains($0.type) }
        }

        return inspectState.validateGuidanceInputs(content: content, itemId: step.id)
    }

    /// Footer Continue gate for the standard layout: required fields.
    /// Cadence steps use the tile grid and never reach this.
    func standardContinueDisabled(step: InspectConfig.IntroStep) -> Bool {
        return !allRequiredFieldsFilled(step: step)
    }

    /// Seeds form values from the step's inherit sources (plist:path:key, defaults:domain:key, env:NAME) or defaults.
    func initializeFormDefaults(for step: InspectConfig.IntroStep) {
        guard let content = step.content else { return }

        // Preset 5 steps are not in `items`, so the shared initializer creates empty state; values are seeded below.
        inspectState.initializeGuidanceFormState(for: step.id)

        for block in content {
            guard let fieldId = block.id else { continue }
            // Keep existing values when navigating back and forth.
            guard !storedFormValueExists(stepId: step.id, block: block, fieldId: fieldId) else { continue }

            if let inheritSpec = block.inherit {
                if let inherited = inspectState.resolveInheritValue(inheritSpec, basePath: config?.iconBasePath) {
                    seedFormValue(stepId: step.id, block: block, fieldId: fieldId, rawValue: inherited)
                    writeLog("Preset5: Inherited value for '\(fieldId)' from '\(inheritSpec)' = '\(inherited)'", logLevel: .debug)
                    continue
                }
            }

            if let defaultValue = block.value {
                seedFormValue(stepId: step.id, block: block, fieldId: fieldId, rawValue: defaultValue)
            }
        }
    }

    func storedFormValueExists(stepId: String, block: InspectConfig.GuidanceContent, fieldId: String) -> Bool {
        guard let state = inspectState.guidanceFormInputs[stepId] else { return false }
        switch block.type {
        case "checkbox": return state.checkboxes[fieldId] != nil
        case "toggle": return state.toggles[fieldId] != nil
        case "dropdown": return state.dropdowns[fieldId] != nil
        case "radio": return state.radios[fieldId] != nil
        case "slider": return state.sliders[fieldId] != nil
        default: return state.textfields[fieldId] != nil
        }
    }

    /// Seeds one field from a raw string: bools are exactly "true"; sliders accept numbers only.
    func seedFormValue(stepId: String, block: InspectConfig.GuidanceContent, fieldId: String, rawValue: String) {
        switch block.type {
        case "checkbox":
            inspectState.guidanceFormInputs[stepId]?.checkboxes[fieldId] = (rawValue == "true")
        case "toggle":
            inspectState.guidanceFormInputs[stepId]?.toggles[fieldId] = (rawValue == "true")
        case "slider":
            if let number = Double(rawValue) {
                inspectState.guidanceFormInputs[stepId]?.sliders[fieldId] = number
            }
        // `segmented` is stored with dropdowns; otherwise its default would land in `textfields`, unread.
        case "dropdown", "segmented":
            inspectState.guidanceFormInputs[stepId]?.dropdowns[fieldId] = rawValue
        case "radio":
            inspectState.guidanceFormInputs[stepId]?.radios[fieldId] = rawValue
        default:
            inspectState.guidanceFormInputs[stepId]?.textfields[fieldId] = rawValue
        }
    }

    /// Per-view default seeding, a fallback for initializeFormDefaults.
    func seedFormDefaultIfNeeded(block: InspectConfig.GuidanceContent) {
        guard let fieldId = block.id, let defaultValue = block.value,
              let stepId = currentStep?.id else { return }
        if inspectState.guidanceFormInputs[stepId] == nil {
            inspectState.initializeGuidanceFormState(for: stepId)
        }
        guard !storedFormValueExists(stepId: stepId, block: block, fieldId: fieldId) else { return }
        seedFormValue(stepId: stepId, block: block, fieldId: fieldId, rawValue: defaultValue)
    }

    /// One step's form state as flat strings (`fieldId → value`; bools "true"/"false", whole sliders as Int).
    func legacyFormValues(for step: InspectConfig.IntroStep) -> [String: String] {
        guard let content = step.content,
              let state = inspectState.guidanceFormInputs[step.id] else { return [:] }
        var result: [String: String] = [:]
        for block in content {
            guard let fieldId = block.id else { continue }
            switch block.type {
            case "checkbox":
                if let value = state.checkboxes[fieldId] { result[fieldId] = value ? "true" : "false" }
            case "toggle":
                if let value = state.toggles[fieldId] { result[fieldId] = value ? "true" : "false" }
            case "dropdown", "segmented":
                if let value = state.dropdowns[fieldId] { result[fieldId] = value }
            case "radio":
                if let value = state.radios[fieldId] { result[fieldId] = value }
            case "textfield", "color-picker", "stepper", "search":
                if let value = state.textfields[fieldId] { result[fieldId] = value }
            case "drop-zone", "multi-select", "select-list", "select-grid":
                // Several values: comma-joined, as Preset 5 writes multi-select picks everywhere else.
                if let value = state.textfields[fieldId] {
                    result[fieldId] = value.split(whereSeparator: { $0 == "\u{001F}" || $0 == "\n" })
                        .map(String.init).joined(separator: ",")
                }
            case "slider":
                if let value = state.sliders[fieldId] {
                    result[fieldId] = value == value.rounded() ? "\(Int(value))" : "\(value)"
                }
            default:
                continue
            }
        }
        return result
    }

    /// All steps' form values, flat; read by writeResultFile, writeStepEvent and writeFinalOutput.
    /// Steps iterate in config order, so a duplicate field id takes the last step's value.
    var legacyFormValues: [String: String] {
        var result: [String: String] = [:]
        for step in allSteps {
            result.merge(legacyFormValues(for: step)) { _, new in new }
        }
        return result
    }

    /// `legacyFormValues` without secure text fields, for every file this preset writes.
    /// Secure values never reach disk; stdout and an authored `preferences` write still get the full set.
    var exportedFormValues: [String: String] {
        let secureIds = allSteps.reduce(into: Set<String>()) { $0.formUnion(secureFieldIds(in: $1.content)) }
        return legacyFormValues.filter { !secureIds.contains($0.key) }
    }

    // MARK: - Actions

    func loadMDMOverrides() {
        // Load MDM branding overrides when appConfigSource is set.
        mdmOverrides = appConfigService.loadMDMOverrides(source: config?.appConfigSource)
    }

    /// Named hook for "this step's portal is about to load". Empty: there is no per-step portal setup yet.
    func setupPortal() {
    }

    func retryConnection() {
        loadState = .initializing
        showContent = false

        // Ask the calling script for a refresh; it can answer by writing a new URL to portalURLFile.
        inspectState.writeToInteractionLog("portal:refresh")
        writeLog("Preset5: Portal refresh requested", logLevel: .info)
    }

    func refetch() {
        withAnimation(.linear(duration: 0.5)) {
            isRefetching = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefetching = false
        }

        loadState = .loading
        showContent = false

        // Rotating the id rebuilds the web view with a fresh coordinator: setting loadState alone does not
        // reload a page already at that URL or retry a failed one.
        portalViewId = UUID()
    }

    func handleButton1() {
        let portalCfg = effectivePortalConfig
        let selfServiceOnly = portalCfg?.selfServiceOnly ?? false

        // On a portal step with more steps (and not self-service only), advance.
        if isPortalStep && currentStepIndex + 1 < allSteps.count && !selfServiceOnly {
            goToNextStep()
        } else {
            preferencesService?.writeOnExitIfNeeded()

            // Write the result file and clean up the readiness signal; the final step counts as completed.
            var allCompleted = completedNavigatedSteps.union(completedProcessingSteps)
            if let step = currentStep { allCompleted.insert(step.id) }
            let stepInfos = allSteps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }
            writeResultFile(
                config: config, exitCode: 0, steps: stepInfos,
                completedSteps: allCompleted, failedSteps: failedSteps,
                skippedSteps: skippedSteps, currentStepIndex: currentStepIndex,
                formValues: exportedFormValues, selections: mergedResultSelections,
                selectedBrand: selectedBrandId
            )
            cleanupReadinessFile(config: config, triggerFilePath: triggerFilePath,
                                 exitCode: 0, completedCount: allCompleted.count,
                                 failedCount: failedSteps.count,
                                 totalSteps: allSteps.count)

            quitDialog(exitCode: 0)
        }
    }

    func handleButton2() {
        if ButtonExit.minimizeInsteadOfExiting(config?.button2Action, label: "Preset5") { return }
        // Write the result file and clean up the readiness signal before cancelling.
        let allCompleted = completedNavigatedSteps.union(completedProcessingSteps)
        let stepInfos = allSteps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }
        writeResultFile(
            config: config, exitCode: 2, steps: stepInfos,
            completedSteps: allCompleted, failedSteps: failedSteps,
            skippedSteps: skippedSteps, currentStepIndex: currentStepIndex,
            formValues: exportedFormValues, selections: mergedResultSelections,
            selectedBrand: selectedBrandId
        )
        cleanupReadinessFile(config: config, triggerFilePath: triggerFilePath,
                             exitCode: 2, completedCount: allCompleted.count,
                             failedCount: failedSteps.count,
                             totalSteps: allSteps.count)

        quitDialog(exitCode: 2)
    }
}
