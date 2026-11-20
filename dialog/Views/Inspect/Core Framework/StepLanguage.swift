//
//  StepLanguage.swift
//  dialog
//
//  The language a step flow (Presets 5 and 6) uses. A pick from a picker in the flow translates its step
//  and later ones; any other pick, or the default language, translates every step.
//

import Foundation

enum StepLanguage {
    static func key(_ config: InspectConfig?) -> String {
        config?.localization?.selectionKey ?? "preferredLanguage"
    }

    /// The picked language, in this order: a grid picker, a recorded value (option picker,
    /// IPC, MDM), a dropdown/radio block in a step's content. nil when nothing is picked.
    static func manualSelection(key: String, steps: [InspectConfig.IntroStep],
                                userValues: [String: String],
                                formInputs: [String: GuidanceFormInputState],
                                gridSelections: [String: Set<String>] = [:]) -> String? {
        if let grid = gridSelections[key]?.first { return grid }
        if let value = userValues[key], !value.isEmpty { return value }
        guard let step = steps.first(where: { $0.content?.contains { $0.id == key } ?? false }),
              let form = formInputs[step.id] else { return nil }
        return form.dropdowns[key] ?? form.radios[key]
    }

    /// The step that holds the flow's language picker — a grid, an option step, or a block.
    static func pickerIndex(key: String, steps: [InspectConfig.IntroStep]) -> Int? {
        steps.firstIndex { step in
            step.gridSelectionKey == key || step.optionKey == key
                || (step.content?.contains { $0.id == key } ?? false)
        }
    }

    /// Whether the step at `stepIndex` is translated: always, unless the language was picked by a
    /// picker in the flow — then the picker's step and the steps after it.
    static func applies(isManual: Bool, pickerIndex: Int?, stepIndex: Int?) -> Bool {
        guard isManual, let pickerIndex else { return true }
        guard let stepIndex else { return false }
        return stepIndex >= pickerIndex
    }
}
