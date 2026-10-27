//
//  StepCompletion.swift
//  dialog
//
//  Processing-step rules for the step presets: what a step does when it starts, when its countdown
//  ends, and how a result (`success:`, `failure:`, `warning:`, an override) is recorded.
//

import Foundation

enum ProcessingFlow {
    enum Start: Equatable {
        /// No countdown and nothing to wait for: the step completes at once.
        case completeNow(InspectCompletionResult)
        /// No countdown, `waitForExternalTrigger`: wait for `success:` / `failure:`.
        case wait
        /// Count down this many seconds, then `afterCountdown`.
        case countdown(seconds: Int)
    }

    enum AfterCountdown: Equatable {
        /// `waitForExternalTrigger`, or `processingMode: "progressive"`: wait for a trigger.
        case wait
        /// The step's own result: `autoResult` ("failure" for demos), else success.
        case complete(InspectCompletionResult)
    }

    static func start(_ step: InspectConfig.IntroStep) -> Start {
        if let duration = step.processingDuration, duration > 0 { return .countdown(seconds: duration) }
        if step.waitForExternalTrigger == true { return .wait }
        return .completeNow(.success(message: step.successMessage))
    }

    /// The override tier for a step that has waited `waited` seconds. Opt-in via `allowOverride`
    /// (default false): a step that does not opt in never offers one.
    static func overrideLevel(for step: InspectConfig.IntroStep?, waited: Int) -> InspectOverrideLevel {
        guard step?.allowOverride == true else { return .none }
        return InspectOverrideLevel.level(for: waited)
    }

    /// Whether a completed processing step moves the flow on by itself: `autoAdvance`, no
    /// `requireManualConfirm`, and not a failure (a failure stays on screen to be read).
    static func advancesAfterCompletion(_ step: InspectConfig.IntroStep, result: InspectCompletionResult) -> Bool {
        guard step.autoAdvance == true, step.requireManualConfirm != true else { return false }
        if case .failure = result { return false }
        return true
    }

    static func afterCountdown(_ step: InspectConfig.IntroStep) -> AfterCountdown {
        if step.waitForExternalTrigger == true || step.processingMode == "progressive" { return .wait }
        if (step.autoResult ?? "success") == "failure" {
            return .complete(.failure(message: step.failureMessage ?? "Operation failed"))
        }
        return .complete(.success(message: step.successMessage))
    }
}

enum StepCompletion {
    enum Effect: Equatable {
        /// No step has this id: nothing is recorded.
        case unknownStep
        /// `requireManualConfirm`: the result is recorded, but the step does not complete — the
        /// user's click does. The processing clock keeps running.
        case awaitingConfirm
        /// The step completed with this result: stop its clock, then advance as the preset does.
        case completed
    }

    static func resultKey(_ stepId: String) -> String { "processingResult_\(stepId)" }

    // swiftlint:disable function_parameter_count
    /// Records `result` for `stepId`: `processingResult_<id>` = success | warning | failed |
    /// skipped (what `showWhen` reads), plus the completed / failed / skipped stores. With
    /// `requireManualConfirm` only the result is recorded until the user's click, unless
    /// `confirmed` (an override the user chose is its own confirmation).
    static func record(_ result: InspectCompletionResult, stepId: String,
                       steps: [InspectConfig.IntroStep], confirmed: Bool = false,
                       completed: inout Set<String>, failed: inout [String: String],
                       skipped: inout Set<String>, values: inout [String: String]) -> Effect {
        // swiftlint:enable function_parameter_count
        guard let step = steps.first(where: { $0.id == stepId }) else { return .unknownStep }
        let key = resultKey(stepId)

        if step.requireManualConfirm == true && !confirmed {
            switch result {
            case .success: values[key] = "success"
            case .warning: values[key] = "warning"
            case .failure(let message):
                failed[stepId] = message ?? "Step failed"
                values[key] = "failed"
            case .cancelled: values[key] = "skipped"
            }
            return .awaitingConfirm
        }

        completed.insert(stepId)
        switch result {
        case .success:
            failed.removeValue(forKey: stepId); skipped.remove(stepId); values[key] = "success"
        case .warning:
            failed.removeValue(forKey: stepId); skipped.remove(stepId); values[key] = "warning"
        case .failure(let message):
            failed[stepId] = message ?? "Step failed"; skipped.remove(stepId); values[key] = "failed"
        case .cancelled:
            failed.removeValue(forKey: stepId); skipped.insert(stepId); values[key] = "skipped"
        }
        return .completed
    }

    /// A retry: the step is outstanding again. The recorded result is cleared too, so
    /// `processingResult_<id>` readers do not still see the failure the retry replaces.
    static func reset(stepId: String, completed: inout Set<String>, failed: inout [String: String],
                      skipped: inout Set<String>, values: inout [String: String]) {
        completed.remove(stepId)
        failed.removeValue(forKey: stepId)
        skipped.remove(stepId)
        values.removeValue(forKey: resultKey(stepId))
    }

    /// Completes a `requireManualConfirm` step with its recorded result. Returns false when nothing
    /// is recorded yet (the click is then an ordinary Continue).
    static func confirm(stepId: String, completed: inout Set<String>, failed: inout [String: String],
                        skipped: inout Set<String>, values: [String: String]) -> Bool {
        guard let recorded = values[resultKey(stepId)] else { return false }
        completed.insert(stepId)
        switch recorded {
        case "failed":
            if failed[stepId] == nil { failed[stepId] = "Step failed" }
            skipped.remove(stepId)
        case "skipped":
            failed.removeValue(forKey: stepId); skipped.insert(stepId)
        default:   // success, warning
            failed.removeValue(forKey: stepId); skipped.remove(stepId)
        }
        return true
    }
}
