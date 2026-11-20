//
//  Preset5+DynamicUpdates.swift
//  dialog
//
//  Preset5View's dynamic content handlers (set / clear / update_guidance / batch) and the merge
//  of plist-monitor and IPC state into guidance blocks.
//

import SwiftUI

extension Preset5View {

    // MARK: - Dynamic Content Override Handlers

    /// `set:` — applied to the shared store by `DynamicSetCommand`, as on Preset 6.
    func handleSetCommand(targetType: String, value: String, extra: String?) {
        if let line = DynamicSetCommand.apply(type: targetType, value: value, extra: extra, steps: allSteps,
                                              currentStepId: currentStep?.id, state: dynamicState) {
            writeLog("Preset5: set:\(targetType) — \(line)", logLevel: .info)
        } else {
            writeLog("Preset5: Unknown set command type: \(targetType)", logLevel: .debug)
        }
    }

    /// `update_guidance:` — resolved by `GuidanceUpdateCommand`, applied by InspectDynamicState.
    func handleUpdateGuidanceCommand(_ command: String) {
        switch GuidanceUpdateCommand.resolve(command, steps: allSteps, currentStep: currentStep) {
        case .failure(.malformed):
            writeLog("Preset5: Invalid update_guidance format: \(command)", logLevel: .error)
        case .failure(.unknownBlock(let block)):
            writeLog("Preset5: Cannot resolve block '\(block)' in update_guidance", logLevel: .error)
        case .success(let update):
            dynamicState.apply(update)
            writeLog("Preset5: update_guidance '\(update.stepId)'[\(update.blockIndex)] \(update.operation)", logLevel: .info)
        }
    }

    /// Applies a batch update payload in one store update.
    /// Format: `{"step":"device","updates":{"2":{"value":"SERIAL"},"name_badge":{"value":"MyMac"}}}`
    func processBatchUpdate(_ jsonString: String) {
        let resolved: GuidanceBatchUpdate.Resolved
        switch GuidanceBatchUpdate.resolve(jsonString, in: allSteps) {
        case .failure(.invalidJSON):
            writeLog("Preset5: batch_update: invalid JSON — \(jsonString.prefix(200))", logLevel: .error)
            return
        case .failure(.unknownStep(let step)):
            writeLog("Preset5: batch_update: cannot resolve step '\(step)'", logLevel: .error)
            return
        case .success(let value):
            resolved = value
        }
        for blockKey in resolved.unresolvedKeys {
            writeLog("Preset5: batch_update: cannot resolve block '\(blockKey)' in step '\(resolved.stepId)'", logLevel: .error)
        }
        guard !resolved.blocks.isEmpty else { return }

        dynamicState.updateGuidancePropertiesBatch(stepId: resolved.stepId, blocks: resolved.blocks)
        writeLog("Preset5: batch_update: applied \(resolved.blocks.count) blocks to '\(resolved.stepId)' via dynamicState", logLevel: .info)
    }
    /// Merges plist-monitor state into a guidance block. Every field a `plistMonitor` can drive
    /// must land on the field the renderer reads, or the live update never shows.
    /// `actual` also sets `value`, which only form fields read.
    func applyDynamicState(to block: InspectConfig.GuidanceContent, dynamicState: DynamicContentState?) -> InspectConfig.GuidanceContent {
        guard let ds = dynamicState else { return block }
        var b = block
        if let actual = ds.actual, !actual.isEmpty {
            b.value = actual
            b.actual = actual
        }
        if let label = ds.label, !label.isEmpty { b.label = label }
        if let state = ds.state, !state.isEmpty { b.state = state }
        if let progress = ds.progress { b.progress = progress }
        if let passed = ds.passed { b.passed = passed }
        if let total = ds.total { b.total = total }
        if let currentPhase = ds.currentPhase { b.currentPhase = currentPhase }
        if let visible = ds.visible { b.visible = visible }
        if let content = ds.content, !content.isEmpty {
            // A compliance card's authored `content` is its category name; monitored content is its check list.
            if block.type == "compliance-card" {
                b.checkDetails = content
            } else {
                b.content = content
            }
        }
        return b
    }

    /// Merges IPC-driven state from InspectDynamicState into a guidance block.
    func applyIPCState(to block: InspectConfig.GuidanceContent, blockIndex: Int, stepId: String) -> InspectConfig.GuidanceContent {
        dynamicState.applied(to: block, blockIndex: blockIndex, stepId: stepId)
    }
}
