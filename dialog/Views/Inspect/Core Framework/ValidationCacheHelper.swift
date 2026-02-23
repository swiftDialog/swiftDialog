//
//  ValidationCacheHelper.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Generic validation caching utilities for Inspect presets
//  Consolidates shared caching patterns from legacy presets
//

import Foundation
import SwiftUI

// MARK: - Validation Source

/// Source of validation data
enum ValidationSource: String, CustomStringConvertible {
    case fileSystem = "fileSystem"
    case plist = "plist"
    case emptyPaths = "emptyPaths"

    var description: String { rawValue }
}

// MARK: - Validation Result

/// Generic validation result for caching to prevent UI flickering
struct PresetValidationResult {
    let isValid: Bool
    let isInstalled: Bool
    let timestamp: Date
    let source: ValidationSource

    init(isValid: Bool, isInstalled: Bool, source: ValidationSource) {
        self.isValid = isValid
        self.isInstalled = isInstalled
        self.timestamp = Date()
        self.source = source
    }

    /// Status string for external monitoring
    var statusString: String {
        if isInstalled {
            return "completed"
        } else if isValid {
            return "condition_met"
        } else {
            return "condition_not_met"
        }
    }
}

// MARK: - Validation Cache

/// Thread-safe validation cache for item validation results
class ValidationCache {
    private var cache: [String: PresetValidationResult] = [:]
    private var lastValidationTime: [String: Date] = [:]
    private let lock = NSLock()

    /// Get cached result for an item
    func getResult(for itemId: String) -> PresetValidationResult? {
        lock.lock()
        defer { lock.unlock() }
        return cache[itemId]
    }

    /// Cache a validation result
    func setResult(_ result: PresetValidationResult, for itemId: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[itemId] = result
        lastValidationTime[itemId] = result.timestamp
    }

    /// Check if a cached result is stale
    func isStale(for itemId: String, maxAge: TimeInterval = 1.0) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let lastTime = lastValidationTime[itemId] else {
            return true
        }
        return Date().timeIntervalSince(lastTime) > maxAge
    }

    /// Check if result was from cache (same timestamp)
    func isCached(itemId: String, result: PresetValidationResult) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let lastTime = lastValidationTime[itemId] else {
            return false
        }
        return lastTime != result.timestamp
    }

    /// Clear all cached results
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        lastValidationTime.removeAll()
    }

    /// Clear cached result for specific item
    func clearResult(for itemId: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: itemId)
        lastValidationTime.removeValue(forKey: itemId)
    }
}

// MARK: - Status Plist Writer

/// Writes validation status to plist for external monitoring
enum ValidationStatusWriter {

    /// Write status to plist for external monitoring
    /// - Parameters:
    ///   - presetName: Name of the preset (e.g., "Preset5", "Preset6")
    ///   - itemId: ID of the item being validated
    ///   - itemName: Display name of the item
    ///   - result: Validation result
    ///   - isCached: Whether this result was from cache
    static func writeStatus(
        presetName: String,
        itemId: String,
        itemName: String,
        result: PresetValidationResult,
        isCached: Bool
    ) {
        let statusPath = "/tmp/\(presetName.lowercased())_status.plist"
        let statusData: [String: Any] = [
            "timestamp": result.timestamp,
            "item_id": itemId,
            "item_name": itemName,
            "status": result.statusString,
            "is_valid": result.isValid,
            "is_installed": result.isInstalled,
            "validation_source": result.source.rawValue,
            "cached": isCached
        ]

        do {
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: statusData,
                format: .xml,
                options: 0
            )
            try plistData.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
        } catch {
            writeLog("\(presetName): Failed to write status plist: \(error.localizedDescription)", logLevel: .error)
        }
    }

    /// Log status change to console for external monitoring
    static func logStatusChange(
        presetName: String,
        itemId: String,
        result: PresetValidationResult,
        isCached: Bool
    ) {
        print("[\(presetName.uppercased())_STATUS_CHANGE] item=\(itemId) status=\(result.statusString) source=\(result.source) cached=\(isCached)")
    }
}

// MARK: - Validation State Manager

/// Manages completed items state with stable update logic
class ValidationStateManager {
    private let presetName: String
    private var completedItems: Set<String>
    private let lock = NSLock()
    private let onCompletionChange: ((String, Bool) -> Void)?

    init(presetName: String, initialCompleted: Set<String> = [], onCompletionChange: ((String, Bool) -> Void)? = nil) {
        self.presetName = presetName
        self.completedItems = initialCompleted
        self.onCompletionChange = onCompletionChange
    }

    /// Apply validation result with stable state management
    /// - Parameters:
    ///   - itemId: ID of the item
    ///   - itemPaths: Item's configured paths (for empty path handling)
    ///   - result: Validation result
    /// - Returns: True if state changed
    @discardableResult
    func applyResult(itemId: String, itemPaths: [String], result: PresetValidationResult) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let wasCompleted = completedItems.contains(itemId)
        let shouldBeCompleted = result.isInstalled

        // Special handling for items with empty paths - once marked as completed, preserve state
        if itemPaths.isEmpty && wasCompleted {
            writeLog("\(presetName): Item \(itemId) has empty paths and is already completed - preserving state", logLevel: .debug)
            return false
        }

        // Only update completion state if there's a real change
        if shouldBeCompleted && !wasCompleted {
            completedItems.insert(itemId)
            writeLog("\(presetName): Item \(itemId) marked as completed (\(result.source))", logLevel: .info)
            onCompletionChange?(itemId, true)
            return true
        } else if !shouldBeCompleted && wasCompleted {
            // Only remove if we're certain from file system check
            if result.source == .fileSystem {
                completedItems.remove(itemId)
                writeLog("\(presetName): Item \(itemId) removed from completed (\(result.source))", logLevel: .info)
                onCompletionChange?(itemId, false)
                return true
            }
        }

        return false
    }

    /// Check if an item is completed
    func isCompleted(_ itemId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return completedItems.contains(itemId)
    }

    /// Get all completed items
    func getCompletedItems() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return completedItems
    }

    /// Sync with external state (e.g., from InspectState)
    func sync(with externalCompleted: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        completedItems = externalCompleted
    }
}
