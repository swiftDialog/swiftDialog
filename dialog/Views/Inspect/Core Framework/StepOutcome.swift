//
//  StepOutcome.swift
//  dialog
//
//  Records what a flow has done into `InspectState.userValues` so a later step's `showWhen` can
//  depend on it: `items.done` / `items.failed` (ids in config order) and `<stepId>.done` /
//  `<stepId>.failed` for a progress step. Also the rule that picks which step shows next.
//

import Foundation

enum StepOutcome {
    static let itemsScope = "items"

    static func doneKey(_ scope: String) -> String { "\(scope).done" }
    static func failedKey(_ scope: String) -> String { "\(scope).failed" }

    /// Writes `<scope>.done` and `<scope>.failed`, comma-joined like every multi-value pick.
    static func record(into values: inout [String: String], scope: String,
                       done: [String], failed: [String]) {
        let doneValue = done.joined(separator: ",")
        let failedValue = failed.joined(separator: ",")
        // userValues is published; an unchanged write would redraw every screen reading it.
        if values[doneKey(scope)] != doneValue { values[doneKey(scope)] = doneValue }
        if values[failedKey(scope)] != failedValue { values[failedKey(scope)] = failedValue }
    }

    /// Completed and failed ids in config order. An item in both sets is failed, never done.
    static func items(_ ids: [String], completed: Set<String>, failed: Set<String>)
        -> (done: [String], failed: [String]) {
        (ids.filter { completed.contains($0) && !failed.contains($0) },
         ids.filter { failed.contains($0) })
    }
}

/// Which steps show. A step is passed over, forward and back, when its `showWhen` does not match
/// the recorded values, or when it has `skipIfComplete`, is not `revisitable`, and is satisfied.
enum StepVisibility {
    static func isShown(_ step: InspectConfig.IntroStep, values: [String: String]) -> Bool {
        step.showWhen?.matches(values) ?? true
    }

    static func isSkipped(_ step: InspectConfig.IntroStep, values: [String: String],
                          isSatisfied: (InspectConfig.IntroStep) -> Bool) -> Bool {
        if !isShown(step, values: values) { return true }
        guard step.skipIfComplete == true, step.revisitable != true else { return false }
        return isSatisfied(step)
    }

    /// Whether a pick is recorded for the step's chooser (options, dock or wallpaper).
    static func hasRecordedPick(_ step: InspectConfig.IntroStep, userValues: [String: String],
                                dockSelection: [String: String], wallpaperSelection: [String: String]) -> Bool {
        if let key = step.optionKey ?? (step.optionCards != nil ? step.id : nil),
           let v = userValues[key], !v.isEmpty { return true }
        if let key = step.dockSelectionKey ?? ((step.dockFlavors != nil || step.dockItems != nil) ? step.id : nil),
           let v = dockSelection[key], !v.isEmpty { return true }
        if let key = step.wallpaperSelectionKey ?? (step.wallpaperCategories != nil ? step.id : nil),
           let v = wallpaperSelection[key], !v.isEmpty { return true }
        return false
    }

    /// The first step after `index` that is not skipped; nil when none is (the flow is at its end).
    static func next(after index: Int, in steps: [InspectConfig.IntroStep], values: [String: String],
                     isSatisfied: (InspectConfig.IntroStep) -> Bool = { _ in false }) -> Int? {
        guard index + 1 < steps.count else { return nil }
        return (index + 1..<steps.count).first { !isSkipped(steps[$0], values: values, isSatisfied: isSatisfied) }
    }

    /// The last step before `index` that is not skipped; nil when none is.
    static func previous(before index: Int, in steps: [InspectConfig.IntroStep], values: [String: String],
                         isSatisfied: (InspectConfig.IntroStep) -> Bool = { _ in false }) -> Int? {
        guard index > 0 else { return nil }
        return (0..<min(index, steps.count)).reversed().first {
            !isSkipped(steps[$0], values: values, isSatisfied: isSatisfied)
        }
    }
}
