//
//  ListItemCommand.swift
//  dialog
//
//  The list-item command vocabulary shared by every preset that takes item commands.
//

import SwiftUI

// MARK: - listitem:

/// Parses and resolves a classic swiftDialog `listitem:` line into an `Outcome`, without rendering:
///
///     listitem: title: Example App, status: wait, statustext: Installing
///
/// `Preset5View.handleListItemCommand` applies the result.
enum ListItemCommand {

    /// What one line asks for. Failures carry their text so logging stays with the caller.
    enum Outcome: Equatable {
        /// Both payloads are optional independently: a line may push only a status, only a
        /// `statustext:`, or both.
        case update(itemId: String, status: StepStatus?, message: String?)
        /// A `title:`/`index:` naming no row on this step; never guessed.
        case unresolved(target: String)
        /// A status word outside the vocabulary. Nothing is written, including its `statustext:`.
        case unknownStatus(word: String)
        /// `listitem: add, title: …` for a new row. The id is `id:` if given, else `app-<title, a–z0–9>`.
        case add(itemId: String, title: String, icon: String?, status: StepStatus?, message: String?, step: String? = nil)
        /// `listitem: order, ids: a|b|c`: these rows in this order; rows not named stay where they are.
        case order(ids: [String])
        /// `listitem: delete, id: …` (or `remove`), addressed by `id:` or `title:`.
        case delete(itemId: String)
        /// Nothing addressed, or nothing to apply.
        case empty
    }

    /// Maps classic status words (`AppDefaults.ckListStatusOptions`): `success` completes, `wait`/`progress`
    /// are in flight, `fail`/`error` fail, `pending` is none. `progress` is mapped here because
    /// `StepStatus(lenient:)` deliberately does not accept it.
    static func lifecycle(_ word: String) -> StepStatus? {
        let normalised = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalised == "progress" ? .active : StepStatus(lenient: normalised)
    }

    /// `rows` with the ones `order` names moved into the slots those rows already hold, in that
    /// order; every other row stays exactly where it is. nil when nothing would move.
    static func reordered<T>(_ rows: [T], by order: [String], id: (T) -> String) -> [T]? {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let slots = rows.indices.filter { rank[id(rows[$0])] != nil }
        let moving = slots.map { rows[$0] }.sorted { rank[id($0)]! < rank[id($1)]! }
        var out = rows
        for (slot, row) in zip(slots, moving) { out[slot] = row }
        return out.map(id) == rows.map(id) ? nil : out
    }

    /// Where `listitem: add` puts a row and whether it counts. Placement: `named` step, else the
    /// installation step holding rows of the same kind, else the last installation step, else the current
    /// step. Counts when that step was deployed empty. nil when nothing fits or the id already exists.
    static func placement(of id: String, in steps: [InspectConfig.IntroStep], named: String?, current: String?,
                          deployed: [InspectConfig.IntroStep]) -> (index: Int, counted: Bool)? {
        guard !steps.contains(where: { ($0.items ?? []).contains { $0.id == id } }) else { return nil }
        let setupKind = { (rowId: String) in rowId == "profiles" || rowId == "bootstrap" || rowId.hasPrefix("profile-") }
        let installs = steps.indices.filter { steps[$0].resolvedStepType == "installation" }
        guard let at = named.flatMap({ s in steps.firstIndex { $0.id == s } })
                ?? installs.first(where: { (steps[$0].items ?? []).contains { setupKind($0.id) == setupKind(id) } })
                ?? installs.last
                ?? current.flatMap({ cur in steps.firstIndex { $0.id == cur } }) else { return nil }
        let asDeployed = deployed.first { $0.id == steps[at].id }?.items ?? []
        return (at, asDeployed.isEmpty)
    }

    /// The new index of the item at `current` after reordering, so a by-position view keeps the same item.
    /// nil when it is gone or `current` was out of range.
    static func index(following current: Int, from old: [String], to new: [String]) -> Int? {
        guard old.indices.contains(current) else { return nil }
        return new.firstIndex(of: old[current])
    }

    /// `reordered` over every step's rows; nil when no step changes.
    static func reorderingRows(of steps: [InspectConfig.IntroStep], by order: [String]) -> [InspectConfig.IntroStep]? {
        var out = steps, changed = false
        for index in out.indices {
            guard let moved = reordered(out[index].items ?? [], by: order, id: \.id) else { continue }
            out[index].items = moved
            changed = true
        }
        return changed ? out : nil
    }

    /// - Parameters:
    ///   - remainder: everything after `listitem:`, e.g. `title: Example App, status: wait`.
    ///   - items: the rows of the step currently on screen.
    static func resolve(_ remainder: String, items: [any MonitoredItem]) -> Outcome {
        resolve(remainder, rows: items.map { ($0.id, $0.displayName) })
    }

    /// The same decision over `(id, name)` rows; Preset 6's rows are its steps.
    static func resolve(_ remainder: String, rows: [(id: String, name: String)]) -> Outcome {
        var title: String?
        var index: Int?
        var statusWord: String?
        var statusText: String?
        var adding = false
        var ordering = false
        var deleting = false
        var orderIds: [String] = []
        var addId: String?
        var icon: String?
        var step: String?

        // Comma-separated `key: value` pairs, split on the first colon so values keep their own colons.
        for field in remainder.components(separatedBy: ",") {
            let parts = field.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 1, parts[0].lowercased() == "add" { adding = true; continue }
            if parts.count == 1, parts[0].lowercased() == "order" { ordering = true; continue }
            if parts.count == 1, ["delete", "remove"].contains(parts[0].lowercased()) { deleting = true; continue }
            guard parts.count == 2, !parts[1].isEmpty else { continue }
            switch parts[0].lowercased() {
            case "title": title = parts[1]
            case "id": addId = parts[1]
            case "icon": icon = parts[1]
            case "step": step = parts[1]
            case "ids": orderIds = parts[1].split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            case "index": index = Int(parts[1])
            case "status": statusWord = parts[1]
            case "statustext": statusText = parts[1]
            default: continue
            }
        }

        // Exact, case-insensitive match on `displayName`, then `id`. Not `FilenameMatching.directMatch`,
        // which is a substring test and would let "Chrome" match "Chrome Beta".
        if ordering { return orderIds.isEmpty ? .empty : .order(ids: orderIds) }
        if deleting, let addId { return .delete(itemId: addId) }

        let resolved: (id: String, name: String)?
        let addressed: String
        if let title {
            addressed = title
            resolved = rows.first { $0.name.caseInsensitiveCompare(title) == .orderedSame }
                ?? rows.first { $0.id.caseInsensitiveCompare(title) == .orderedSame }
        } else if let index {
            addressed = "index \(index)"
            resolved = rows.indices.contains(index) ? rows[index] : nil
        } else {
            return .empty
        }
        var status: StepStatus?
        if let statusWord {
            guard let mapped = lifecycle(statusWord) else { return .unknownStatus(word: statusWord) }
            status = mapped
        }
        // Adding an existing row is an update, so repeats are harmless.
        if adding, resolved == nil, let title {
            let id = addId ?? "app-" + FleetSetup.slug(title)
            if let existing = rows.first(where: { $0.id == id }) {
                guard status != nil || statusText != nil else { return .empty }
                return .update(itemId: existing.id, status: status, message: statusText)
            }
            return .add(itemId: id, title: title, icon: icon, status: status, message: statusText, step: step)
        }
        guard let item = resolved else { return .unresolved(target: addressed) }
        if deleting { return .delete(itemId: item.id) }
        guard status != nil || statusText != nil else { return .empty }
        return .update(itemId: item.id, status: status, message: statusText)
    }
}
