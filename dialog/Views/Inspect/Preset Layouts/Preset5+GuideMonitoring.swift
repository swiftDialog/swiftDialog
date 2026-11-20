//
//  Preset5+GuideMonitoring.swift
//  dialog
//
//  Preset5View's guide condition monitoring (plist/file checks): the per-step guide watch and
//  the per-line checklist watch.
//

import SwiftUI

extension Preset5View {

    // MARK: - Guide Monitoring

    /// Starts the guide watch: an immediate check, then a 5 s poll on the main actor.
    func startGuideMonitoring() {
        stopGuideMonitoring()

        evaluateAllGuideSteps()

        let poll = Poll(every: 5.0)
        guideMonitoringPoll = poll
        poll.start { self.evaluateAllGuideSteps() }
        writeLog("Preset5: Started guide monitoring timer", logLevel: .debug)
    }

    /// Whether the guide watch runs: a guide step with `paths`, or any step's checklist with a
    /// watched line. The preset root owns the lifecycle.
    nonisolated static func needsGuideWatch(_ steps: [InspectConfig.IntroStep]) -> Bool {
        steps.contains { $0.stepType == "guide" && ($0.paths ?? []).isEmpty == false }
            || ChecklistLineMonitor.hasWatchedLines(in: steps)
    }

    func stopGuideMonitoring() {
        guideMonitoringPoll?.cancel()
        guideMonitoringPoll = nil
    }

    /// Evaluates every guide step's paths and every step's watched checklist lines.
    func evaluateAllGuideSteps() {
        for step in allSteps where step.stepType == "guide" {
            evaluateGuideStep(step)
        }
        // Checklists ride any step type, so the per-line watch walks every step.
        for step in allSteps {
            evaluateChecklistLines(for: step)
        }
    }

    /// Evaluates one guide step's paths and plist condition, at most once per 2 s.
    func evaluateGuideStep(_ step: InspectConfig.IntroStep) {
        guard let paths = step.paths, !paths.isEmpty else { return }

        let now = Date()
        if let lastTime = guideLastValidationTime[step.id],
           now.timeIntervalSince(lastTime) < 2.0 {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let pathExists = paths.contains { FileManager.default.fileExists(atPath: $0) }

            var plistValid = true
            if let plistKey = step.plistKey {
                if let plistPath = paths.first(where: { $0.hasSuffix(".plist") }) {
                    plistValid = self.evaluatePlistCondition(
                        plistPath: plistPath,
                        key: plistKey,
                        expectedValue: step.expectedValue,
                        evaluation: EvaluationOperator
                            .resolve(evaluation: step.evaluation,
                                     expectedValue: step.expectedValue)?.rawValue
                            ?? (step.evaluation ?? "")
                    )
                }
            }

            let isValid = pathExists && plistValid

            DispatchQueue.main.async {
                self.guideValidationCache[step.id] = isValid
                self.guideLastValidationTime[step.id] = now

                if isValid {
                    self.guideCompletedSteps.insert(step.id)
                } else {
                    self.guideCompletedSteps.remove(step.id)
                }
            }
        }
    }

    /// The per-line watch: one answer per checklist line, cached in `checklistLineSatisfied`.
    /// The evaluator is `ChecklistLineMonitor`, shared with Preset 6.
    func evaluateChecklistLines(for step: InspectConfig.IntroStep) {
        guard let lines = step.content?.first(where: { $0.type == "checklist" })?.checklist,
              !lines.isEmpty else { return }

        let existing = checklistLineSatisfied[step.id]
        let baseline = (existing?.count == lines.count) ? existing! : Array(repeating: false, count: lines.count)

        guard ChecklistLineMonitor.hasWork(lines: lines, baseline: baseline) else { return }

        ChecklistLineMonitor.evaluate(step: step, baseline: baseline) { results in
            self.checklistLineSatisfied[step.id] = results
        }
    }

    /// Evaluates a plist condition through `ChecklistLineMonitor`, the one evaluator both watches read.
    nonisolated func evaluatePlistCondition(plistPath: String, key: String, expectedValue: String?, evaluation: String) -> Bool {
        ChecklistLineMonitor.evaluatePlistCondition(plistPath: plistPath, key: key,
                                                     expectedValue: expectedValue, evaluation: evaluation)
    }
}
