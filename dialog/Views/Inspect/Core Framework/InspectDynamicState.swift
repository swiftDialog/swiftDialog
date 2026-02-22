//
//  InspectDynamicState.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 10/11/2025
//  Try a MVVM appoach here as a generic state manager
//
//  Centralized state management for Inspect dynamic UI components.
//  Eliminates nested dictionary @State issues with ObservableObject pattern.
//

import SwiftUI
import Combine

/// Observable state manager for Inspect preset dynamic content updates
/// Replaces problematic @State nested dictionaries with proper @Published properties
/// Used across multiple presets (Preset5, Preset6, etc.)
class InspectDynamicState: ObservableObject {

    // MARK: - Published State (Triggers SwiftUI Updates)

    /// Custom processing messages per step (stepId → message)
    @Published var dynamicMessages: [String: String] = [:] {
        willSet {
            writeLog("MVVM: dynamicMessages willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Progress percentages per step (stepId → 0-100)
    @Published var progressPercentages: [String: Int] = [:] {
        willSet {
            writeLog("MVVM: progressPercentages willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Custom data display per step (stepId → [(key, value, color)])
    @Published var customDataDisplay: [String: [(String, String, String?)]] = [:] {
        willSet {
            writeLog("MVVM: customDataDisplay willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Dynamic guidance content updates (stepId → blockIndex → content)
    @Published var dynamicGuidanceContent: [String: [Int: String]] = [:] {
        willSet {
            writeLog("MVVM: dynamicGuidanceContent willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Dynamic guidance property updates (stepId → blockIndex → [property → value])
    /// This is the PRIMARY state for status badges, comparison tables, phase trackers
    @Published var dynamicGuidanceProperties: [String: [Int: [String: String]]] = [:] {
        willSet {
            writeLog("MVVM: dynamicGuidanceProperties willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Status icons per list item (index → "iconName-color")
    @Published var itemStatusIcons: [Int: String] = [:] {
        willSet {
            writeLog("MVVM: itemStatusIcons willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

    /// Continue button visibility per step (stepId → showButton)
    @Published var showContinueButton: [String: Bool] = [:] {
        willSet {
            writeLog("MVVM: showContinueButton willSet (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .debug)
        }
    }

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

        // Capture old value for debugging
        let oldValue = blockDict[property] ?? "(none)"

        // Update the property
        blockDict[property] = value
        stepDict[blockIndex] = blockDict

        // Reassign to trigger @Published
        dynamicGuidanceProperties[stepId] = stepDict

        writeLog("MVVM: updateGuidanceProperty('\(stepId)'[\(blockIndex)].\(property): '\(oldValue)' → '\(value)') (thread: \(Thread.isMainThread ? "MAIN" : "BG"))", logLevel: .info)
    }

    /// Batch update multiple properties on a guidance component (optimization)
    func updateGuidanceProperties(stepId: String, blockIndex: Int, properties: [String: String]) {
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]
        var blockDict = stepDict[blockIndex] ?? [:]

        // Merge all properties
        blockDict.merge(properties) { _, new in new }
        stepDict[blockIndex] = blockDict

        // Single @Published update
        dynamicGuidanceProperties[stepId] = stepDict

        writeLog("InspectDynamicState: Batch updated \(properties.count) properties for '\(stepId)'[\(blockIndex)]", logLevel: .info)
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
