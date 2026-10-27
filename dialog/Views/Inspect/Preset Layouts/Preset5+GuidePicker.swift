//
//  Preset5+GuidePicker.swift
//  dialog
//
//  3.1.1 guide picker mode, restored: `pickerConfig.selectionMode` makes `selectable` steps choosable,
//  and Finish writes the selections plist scripts read (`selectedItem` / `selectedItems[].id`).
//

import Foundation

/// The selection rules and the plist shape, kept pure so they can be tested without a view.
enum GuidePicker {
    static let defaultOutputPath = "/tmp/preset5_guide_selections.plist"

    static func isActive(_ picker: InspectConfig.PickerConfig?) -> Bool {
        picker?.selectionMode == "single" || picker?.selectionMode == "multi"
    }

    /// Single mode is exclusive; multi toggles each step on its own.
    static func toggled(_ selections: Set<String>, id: String, mode: String?) -> Set<String> {
        if mode == "single" { return selections.contains(id) ? [] : [id] }
        return selections.symmetricDifference([id])
    }

    static func canFinish(_ picker: InspectConfig.PickerConfig?, selections: Set<String>) -> Bool {
        !isActive(picker) || picker?.allowContinueWithoutSelection == true || !selections.isEmpty
    }

    /// The 3.1.1 plist: `selectedItem` in single mode, `selectedItems` + `selectionCount` otherwise,
    /// each entry `{id, title}`, in step order.
    static func output(mode: String, selections: Set<String>, steps: [InspectConfig.IntroStep],
                       now: Date = Date()) -> [String: Any] {
        let chosen = steps.filter { selections.contains($0.id) }.map { ["id": $0.id, "title": $0.title ?? $0.id] }
        var out: [String: Any] = ["timestamp": now, "selectionMode": mode]
        if mode == "single" {
            if let first = chosen.first { out["selectedItem"] = first }
        } else {
            out["selectedItems"] = chosen
            out["selectionCount"] = chosen.count
        }
        return out
    }
}

extension Preset5View {
    var isGuidePickerMode: Bool { GuidePicker.isActive(config?.pickerConfig) }

    func isGuidePickable(_ step: InspectConfig.IntroStep) -> Bool {
        isGuidePickerMode && step.selectable == true
    }

    func toggleGuideSelection(_ step: InspectConfig.IntroStep) {
        guideSelections = GuidePicker.toggled(guideSelections, id: step.id, mode: config?.pickerConfig?.selectionMode)
        writeLog("Preset5: Guide picker toggled \(step.id): \(guideSelections.contains(step.id))", logLevel: .info)
    }

    /// Finish is held until something is selected, unless `allowContinueWithoutSelection`.
    var guidePickerAllowsFinish: Bool {
        GuidePicker.canFinish(config?.pickerConfig, selections: guideSelections)
    }

    func writeGuideSelectionsToOutput() {
        guard let picker = config?.pickerConfig, isGuidePickerMode, picker.returnSelections == true else { return }
        let path = picker.outputPath ?? GuidePicker.defaultOutputPath
        let data = GuidePicker.output(mode: picker.selectionMode ?? "none", selections: guideSelections, steps: allSteps)
        do {
            let plist = try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0)
            try plist.write(to: URL(fileURLWithPath: path), options: .atomic)
            writeLog("Preset5: Wrote guide selections to \(path)", logLevel: .info)
        } catch {
            writeLog("Preset5: Failed to write guide selections: \(error.localizedDescription)", logLevel: .error)
        }
    }
}
