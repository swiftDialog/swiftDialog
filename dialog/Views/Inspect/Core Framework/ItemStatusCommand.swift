//
//  ItemStatusCommand.swift
//  dialog
//
//  `item:<id>:<status>[:message]` on every inspect surface: the words resolve once
//  (`StepStatus(itemCommand:)`) and the state change is one rule (`ItemLifecycle`).
//

import SwiftUI

extension StepStatus {
    /// The status words an item command accepts: every lenient spelling (`StepStatus(lenient:)`)
    /// plus `checking` and `running`, which are item-command words only.
    init?(itemCommand word: String) {
        if let status = StepStatus(lenient: word) {
            self = status
            return
        }
        switch word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "checking", "running": self = .active
        default: return nil
        }
    }
}

/// What a status does to an item's completed / failed / active sets. Pure; the presets own the
/// stores. Each status clears the other two (re-driving an item is a retry); `skipped` changes
/// nothing.
struct ItemLifecycle: Equatable {
    var completed: Set<String>
    var failed: Set<String>
    var active: Set<String>

    mutating func apply(_ id: String, _ status: StepStatus) {
        switch status {
        case .completed:
            completed.insert(id); failed.remove(id); active.remove(id)
        case .failed:
            failed.insert(id); completed.remove(id); active.remove(id)
        case .active:
            active.insert(id); completed.remove(id); failed.remove(id)
        case .pending:
            completed.remove(id); failed.remove(id); active.remove(id)
        case .skipped:
            break
        }
    }
}

extension InspectState {
    /// One item's status change through `ItemLifecycle`; progress is pinned to 100 on completion
    /// and cleared on pending. Unknown ids change nothing unless `knownItemsOnly` is false.
    func applyItemStatus(_ itemId: String, _ status: StepStatus, knownItemsOnly: Bool = true) {
        if knownItemsOnly { guard items.contains(where: { $0.id == itemId }) else { return } }
        guard status != .skipped else { return }
        var lifecycle = ItemLifecycle(completed: completedItems, failed: failedItems, active: downloadingItems)
        lifecycle.apply(itemId, status)
        withAnimation(.easeInOut(duration: 0.2)) {
            if completedItems != lifecycle.completed { completedItems = lifecycle.completed }
            if failedItems != lifecycle.failed { failedItems = lifecycle.failed }
            if downloadingItems != lifecycle.active { downloadingItems = lifecycle.active }
            switch status {
            case .completed: itemProgress[itemId] = 100
            case .pending: itemProgress.removeValue(forKey: itemId)
            default: break
            }
        }
    }

    /// The config's rows, without the ones added while running — what completion counts.
    var trackedItems: [InspectConfig.ItemConfig] { items.filter { !addedItemIDs.contains($0.id) } }
    var trackedCompletedCount: Int { completedItems.subtracting(addedItemIDs).intersection(items.map(\.id)).count }
    var trackedFailedCount: Int { failedItems.subtracting(addedItemIDs).intersection(items.map(\.id)).count }

    /// `listitem: add`: a row the config does not list. Rows added to a list deployed empty count;
    /// rows added beside configured rows are drawn but never counted (`addedItemIDs`).
    func addItem(id: String, title: String, icon: String?) {
        guard !items.contains(where: { $0.id == id }) else { return }
        // Judged against the config, not the live list, so a second added row counts like the first.
        let deployedEmpty = config.map { $0.items.isEmpty } ?? items.isEmpty
        withAnimation(.easeInOut(duration: 0.2)) {
            // Highest guiIndex so a sorted list does not put the new row first.
            items.append(InspectConfig.ItemConfig(id: id, displayName: title, icon: icon,
                                                  guiIndex: (items.map(\.guiIndex).max() ?? 0) + 1))
            if !deployedEmpty { addedItemIDs.insert(id) }
        }
    }

    /// `listitem: delete`: removes the row and everything recorded about it. Unknown ids are no-ops.
    func removeItem(_ id: String) {
        guard items.contains(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            items.removeAll { $0.id == id }
            addedItemIDs.remove(id)
            completedItems.remove(id)
            failedItems.remove(id)
            downloadingItems.remove(id)
            itemProgress.removeValue(forKey: id)
            itemStatusText.removeValue(forKey: id)
        }
    }

    /// `listitem: order`: the named rows first, in the given order, then every row renumbered by
    /// position so array order and guiIndex sorting agree.
    func reorderItems(_ ids: [String]) {
        guard var moved = ListItemCommand.reordered(items, by: ids, id: \.id) else { return }
        for index in moved.indices { moved[index].guiIndex = index }
        withAnimation(.easeInOut(duration: 0.2)) { items = moved }
    }

    /// `item:<id>:<status>[:message]`: the message replaces the row's result line (none clears
    /// it), then the status word is applied. An unknown word changes no state.
    func applyItemStatusCommand(_ itemId: String, word: String, message: String?) {
        guard items.contains(where: { $0.id == itemId }) else { return }
        if let message, !message.trimmingCharacters(in: .whitespaces).isEmpty {
            itemStatusText[itemId] = message
        } else {
            itemStatusText.removeValue(forKey: itemId)
        }
        guard let status = StepStatus(itemCommand: word) else { return }
        applyItemStatus(itemId, status)
    }
}

/// `close` / `quit:` on an item-set preset: writes the result file with exit 5, then exits cleanly.
@MainActor
func itemPresetSupervisedClose(state: InspectState, triggerFilePath: String, label: String) -> Never {
    writeItemPresetResultFile(state: state, exitCode: Int(appDefaults.exit5.code))
    presetCleanExit(state: state, triggerFilePath: triggerFilePath, label: label,
                    message: "supervised close", exitCode: appDefaults.exit5.code)
}
