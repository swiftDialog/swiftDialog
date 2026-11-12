//
//  InstallNarration.swift
//
//  Maps a narration line ("Installing X…" from `cadence:message:` or `progresstext:`) to a step
//  row. Narrations come from logs, so they use the fuzzy `FilenameMatching` ladder; `listitem:`
//  keeps its exact matcher in `ListItemCommand`.
//

import Foundation

enum InstallNarration {

    /// Matched case-insensitively at the start of the line only.
    private static let verbs = ["installing", "downloading", "removing", "configuring", "updating"]

    /// The subject of a narration line, or nil when the line does not narrate an install:
    /// "Installing Example App · 101 MB…" -> "Example App".
    static func subject(of text: String) -> String? {
        var rest = text.trimmingCharacters(in: .whitespaces)
        guard let verb = verbs.first(where: { rest.lowercased().hasPrefix($0 + " ") }) else { return nil }
        rest = String(rest.dropFirst(verb.count + 1))

        // " · 101 MB…" is the bridge's size suffix.
        if let separator = rest.range(of: " · ") {
            rest = String(rest[rest.startIndex..<separator.lowerBound])
        }
        rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " .…"))
        return rest.isEmpty ? nil : rest
    }

    /// The row a subject means, or nil. Rungs in order: display name, id, `logAliases`,
    /// then `FilenameMatching`.
    static func item(named subject: String,
                     in items: [any MonitoredItem]) -> (any MonitoredItem)? {
        if let hit = items.first(where: { $0.displayName.caseInsensitiveCompare(subject) == .orderedSame }) {
            return hit
        }
        if let hit = items.first(where: { $0.id.caseInsensitiveCompare(subject) == .orderedSame }) {
            return hit
        }
        // `logAliases` are the extra names a row answers to when a log names the artefact.
        if let hit = items.first(where: { item in
            (item.logAliases ?? []).contains { $0.caseInsensitiveCompare(subject) == .orderedSame }
        }) {
            return hit
        }
        return items.first {
            FilenameMatching.matches(itemId: $0.id, displayName: $0.displayName,
                                     filename: subject, brandFuzzy: true, log: nil)
        }
    }

    /// The row a narration line drives and its status, or nil. Always `.active`: completion is the
    /// path check's to declare.
    static func rowUpdate(for text: String,
                          items: [any MonitoredItem]) -> (id: String, status: StepStatus, message: String)? {
        guard let subject = subject(of: text),
              let item = item(named: subject, in: items) else { return nil }
        return (item.id, .active, text)
    }
}
