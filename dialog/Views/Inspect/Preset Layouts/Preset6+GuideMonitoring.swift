//
//  Preset6+GuideMonitoring.swift
//  dialog
//
//  Preset 6 extension: owns the per-line checklist cache and its poll timer.
//  Evaluation itself lives in `ChecklistLineMonitor`, shared with Preset 5.
//

import SwiftUI

extension Preset6View {

    /// Whether any step's checklist block has a watched line; the poll only runs when one does.
    var hasWatchedChecklistLines: Bool {
        ChecklistLineMonitor.hasWatchedLines(in: inspectState.steps)
    }

    /// Starts the checklist poll, every 5 s like Preset 5's guide watch.
    func startChecklistMonitoring() {
        stopChecklistMonitoring()

        evaluateAllChecklistLines()

        let poll = Poll(every: 5.0)
        checklistMonitoringPoll = poll
        poll.start { self.evaluateAllChecklistLines() }
        writeLog("Preset6: Started checklist line monitoring timer", logLevel: .debug)
    }

    func stopChecklistMonitoring() {
        checklistMonitoringPoll?.cancel()
        checklistMonitoringPoll = nil
    }

    /// Evaluates every step, not only the current one, so lines ahead can already show as checked.
    func evaluateAllChecklistLines() {
        for step in inspectState.steps {
            evaluateChecklistLines(for: step)
        }
    }

    /// Evaluates one step's checklist via `ChecklistLineMonitor` and writes the result to the cache.
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
}
