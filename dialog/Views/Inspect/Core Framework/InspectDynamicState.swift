//
//  InspectDynamicState.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 10/11/2025
//
//  Centralized state management for Inspect dynamic UI components.
//  Uses @Observable for per-property tracking — SwiftUI only re-renders
//  views that read the specific property that changed.
//

import SwiftUI
import Observation

/// Observable state manager for Inspect preset dynamic content updates
/// Used across multiple presets (Preset5, Preset6, etc.)
@MainActor
@Observable
class InspectDynamicState {

    // MARK: - Tracked State (Per-Property SwiftUI Updates)

    /// Custom processing messages per step (stepId -> message)
    var dynamicMessages: [String: String] = [:]

    /// Progress percentages per step (stepId -> 0-100)
    var progressPercentages: [String: Int] = [:]

    /// Custom data display per step (stepId -> [(key, value, color)])
    var customDataDisplay: [String: [(String, String, String?)]] = [:]

    /// Dynamic guidance content updates (stepId -> blockIndex -> content)
    var dynamicGuidanceContent: [String: [Int: String]] = [:]

    /// Dynamic guidance property updates (stepId -> blockIndex -> [property -> value])
    /// This is the PRIMARY state for status badges, comparison tables, phase trackers
    var dynamicGuidanceProperties: [String: [Int: [String: String]]] = [:]

    /// Status icons per list item (index -> "iconName-color")
    var itemStatusIcons: [Int: String] = [:]

    /// Continue button visibility per step (stepId -> showButton)
    var showContinueButton: [String: Bool] = [:]

    // MARK: - Update Methods (Called by External Systems)

    /// Update a processing message for a step
    func updateMessage(stepId: String, message: String) {
        dynamicMessages[stepId] = message
        writeLog("InspectDynamicState: Updated message for '\(stepId)'", logLevel: .info)
    }

    /// Update progress percentage for a step
    func updateProgress(stepId: String, percentage: Int) {
        progressPercentages[stepId] = min(100, max(0, percentage))
        writeLog("InspectDynamicState: Updated progress for '\(stepId)': \(percentage)%", logLevel: .info)
    }

    /// Add or update custom data display entry
    func updateDisplayData(stepId: String, key: String, value: String, color: String? = nil) {
        var stepData = customDataDisplay[stepId] ?? []

        // Update existing key or append new one
        if let existingIndex = stepData.firstIndex(where: { $0.0 == key }) {
            stepData[existingIndex] = (key, value, color)
        } else {
            stepData.append((key, value, color))
        }

        customDataDisplay[stepId] = stepData
        writeLog("InspectDynamicState: Updated display data '\(key)' = '\(value)' for '\(stepId)'", logLevel: .info)
    }

    /// Update guidance content text for a specific block
    func updateGuidanceContent(stepId: String, blockIndex: Int, content: String) {
        var stepDict = dynamicGuidanceContent[stepId] ?? [:]
        stepDict[blockIndex] = content
        dynamicGuidanceContent[stepId] = stepDict

        writeLog("InspectDynamicState: Updated guidance content for '\(stepId)'[\(blockIndex)]", logLevel: .info)
    }

    /// Update a specific property on a guidance component
    /// This is the CORE method for status badge, comparison table, phase tracker updates
    func updateGuidanceProperty(stepId: String, blockIndex: Int, property: String, value: String) {
        // Get or create nested dictionaries
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]
        var blockDict = stepDict[blockIndex] ?? [:]

        // Update the property
        blockDict[property] = value
        stepDict[blockIndex] = blockDict

        // Reassign to trigger observation
        dynamicGuidanceProperties[stepId] = stepDict

        writeLog("InspectDynamicState: updateGuidanceProperty('\(stepId)'[\(blockIndex)].\(property) = '\(value)')", logLevel: .info)
    }

    /// Batch update multiple properties on a guidance component (optimization)
    func updateGuidanceProperties(stepId: String, blockIndex: Int, properties: [String: String]) {
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]
        var blockDict = stepDict[blockIndex] ?? [:]

        // Merge all properties
        blockDict.merge(properties) { _, new in new }
        stepDict[blockIndex] = blockDict

        // Single observation update
        dynamicGuidanceProperties[stepId] = stepDict

        writeLog("InspectDynamicState: Batch updated \(properties.count) properties for '\(stepId)'[\(blockIndex)]", logLevel: .info)
    }

    /// Batch update multiple blocks in a single observation fire.
    /// All values appear in one SwiftUI render frame — no per-property flicker.
    func updateGuidancePropertiesBatch(stepId: String, blocks: [Int: [String: String]]) {
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]

        for (blockIndex, properties) in blocks {
            var blockDict = stepDict[blockIndex] ?? [:]
            blockDict.merge(properties) { _, new in new }
            stepDict[blockIndex] = blockDict
        }

        // Single observation fire for all blocks
        dynamicGuidanceProperties[stepId] = stepDict

        let totalProps = blocks.values.reduce(0) { $0 + $1.count }
        writeLog("InspectDynamicState: Batch updated \(blocks.count) blocks (\(totalProps) properties) for '\(stepId)'", logLevel: .info)
    }

    /// Update list item status icon
    func updateItemStatusIcon(index: Int, icon: String?) {
        if let icon = icon, !icon.isEmpty {
            itemStatusIcons[index] = icon
        } else {
            itemStatusIcons.removeValue(forKey: index)
        }
        writeLog("InspectDynamicState: Updated status icon for item \(index)", logLevel: .info)
    }

    /// Show/hide continue button for a step
    func setContinueButtonVisible(stepId: String, visible: Bool) {
        showContinueButton[stepId] = visible
    }

    /// Clear all dynamic state for a specific step (used on reset)
    func clearStepState(stepId: String) {
        dynamicMessages.removeValue(forKey: stepId)
        progressPercentages.removeValue(forKey: stepId)
        customDataDisplay.removeValue(forKey: stepId)
        dynamicGuidanceContent.removeValue(forKey: stepId)
        dynamicGuidanceProperties.removeValue(forKey: stepId)
        showContinueButton.removeValue(forKey: stepId)

        writeLog("InspectDynamicState: Cleared all state for '\(stepId)'", logLevel: .info)
    }

    /// Clear all dynamic state (used on full reset)
    func clearAllState() {
        dynamicMessages.removeAll()
        progressPercentages.removeAll()
        customDataDisplay.removeAll()
        dynamicGuidanceContent.removeAll()
        dynamicGuidanceProperties.removeAll()
        itemStatusIcons.removeAll()
        showContinueButton.removeAll()

        writeLog("InspectDynamicState: Cleared all dynamic state", logLevel: .info)
    }

    // MARK: - Query Methods (Read-Only Access)

    /// Get current message for a step
    func getMessage(for stepId: String) -> String? {
        dynamicMessages[stepId]
    }

    /// Get current progress for a step
    func getProgress(for stepId: String) -> Int? {
        progressPercentages[stepId]
    }

    /// Get display data for a step
    func getDisplayData(for stepId: String) -> [(String, String, String?)] {
        customDataDisplay[stepId] ?? []
    }

    /// Get updated guidance properties for a block
    func getGuidanceProperties(stepId: String, blockIndex: Int) -> [String: String]? {
        dynamicGuidanceProperties[stepId]?[blockIndex]
    }
}
