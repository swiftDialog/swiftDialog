//
//  ProvisioningVocabulary.swift
//  dialog
//
//  The words of the provisioning language, resolved once per step.
//

import SwiftUI

/// The words a row's state is said in. The flavour (checks vs packages) is the adapter's, never
/// the author's; the author may only re-word the roles through `merged(with:)`.
struct ProvisioningVocabulary {
    let done: String
    let active: String
    let queued: String
    let failed: String
    /// A row waiting on a failure above it; without its own word it would read as queued.
    let blocked: String
    /// A removed app, which arrives as `.pending`; without its own word it would read as queued.
    let removed: String

    static let checks = ProvisioningVocabulary(
        done: "Confirmed", active: "Checking", queued: "Queued",
        failed: "Not found", blocked: "Blocked", removed: "Removed")

    static let packages = ProvisioningVocabulary(
        done: "Installed", active: "Installing", queued: "Queued",
        failed: "Failed", blocked: "Blocked", removed: "Removed")

    /// Applies a step's `stateWords` over the adapter's words, role by role. Unknown keys and
    /// blank values are ignored, so a typo cannot blank a row.
    func merged(with words: [String: String]?) -> ProvisioningVocabulary {
        guard let words, !words.isEmpty else { return self }
        func pick(_ key: String, _ fallback: String) -> String {
            let value = words[key]?.trimmingCharacters(in: .whitespaces) ?? ""
            return value.isEmpty ? fallback : value
        }
        return ProvisioningVocabulary(
            done: pick("done", done), active: pick("active", active),
            queued: pick("queued", queued), failed: pick("failed", failed),
            blocked: pick("blocked", blocked), removed: pick("removed", removed))
    }
}

