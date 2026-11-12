//
//  Preset6+DynamicUpdates.swift
//  dialog
//
//  Preset 6 extension: merges plist-monitor state and IPC updates into guidance blocks.
//

import SwiftUI

extension Preset6View {
    // MARK: - Dynamic Content Updates

    /// Merges live plist/JSON monitor state (state, label, content, value) into a guidance block.
    /// Reading `stateForBlock` makes the view observe the monitor, so it re-renders on each poll.
    func applyPlistMonitorState(to block: InspectConfig.GuidanceContent, index: Int) -> InspectConfig.GuidanceContent {
        guard let ds = introStepMonitor.stateForBlock(index) else { return block }
        var b = block
        if let actual = ds.actual, !actual.isEmpty { b.value = actual }
        if let label = ds.label, !label.isEmpty { b.label = label }
        if let content = ds.content, !content.isEmpty { b.content = content }
        if let state = ds.state, !state.isEmpty { b.state = state }
        return b
    }

    /// Applies IPC property and content updates (trigger-file commands) to a guidance block.
    func applyDynamicUpdates(to block: InspectConfig.GuidanceContent, index: Int, itemId: String) -> InspectConfig.GuidanceContent {
        dynamicState.applied(to: block, blockIndex: index, stepId: itemId)
    }
}
