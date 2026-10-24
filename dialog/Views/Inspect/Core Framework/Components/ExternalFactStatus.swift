//
//  ExternalFactStatus.swift
//  Dialog
//
//  Classifies authored status words about the machine (`compliant`, `enrolled`) once, so the
//  badge's hue and glyph cannot disagree. Used by `StatusBadgeView` and the comparison fold.
//

import SwiftUI

/// What the machine is, as opposed to `StepStatus`, which is where a step is in its lifecycle.
/// The two vocabularies never merge. `symbol` and `color(palette:)` are pure mappings off the
/// classification.
enum ExternalFactStatus {
    case success
    /// Work is happening right now.
    case progress
    /// Attention warranted, not a failure.
    case warning
    /// Informational; no severity, so no hue.
    case info
    case fail
    /// Queued or being checked.
    case pending
    /// Indeterminate answer.
    case unknown
    /// A word this vocabulary does not model; renders as plain text.
    case neutral

    // MARK: - The words
    //
    // Match order is the contract: success is tested before fail, so a string carrying both reads
    // as success.

    private static let successWords = [
        "enabled", "active", "pass", "success", "valid", "enrolled", "connected",
        "on", "true", "yes", "installed", "present", "compliant", "detected", "ok"
    ]

    /// Checked before the failure list, which matches on `contains`.
    private static let progressWords = ["downloading", "processing", "running"]

    /// `disabled`, `off`, `false` and `no` are legitimate states, not failures, and fall through
    /// to `.neutral`. `"no"` would also match inside `"unknown"` under `contains`.
    private static let failWords = [
        "fail", "failure", "invalid", "unenrolled", "disconnected",
        "not found", "missing", "error", "non-compliant", "not detected"
    ]

    private static let pendingWords = ["pending", "in-progress", "waiting", "checking"]

    private static let unknownWords = ["unknown", "partial"]

    /// Most words match on prefix (`"enabled (managed)"`); failure words match on `contains`
    /// (`"disk error"`).
    static func classify(_ authored: String) -> ExternalFactStatus {
        let state = authored.lowercased()

        if successWords.contains(where: { state.hasPrefix($0) }) { return .success }
        if progressWords.contains(where: { state.hasPrefix($0) }) { return .progress }
        // Exact matches: "warnings" is not a warning.
        if state == "warning" { return .warning }
        if state == "info" { return .info }
        if failWords.contains(where: { state.contains($0) }) { return .fail }
        if pendingWords.contains(where: { state.hasPrefix($0) }) { return .pending }
        if unknownWords.contains(where: { state.hasPrefix($0) }) { return .unknown }

        return .neutral
    }

    // MARK: - The verdict, for the comparison fold

    /// Pass/fail reading: `.success` → true, `.fail` → false, anything else nil so the table
    /// derives its verdict from `required == found`. `InspectConfig.verdictIsPass` is this
    /// projection and keeps no word list of its own.
    var verdict: Bool? {
        switch self {
        case .success: return true
        case .fail: return false
        default: return nil
        }
    }

    // MARK: - What it renders as

    /// The SF Symbol for this state.
    var symbol: String {
        switch self {
        case .success:  return "checkmark.circle.fill"
        case .progress: return "arrow.down.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        case .fail:     return "xmark.circle.fill"
        case .pending:  return "clock.fill"
        case .unknown:  return "questionmark.circle.fill"
        case .neutral:  return "circle.fill"
        }
    }

    /// The hue, from the palette. `pending` and `unknown` share `warning`; `info` and `neutral`
    /// carry no severity and stay `.secondary`.
    func color(palette: ResolvedPalette) -> Color {
        switch self {
        case .success:  return palette.success
        case .progress: return palette.info
        case .warning:  return palette.warning
        case .fail:     return palette.error
        case .pending:  return palette.warning
        case .unknown:  return palette.warning
        case .info:     return .secondary
        case .neutral:  return .secondary
        }
    }
}
