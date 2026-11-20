//
//  ChecklistLineMonitor.swift
//  dialog
//
//  Evaluates watched checklist lines (paths and plist conditions) for Preset5View and Preset6View.
//  Each preset owns its own cache and poll; the evaluation and the `hasWatchedLines` gate are shared.
//

import Foundation

enum ChecklistLineMonitor {

    /// True when a watched line (one with `paths`) is still unresolved; must agree with
    /// `ChecklistState.resolve` on what counts as unwatched.
    static func hasWork(lines: [InspectConfig.GuidanceContent.ChecklistLine], baseline: [Bool]) -> Bool {
        lines.indices.contains { i in
            guard let paths = lines[i].paths, !paths.isEmpty else { return false }
            return i >= baseline.count || !baseline[i]
        }
    }

    /// The gate both presets start their poll on: any step's first checklist block has a line with
    /// `paths`, whatever the step's type.
    static func hasWatchedLines(in steps: [InspectConfig.IntroStep]) -> Bool {
        steps.contains { step in
            guard let lines = step.content?.first(where: { $0.type == "checklist" })?.checklist else {
                return false
            }
            return lines.contains { ($0.paths ?? []).isEmpty == false }
        }
    }

    /// Evaluates a step's first checklist block off the main thread and delivers per-line results
    /// on the main thread. Lines already `true` in `baseline` are not re-checked.
    static func evaluate(step: InspectConfig.IntroStep, baseline: [Bool],
                          completion: @escaping @MainActor @Sendable ([Bool]) -> Void) {
        guard let lines = step.content?.first(where: { $0.type == "checklist" })?.checklist,
              !lines.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var results = baseline.count == lines.count ? baseline : Array(repeating: false, count: lines.count)
            for (index, line) in lines.enumerated() {
                if results[index] { continue }
                guard let paths = line.paths, !paths.isEmpty else { continue }

                let pathExists = paths.contains { FileManager.default.fileExists(atPath: $0) }
                var plistValid = true
                if let plistKey = line.plistKey,
                   let plistPath = paths.first(where: { $0.hasSuffix(".plist") }) {
                    plistValid = evaluatePlistCondition(
                        plistPath: plistPath,
                        key: plistKey,
                        expectedValue: line.expectedValue,
                        evaluation: EvaluationOperator
                            .resolve(evaluation: line.evaluation, expectedValue: line.expectedValue)?.rawValue
                            ?? (line.evaluation ?? "")
                    )
                }
                results[index] = pathExists && plistValid
            }

            let finished = results
            DispatchQueue.main.async {
                completion(finished)
            }
        }
    }

    /// The one plist check for every watch; Preset5View's per-step watch forwards here too.
    static func evaluatePlistCondition(plistPath: String, key: String, expectedValue: String?, evaluation: String) -> Bool {
        guard let plistData = NSDictionary(contentsOfFile: plistPath),
              let value = plistData[key] else {
            return false
        }

        switch EvaluationOperator(authored: evaluation) {
        case .exists:
            return true
        case .boolean:
            if let boolVal = value as? Bool { return boolVal }
            if let strVal = value as? String { return strVal.lowercased() == "true" || strVal == "1" }
            return false
        case .equals:
            guard let expected = expectedValue else { return false }
            return "\(value)" == expected
        case .contains:
            return EvaluationOperator.containsMatch(value: value, expected: expectedValue)
        case .range, .changed, .withinSeconds, nil:
            // Not supported for guide steps; unrecognised names land here too.
            return false
        }
    }
}
