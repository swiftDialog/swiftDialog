//
//  StepCounterLabel.swift
//  dialog
//

import SwiftUI

/// The step counter's words: sidecar key, English default and placeholder substitution. Every
/// "Step n of N" in inspect resolves through here so one translation covers all counters.
/// Both `{n}` and `{current}` are accepted for the position.
enum StepCounterLabel {

    /// Sidecar lookup names, in preference order; `stepProgress` is the older documented key.
    static let sidecarKeys = ["_ui.stepCounterFormat", "stepProgress"]

    /// First key, for callers that resolve one at a time.
    static let sidecarKey = sidecarKeys[0]

    /// Resolve the template through the caller's own lookup; the English default when none is authored.
    static func template(_ lookup: (String) -> String?) -> String {
        for key in sidecarKeys {
            if let hit = lookup(key), !hit.isEmpty { return hit }
        }
        return fallback
    }

    /// English default; a translation may reorder the braces.
    static let fallback = "Step {n} of {total}"

    /// Resolve and substitute through the environment localizer. A caller whose own chain is richer
    /// (sidecar plus config labels) passes its resolved `template` instead.
    static func text(current: Int, total: Int,
                     template injected: String? = nil,
                     localizer: InspectLocalizer) -> String {
        let resolved = injected ?? template { key in
            // The localizer returns its fallback on a miss, so empty is the only "not authored" signal.
            let hit = localizer(key, "")
            return hit.isEmpty ? nil : hit
        }
        return format(resolved, current: current, total: total)
    }

    /// Substitute a resolved template; unknown braces stay visible so a typo shows.
    static func format(_ template: String, current: Int, total: Int) -> String {
        template
            .replacingOccurrences(of: "{n}", with: "\(current)")
            .replacingOccurrences(of: "{current}", with: "\(current)")
            .replacingOccurrences(of: "{total}", with: "\(total)")
    }
}
