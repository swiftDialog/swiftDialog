//
//  CommandRouter+ItemBase.swift
//  dialog
//
//  Base item-command wiring for the item-set presets (1–4): maps the command protocol onto
//  InspectState's item collections so every item-set preset shares one IPC drive.
//

import SwiftUI

extension CommandRouter {
    /// Wire the item-set base handlers and start watching the trigger file.
    ///
    ///   progress:<id>:<pct>     → itemProgress (high-water) + downloading while incomplete
    ///   complete:/success:<id>  → completed (progress pinned to 100)
    ///   failure:<id>            → failed
    ///   item:<id>:<status>      → downloading | completed | failed | pending
    ///   reset                   → clear all item state
    ///
    /// `overrides` runs after the base wiring and before monitoring starts, so a line already
    /// waiting in the trigger file meets the final handlers.
    @MainActor
    func wireItemBase(state: InspectState, presetLabel: String, triggerFilePath: String,
                      overrides: ((CommandRouter) -> Void)? = nil) {
        self.presetLabel = presetLabel
        acknowledgmentLogPath = "/var/tmp/dialog-ack.log"
        itemCount = state.items.count

        func markCompleted(_ itemId: String) { state.applyItemStatus(itemId, .completed) }

        onProgress = { stepId, pct in
            guard state.items.contains(where: { $0.id == stepId }) else { return }
            state.itemProgress[stepId] = max(state.itemProgress[stepId] ?? 0, pct)
            if !state.completedItems.contains(stepId) {
                state.downloadingItems.insert(stepId)
            }
        }
        onComplete = { markCompleted($0) }
        onSuccess = { stepId, _ in markCompleted(stepId) }
        onFailure = { stepId, _ in state.applyItemStatus(stepId, .failed) }
        onItemStatus = { itemId, status, message in
            state.applyItemStatusCommand(itemId, word: status, message: message)
        }
        onItemIcon = { itemId, icon in state.itemIconOverrides[itemId] = icon.isEmpty ? nil : icon }
        // Classic's `listitem:`; rows added at runtime show but never count (`addedItemIDs`).
        onListItem = { remainder in
            switch ListItemCommand.resolve(remainder, items: state.items) {
            case .add(let itemId, let title, let icon, let status, let message, _):
                state.addItem(id: itemId, title: title, icon: icon)
                if let message { state.itemStatusText[itemId] = message }
                if let status { state.applyItemStatus(itemId, status) }
                writeLog("\(presetLabel): listitem added '\(itemId)' (\(title))", logLevel: .info)
            case .order(let ids):
                state.reorderItems(ids)
            case .delete(let itemId):
                state.removeItem(itemId)
                writeLog("\(presetLabel): listitem deleted '\(itemId)'", logLevel: .info)
            case .update(let itemId, let status, let message):
                if let message { state.itemStatusText[itemId] = message }
                if let status { state.applyItemStatus(itemId, status) }
            case .unresolved(let target):
                writeLog("\(presetLabel): listitem '\(target)' names no item — ignored", logLevel: .debug)
            case .unknownStatus(let word):
                writeLog("\(presetLabel): unknown listitem status '\(word)' — ignored", logLevel: .debug)
            case .empty:
                break
            }
        }
        // `close` / `quit:`: a supervised close, as on every preset.
        onClose = { itemPresetSupervisedClose(state: state, triggerFilePath: triggerFilePath, label: presetLabel) }
        onReset = {
            withAnimation(.easeInOut(duration: 0.2)) {
                state.completedItems.removeAll()
                state.failedItems.removeAll()
                state.downloadingItems.removeAll()
                state.itemProgress.removeAll()
                state.itemStatusText.removeAll()
            }
        }

        // `next` / `prev` move the intro → main → summary flow; no-ops past either end.
        onNext = { state.phaseStepRequest += 1 }
        onPrev = { state.phaseStepRequest -= 1 }

        overrides?(self)

        if !FileManager.default.fileExists(atPath: triggerFilePath) {
            FileManager.default.createFile(atPath: triggerFilePath, contents: nil, attributes: nil)
        }
        startMonitoring(triggerFilePath: triggerFilePath)
    }
}
