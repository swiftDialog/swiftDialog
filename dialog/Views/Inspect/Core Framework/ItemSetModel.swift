//
//  ItemSetModel.swift
//  dialog
//
//  What a live item set is, apart from how any screen draws it: sorted rows with status, status
//  word and warning resolved once, so every item screen shows the same truth. Carries no colour;
//  callers resolve `itemStatusColor` with their own palette.
//

import SwiftUI

/// A live item set, sorted, with each row's lifecycle state already resolved.
@MainActor
struct ItemSetModel {

    /// Not `Identifiable` on purpose: `id` can repeat (an item may sit in two membership sets),
    /// and a `ForEach(model.rows)` would misrender silently. Callers key explicitly or by position.
    struct Row {
        let item: InspectConfig.ItemConfig
        /// The lifecycle state, in the shared vocabulary (`StepStatus`).
        let status: StepStatus
        /// The word a screen shows for this row, localized and validation-aware.
        let statusText: String
        /// Completed, but its validation did not pass: reads as a warning, not a failure.
        let hasWarning: Bool

        var id: String { item.id }
    }

    /// Already sorted; callers must not re-sort, or two screens showing one run disagree.
    let rows: [Row]

    static func build(from state: InspectState) -> ItemSetModel {
        let sorted = PresetCommonViews.getSortedItemsByStatus(
            state, order: .init(itemSortOrder: state.config?.itemSortOrder))
        return ItemSetModel(rows: sorted.map { row(for: $0, state: state) })
    }

    /// One item's row: status, word and warning, the same on every preset that shows items.
    static func row(for item: InspectConfig.ItemConfig, state: InspectState) -> Row {
        let status = PresetCommonViews.resolveInstallStatus(for: item, state: state)
        return Row(item: item,
                   status: status,
                   statusText: statusText(for: item, resolvedStatus: status, state: state),
                   hasWarning: PresetCommonViews.hasValidationWarning(for: item, state: state))
    }

    /// The row's status word for the status already resolved for its glyph. Takes the resolved
    /// status rather than re-walking the sets: an item can sit in two sets, and the word and
    /// glyph must agree.
    private static func statusText(for item: InspectConfig.ItemConfig, resolvedStatus: StepStatus, state: InspectState) -> String {
        // A script's own text for the row wins in every state.
        if let live = state.itemStatusText[item.id] { return live }
        if resolvedStatus == .completed, PresetCommonViews.hasValidationWarning(for: item, state: state) {
            return state.config?.uiLabels?.failedStatus ?? "Failed"
        }
        switch resolvedStatus {
        case .failed:
            // Log monitor > item `failureMessage` > global labels > default.
            if let logStatus = state.logMonitorStatuses[item.id] {
                return logStatus
            } else if let itemMessage = item.failureMessage, !itemMessage.isEmpty {
                return itemMessage
            } else if let globalStatus = state.config?.uiLabels?.failedStatus {
                return globalStatus
            } else {
                return "Failed"
            }
        case .completed:
            // Only a completion message from the log monitor counts; a stale "Installing…" must not.
            if let logStatus = state.logMonitorStatuses[item.id],
               logStatus.hasPrefix("Completed") || logStatus.hasPrefix("Installed") {
                return logStatus
            } else if let customStatus = item.completedStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.completedStatus {
                return globalStatus
            } else {
                return "Completed"
            }
        case .active:
            if let logStatus = state.logMonitorStatuses[item.id] {
                return logStatus
            } else if let customStatus = item.downloadingStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.downloadingStatus {
                return globalStatus
            } else {
                return "Installing..."
            }
        case .pending, .skipped:
            // The removal notice beats the authored pending word: "Waiting" on an app the user
            // just deleted is wrong. The log monitor still wins, as the installer's own words.
            if let logStatus = state.logMonitorStatuses[item.id] {
                return logStatus
            } else if let removedAt = state.removedItems[item.id],
                      !AppInspector.removalNoticeExpired(removedAt: removedAt) {
                return state.config?.uiLabels?.removedStatus ?? "Removed"
            } else if let customStatus = item.pendingStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.pendingStatus {
                return globalStatus
            } else {
                return "Waiting"
            }
        }
    }

    /// An item's status word outside a built model: the same word a row gets.
    static func displayStatusText(for item: InspectConfig.ItemConfig, state: InspectState) -> String {
        statusText(for: item, resolvedStatus: PresetCommonViews.resolveInstallStatus(for: item, state: state), state: state)
    }

    /// The status → colour mapping. The palette is a parameter; the caller reads the environment.
    static func itemStatusColor(_ status: StepStatus, hasWarning: Bool, palette: ResolvedPalette) -> Color {
        switch status {
        case .failed:    return palette.error
        case .completed: return hasWarning ? palette.warning : palette.success
        case .active:    return palette.info
        default:         return .secondary
        }
    }
}
