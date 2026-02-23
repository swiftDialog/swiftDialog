//
//  Progress.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Progress tracking service for Inspect mode
//  Handles progress calculation, status management, and preset-specific progress data
//

import Foundation
import SwiftUI

// MARK: - Progress Models

struct ItemProgress {
    let itemId: String
    let status: InspectItemStatus
    let timestamp: Date
}

struct OverallProgress {
    let totalItems: Int
    let completedItems: Int
    let downloadingItems: Int
    let pendingItems: Int
    let progressPercentage: Double

    var isComplete: Bool {
        return completedItems == totalItems && totalItems > 0
    }
}

// MARK: - Progress Service

class Progress: ObservableObject {

    // MARK: Published Properties

    @Published var overallProgress = OverallProgress(
        totalItems: 0,
        completedItems: 0,
        downloadingItems: 0,
        pendingItems: 0,
        progressPercentage: 0.0
    )

    @Published var itemStatuses: [String: InspectItemStatus] = [:]

    // MARK: Private Properties

    private var items: [InspectConfig.ItemConfig] = []
    private var statusHistory: [ItemProgress] = []

    // Preset-specific data
    private var presetData: [String: Any] = [:]

    // MARK: - Initialization

    init(preset: String? = nil, items: [InspectConfig.ItemConfig] = []) {
        self.items = items

        // Initialize item statuses
        for item in items {
            itemStatuses[item.id] = .pending
        }

        updateOverallProgress()
        writeLog("ProgressService: Initialized with \(items.count) items", logLevel: .debug)
    }

    // MARK: - Public API

    func configureItems(_ items: [InspectConfig.ItemConfig]) {
        self.items = items
        itemStatuses.removeAll()

        // Initialize all items as pending
        for item in items {
            itemStatuses[item.id] = .pending
        }

        updateOverallProgress()
        writeLog("ProgressService: Configured with \(items.count) items", logLevel: .info)
    }

    func updateItemStatus(_ itemId: String, status: InspectItemStatus) {
        // Prevent infinite loops by checking if status actually changed
        if let currentStatus = itemStatuses[itemId], statusesEqual(currentStatus, status) {
            return // No change, avoid unnecessary updates
        }
        
        // Auto-add item if not known (for backwards compatibility)
        if itemStatuses[itemId] == nil {
            itemStatuses[itemId] = status
            writeLog("ProgressService: Auto-added item ID: \(itemId)", logLevel: .debug)
        }

        // Record status change with memory management
        let progress = ItemProgress(
            itemId: itemId,
            status: status,
            timestamp: Date()
        )
        statusHistory.append(progress)
        
        // Limit history size to prevent memory accumulation
        if statusHistory.count > 1000 {
            statusHistory.removeFirst(500) // Keep most recent 500 entries
        }

        // Update current status
        itemStatuses[itemId] = status

        // Update overall progress
        updateOverallProgress()

        // Log significant changes
        switch status {
        case .completed:
            writeLog("ProgressService: Item '\(itemId)' completed", logLevel: .info)
        case .failed(let error):
            writeLog("ProgressService: Item '\(itemId)' failed: \(error)", logLevel: .error)
        default:
            break
        }
    }
    
    /// Helper to compare InspectItemStatus values for equality
    private func statusesEqual(_ lhs: InspectItemStatus, _ rhs: InspectItemStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.downloading, .downloading), (.completed, .completed):
            return true
        case (.failed(let error1), .failed(let error2)):
            return error1 == error2
        default:
            return false
        }
    }

    func setItemCompleted(_ itemId: String) {
        updateItemStatus(itemId, status: .completed)
    }

    func setItemDownloading(_ itemId: String) {
        updateItemStatus(itemId, status: .downloading)
    }

    func setItemPending(_ itemId: String) {
        updateItemStatus(itemId, status: .pending)
    }

    func setItemFailed(_ itemId: String, error: String) {
        updateItemStatus(itemId, status: .failed(error))
    }

    func resetAllItems() {
        for itemId in itemStatuses.keys {
            itemStatuses[itemId] = .pending
        }
        statusHistory.removeAll()
        updateOverallProgress()
        writeLog("ProgressService: Reset all items to pending", logLevel: .info)
    }

    // MARK: - Progress Calculation

    private func updateOverallProgress() {
        // Cache counts for efficiency
        var completed = 0
        var downloading = 0
        var pending = 0
        
        // Single pass through statuses for better performance
        for status in itemStatuses.values {
            switch status {
            case .completed:
                completed += 1
            case .downloading:
                downloading += 1
            case .pending:
                pending += 1
            case .failed:
                // Count failed items as pending for progress purposes
                pending += 1
            }
        }

        let total = itemStatuses.count
        let percentage = total > 0 ? Double(completed) / Double(total) : 0.0

        // Only update if values actually changed to prevent unnecessary UI updates
        let newProgress = OverallProgress(
            totalItems: total,
            completedItems: completed,
            downloadingItems: downloading,
            pendingItems: pending,
            progressPercentage: percentage
        )
        
        if !progressEquals(overallProgress, newProgress) {
            overallProgress = newProgress
        }
    }
    
    /// Helper to compare OverallProgress values for equality
    private func progressEquals(_ lhs: OverallProgress, _ rhs: OverallProgress) -> Bool {
        return lhs.totalItems == rhs.totalItems &&
               lhs.completedItems == rhs.completedItems &&
               lhs.downloadingItems == rhs.downloadingItems &&
               lhs.pendingItems == rhs.pendingItems &&
               abs(lhs.progressPercentage - rhs.progressPercentage) < 0.001
    }

    // MARK: - Status Queries

    func isItemCompleted(_ itemId: String) -> Bool {
        if case .completed = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func isItemDownloading(_ itemId: String) -> Bool {
        if case .downloading = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func isItemPending(_ itemId: String) -> Bool {
        if case .pending = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func getItemStatus(_ itemId: String) -> InspectItemStatus? {
        return itemStatuses[itemId]
    }

    func getCompletedItems() -> Set<String> {
        // Optimize with compactMap for better performance
        let completedItems = itemStatuses.compactMap { (key, value) in
            switch value {
            case .completed:
                return key
            default:
                return nil
            }
        }
        return Set(completedItems)
    }

    func getDownloadingItems() -> Set<String> {
        // Optimize with compactMap for better performance
        let downloadingItems = itemStatuses.compactMap { (key, value) in
            switch value {
            case .downloading:
                return key
            default:
                return nil
            }
        }
        return Set(downloadingItems)
    }
    
    func getPendingItems() -> Set<String> {
        // New method for consistency
        let pendingItems = itemStatuses.compactMap { (key, value) in
            switch value {
            case .pending:
                return key
            default:
                return nil
            }
        }
        return Set(pendingItems)
    }

    // MARK: - Preset-Specific Data

    func updatePresetData(_ key: String, value: Any) {
        presetData[key] = value
        writeLog("ProgressService: Updated preset data '\(key)'", logLevel: .debug)
    }

    func getPresetData(_ key: String) -> Any? {
        return presetData[key]
    }

    // For Preset1 spinner
    func updatePreset1Spinner(active: Bool) {
        _ = Array(getDownloadingItems())
        // Progress tracking removed - no longer needed
    }

    // MARK: - History & Analytics

    func getStatusHistory(for itemId: String? = nil) -> [ItemProgress] {
        if let itemId = itemId {
            return statusHistory.filter { $0.itemId == itemId }
        }
        return statusHistory
    }

    func getAverageCompletionTime() -> TimeInterval? {
        var completionTimes: [TimeInterval] = []
        
        // Limit processing to prevent timeout on large datasets
        let itemsToProcess = Array(itemStatuses.keys.prefix(100)) // Process max 100 items

        for itemId in itemsToProcess {
            let history = getStatusHistory(for: itemId)

            // Find download start time
            let downloadStart = history.first { progress in
                switch progress.status {
                case .downloading:
                    return true
                default:
                    return false
                }
            }

            // Find completion time
            let completion = history.first { progress in
                switch progress.status {
                case .completed:
                    return true
                default:
                    return false
                }
            }

            if let start = downloadStart?.timestamp,
               let end = completion?.timestamp,
               end.timeIntervalSince(start) > 0 { // Ensure positive time interval
                completionTimes.append(end.timeIntervalSince(start))
            }
        }

        guard !completionTimes.isEmpty else { return nil }
        
        // Calculate average with safety check
        let total = completionTimes.reduce(0, +)
        let count = Double(completionTimes.count)
        guard count > 0 else { return nil }
        
        return total / count
    }

    // MARK: - Cleanup and Memory Management
    
    func cleanupHistory() {
        // Clean up old history entries to prevent memory accumulation
        let cutoffDate = Date().addingTimeInterval(-3600) // Keep last hour only
        statusHistory.removeAll { $0.timestamp < cutoffDate }
        writeLog("ProgressService: Cleaned up old history entries", logLevel: .debug)
    }
    
    func reset() {
        itemStatuses.removeAll()
        statusHistory.removeAll()
        presetData.removeAll()
        
        overallProgress = OverallProgress(
            totalItems: 0,
            completedItems: 0,
            downloadingItems: 0,
            pendingItems: 0,
            progressPercentage: 0.0
        )
        
        writeLog("ProgressService: Complete reset performed", logLevel: .info)
    }

    // MARK: - Helper Methods

    private func statusString(for status: InspectItemStatus) -> String {
        switch status {
        case .pending:
            return "pending"
        case .downloading:
            return "downloading"
        case .completed:
            return "complete"
        case .failed(let error):
            return "failed(\(error))"
        }
    }

    deinit {
        // Clean up all data to prevent memory leaks
        itemStatuses.removeAll()
        statusHistory.removeAll()
        presetData.removeAll()
        
        writeLog("ProgressService: Deinitialized and cleaned up", logLevel: .debug)
    }
}

// MARK: - Bottom Progress Bar Components

/// Visual states for the bottom progress bar
enum ProgressBarVisualState {
    case normal     // Default blue
    case complete   // All steps done - green
    case blocking   // Has blocking/required incomplete items - orange
    case error      // Error state - red
}

/// Helper to calculate progress bar state based on items and configuration
struct ProgressBarStateCalculator {

    /// Evaluates the current progress bar state
    /// - Parameters:
    ///   - config: Optional progress bar configuration
    ///   - items: All items in the current preset
    ///   - completedSteps: Set of completed item IDs
    ///   - inspectState: InspectState for form validation
    ///   - currentStep: Current step index
    /// - Returns: The appropriate visual state for the progress bar
    static func evaluate(
        config: InspectConfig.ProgressBarConfig?,
        items: [InspectConfig.ItemConfig],
        completedSteps: Set<String>,
        inspectState: InspectState,
        currentStep: Int
    ) -> ProgressBarVisualState {

        // If status colors are disabled, always return normal
        guard config?.enableStatusColors == true else { return .normal }

        // Check completion state first (highest priority)
        if config?.showCompletionState == true {
            if items.allSatisfy({ completedSteps.contains($0.id) }) {
                return .complete
            }
        }

        // Check CURRENT step only (matches button enable logic)
        if config?.showBlockingState == true {
            guard currentStep < items.count else { return .normal }
            let currentItem = items[currentStep]

            let isBlocking = currentItem.blocking == true
            let isRequired = currentItem.required == true
            let notCompleted = !completedSteps.contains(currentItem.id)

            // If current step is blocking/required and not completed
            if notCompleted && (isBlocking || isRequired) {
                // If has guidance content (interactive forms), check if requirements are satisfied
                // This matches the button logic: hasRequiredFields ? validateGuidanceInputs : true
                if currentItem.guidanceContent?.isEmpty == false {
                    // Has interactive form - check if valid
                    // If valid, NOT blocking (button enabled) → return .normal (blue)
                    // If invalid, blocking (button disabled) → return .blocking (orange)
                    let isFormValid = inspectState.validateGuidanceInputs(for: currentItem)
                    return isFormValid ? .normal : .blocking
                }
                // No interactive form - still blocking until completed
                return .blocking
            }
        }

        return .normal
    }

    /// Gets the appropriate color for a given state
    static func color(for state: ProgressBarVisualState, config: InspectConfig.ProgressBarConfig?) -> Color {
        switch state {
        case .normal: return config?.normalColor ?? Color.blue
        case .complete: return config?.completeColor ?? Color.green
        case .blocking: return config?.blockingColor ?? Color.orange
        case .error: return config?.errorColor ?? Color.red
        }
    }
}

/// Reusable bottom progress bar component for Inspect mode presets
struct InspectBottomProgressBar: View {
    @ObservedObject var inspectState: InspectState
    @Binding var completedSteps: Set<String>
    let currentStep: Int
    let scaleFactor: CGFloat

    /// Current progress bar visual state
    private var progressBarState: ProgressBarVisualState {
        ProgressBarStateCalculator.evaluate(
            config: inspectState.config?.progressBarConfig,
            items: inspectState.items,
            completedSteps: completedSteps,
            inspectState: inspectState,
            currentStep: currentStep
        )
    }

    /// Progress bar color based on current state
    private var progressBarColor: Color {
        ProgressBarStateCalculator.color(
            for: progressBarState,
            config: inspectState.config?.progressBarConfig
        )
    }

    /// Current progress percentage (0.0 to 1.0) based on completed items
    private var progressPercentage: Double {
        guard !inspectState.items.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(inspectState.items.count)
    }

    var body: some View {
        if !inspectState.items.isEmpty {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track - subtle and rounded
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        // Progress fill - dynamic color with smooth animation and depth
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressBarColor)
                            .frame(width: geometry.size.width * progressPercentage, height: 8)
                            .shadow(color: progressBarColor.opacity(0.3), radius: 2, x: 0, y: 1)
                            .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                            .animation(.easeInOut(duration: 0.5), value: progressBarColor)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 12)
                .padding([.top, .bottom], 12)
            }
            .frame(height: 16)
            .clipped()  // Prevent overflow beyond container
        }
    }
}
