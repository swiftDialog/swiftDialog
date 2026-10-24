//
//  InspectPresetName.swift
//  dialog
//

import Foundation

/// Every preset name an author may write, mapped to its preset. `InspectView` routing, window sizing
/// and validation all read this table, so they agree on what a name means.
enum InspectPresetName {
    static let spellings: [Int: [String]] = [
        1: ["preset1", "1", "deployment"],
        2: ["preset2", "2", "cards"],
        3: ["preset3", "3", "compact"],
        4: ["preset4", "4", "toast", "compact-installer"],
        5: ["preset5", "5", "portal", "self-service", "webview-portal"],
        6: ["preset6", "6", "guidance", "modern-sidebar"],
        7: ["preset7", "7", "guided-setup", "guided"]
    ]

    /// The preset a name opens, or nil for a name no preset answers to.
    static func number(_ name: String) -> Int? {
        let lowered = name.lowercased()
        return spellings.first { $0.value.contains(lowered) }?.key
    }

    /// The engine that draws the preset: Preset 7 runs on Preset 5's.
    static func engine(_ name: String) -> Int? {
        number(name).map { $0 == 7 ? 5 : $0 }
    }
}

extension InspectPresetName {
    /// Normalize a preset name to its engine form, e.g. "6" → "preset6"; every preset 7 spelling
    /// resolves to "preset5". Unknown names come back lower-cased.
    static func normalizePreset(_ preset: String) -> String {
        InspectPresetName.engine(preset).map { "preset\($0)" } ?? preset.lowercased()
    }
}
