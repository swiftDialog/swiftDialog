//
//  ChecklistState.swift
//  dialog
//
//  The guide checklist's per-line state, derived from what the watches said; there is no authored
//  state key. Active is the first unsatisfied watched line; everything after it is pending.
//

import Foundation

enum ChecklistLineState: Equatable {
    /// No watch authored: the line renders its authored `marker` and claims nothing about
    /// verification. A check is earned by a passing watch, never granted by the absence of one.
    case unwatched
    case satisfied
    case active
    case pending
}

enum ChecklistState {

    /// One result per line, index-aligned with `lines`. A line with no `paths` returns `true`
    /// here but `resolve` short-circuits it to `.unwatched` first.
    static func evaluate(lines: [InspectConfig.GuidanceContent.ChecklistLine],
                         using evaluator: (_ paths: [String], _ plistKey: String?) -> Bool) -> [Bool] {
        lines.map { line in
            guard let paths = line.paths, !paths.isEmpty else { return true }
            return evaluator(paths, line.plistKey)
        }
    }

    /// Watched lines that pass are satisfied; the first unsatisfied watched line is active, later
    /// ones pending. Unwatched lines take no part in choosing the active line.
    static func resolve(lines: [InspectConfig.GuidanceContent.ChecklistLine],
                        satisfied: [Bool]) -> [ChecklistLineState] {
        var activeTaken = false
        return lines.indices.map { i in
            guard let paths = lines[i].paths, !paths.isEmpty else { return .unwatched }
            let ok = i < satisfied.count ? satisfied[i] : false
            if ok { return .satisfied }
            if activeTaken { return .pending }
            activeTaken = true
            return .active
        }
    }
}
