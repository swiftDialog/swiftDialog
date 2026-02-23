//
//  PlistAggregator.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 10/11/2025
//  Shared utility for loading and aggregating plist data into compliance categories
//

import Foundation

/// Shared utility for loading and aggregating plist data
/// Extracts and generalizes plist processing logic originally in Preset5View
/// Used by both Preset5 (visual compliance dashboard) and Preset6 (step-by-step inspect mode)
class PlistAggregator {

    // MARK: - Data Models

    /// Represents a single compliance check item from a plist
    struct ComplianceItem {
        let id: String              // Original plist key
        let category: String        // Category (from prefix or explicit mapping)
        let finding: Bool           // true = passed, false = failed
        let isCritical: Bool       // Whether this is a critical check
        let displayName: String    // Human-readable name for UI display
    }

    /// Represents an aggregated category with compliance statistics
    struct ComplianceCategory {
        let name: String            // Category display name
        let passed: Int            // Number of passed checks
        let total: Int             // Total number of checks
        let score: Double          // Compliance score (0.0-1.0)
        let icon: String           // SF Symbol icon name
        let items: [ComplianceItem] // All items in this category
    }

    // MARK: - Core Methods

    /// Load and parse a plist source into compliance items
    /// - Parameter source: Plist source configuration
    /// - Returns: Tuple of compliance items and last check timestamp (if available)
    static func loadPlistSource(source: InspectConfig.PlistSourceConfig) -> (items: [ComplianceItem], lastCheck: String)? {

        // Memory safety: Check file size first to avoid loading huge plists
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let fileSize = fileAttributes[.size] as? Int64 else {
            writeLog("PlistAggregator: Unable to get file attributes for \(source.path)", logLevel: .error)
            return nil
        }

        // Prevent loading files larger than 10MB
        let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
        if fileSize > maxFileSize {
            writeLog("PlistAggregator: Plist file too large (\(fileSize) bytes) at \(source.path)", logLevel: .error)
            return nil
        }

        // Use autorelease pool for memory management
        return autoreleasepool { () -> (items: [ComplianceItem], lastCheck: String)? in
            guard let fileData = FileManager.default.contents(atPath: source.path) else {
                writeLog("PlistAggregator: Unable to read plist at \(source.path)", logLevel: .error)
                return nil
            }

            do {
                // Use PropertyListSerialization with explicit cleanup
                let plistObject = try PropertyListSerialization.propertyList(from: fileData, format: nil)

                guard let plistContents = plistObject as? [String: Any] else {
                    writeLog("PlistAggregator: Invalid plist format at \(source.path)", logLevel: .error)
                    return nil
                }

                var items: [ComplianceItem] = []
                let lastCheck = plistContents["lastComplianceCheck"] as? String ??
                               plistContents["LastUpdateCheck"] as? String ??
                               getCurrentTimestamp()

                // Process items with memory-conscious approach
                let maxItems = 1000 // Prevent processing too many items
                var processedCount = 0

                for (key, value) in plistContents {
                    if processedCount >= maxItems {
                        writeLog("PlistAggregator: Limiting plist processing to \(maxItems) items for \(source.path)", logLevel: .info)
                        break
                    }

                    if shouldProcessKey(key, source: source) {
                        if let finding = evaluateValue(value, source: source) {
                            let item = ComplianceItem(
                                id: String(key), // Ensure string copy, not reference
                                category: getCategoryForKey(key, source: source),
                                finding: finding,
                                isCritical: isCriticalKey(key, source: source),
                                displayName: getDisplayName(key, source: source)
                            )
                            items.append(item)
                            processedCount += 1
                        }
                    }
                }

                writeLog("PlistAggregator: Processed \(items.count) items from \(source.path)", logLevel: .info)
                return (items, lastCheck)

            } catch {
                writeLog("PlistAggregator: Error loading plist: \(error)", logLevel: .error)
                return nil
            }
        }
    }

    /// Group compliance items by category with aggregated statistics
    /// - Parameter items: Array of compliance items to categorize
    /// - Returns: Array of compliance categories with pass/fail statistics
    static func categorizeItems(_ items: [ComplianceItem]) -> [ComplianceCategory] {
        let grouped = Dictionary(grouping: items) { $0.category }

        return grouped.map { category, items in
            let passed = items.filter { $0.finding }.count
            let total = items.count
            let score = total > 0 ? Double(passed) / Double(total) : 0.0

            return ComplianceCategory(
                name: category,
                passed: passed,
                total: total,
                score: score,
                icon: getIconForCategory(category),
                items: items
            )
        }.sorted { $0.name < $1.name } // Sort alphabetically for consistent UI
    }

    /// Generate compact checkDetails string for compliance cards
    /// Formats compliance items as newline-separated bullet list with Unicode symbols
    /// - Parameters:
    ///   - items: Compliance items to format
    ///   - maxItems: Maximum number of items to include (default: 15)
    ///   - sortFailedFirst: Whether to show failed checks first for visibility (default: true)
    /// - Returns: Formatted checkDetails string with ✓/✗ symbols
    static func generateCheckDetails(
        items: [ComplianceItem],
        maxItems: Int = 15,
        sortFailedFirst: Bool = true
    ) -> String {

        // Sort: failed first (for visibility), then by display name
        let sorted = sortFailedFirst
            ? items.sorted { lhs, rhs in
                // Failed items (finding=false) come first
                if lhs.finding != rhs.finding {
                    return !lhs.finding // false < true (failed before passed)
                }
                return lhs.displayName < rhs.displayName
            }
            : items.sorted { $0.displayName < $1.displayName }

        var lines: [String] = []
        for item in sorted.prefix(maxItems) {
            let symbol = item.finding ? "✓" : "✗"
            lines.append("\(symbol) \(item.displayName)")
        }

        // Add ellipsis if truncated
        if items.count > maxItems {
            let remaining = items.count - maxItems
            lines.append("... and \(remaining) more")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helper Methods (Ported from Preset5)

    /// Determine if a plist key should be processed based on source configuration
    private static func shouldProcessKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        // Skip timestamp and metadata keys
        let skipKeys = ["lastComplianceCheck", "LastUpdateCheck", "CFBundleVersion", "_"]
        if skipKeys.contains(key) || key.hasPrefix("_") { return false }

        // If key mappings exist, only process mapped keys
        if let keyMappings = source.keyMappings {
            return keyMappings.contains { $0.key == key }
        }

        // For compliance type, process all non-metadata keys
        if source.type == "compliance" {
            return true
        }

        // For other types, process all keys
        return true
    }

    /// Evaluate a plist value to determine pass/fail status
    private static func evaluateValue(_ value: Any, source: InspectConfig.PlistSourceConfig) -> Bool? {
        let successValues = source.successValues ?? ["true", "1", "YES"]

        // Handle boolean values
        if let boolValue = value as? Bool {
            return successValues.contains(String(boolValue))
        }

        // Handle string values
        if let stringValue = value as? String {
            return successValues.contains(stringValue)
        }

        // Handle number values
        if let numberValue = value as? NSNumber {
            return successValues.contains(numberValue.stringValue)
        }

        // Handle nested dictionary (e.g., CIS audit format: { "finding": false })
        if let dictValue = value as? [String: Any] {
            if let finding = dictValue["finding"] as? Bool {
                return successValues.contains(String(finding))
            }
            if let status = dictValue["status"] as? String {
                return successValues.contains(status)
            }
        }

        return nil
    }

    /// Get category name for a plist key based on source configuration
    private static func getCategoryForKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> String {
        // Priority 1: Check explicit key mappings
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let category = mapping.category {
                return category
            }
        }

        // Priority 2: Check category prefixes (e.g., "os_*" -> "Operating System")
        if let categoryPrefix = source.categoryPrefix {
            for (prefix, category) in categoryPrefix where key.hasPrefix(prefix) {
                return category
            }
        }

        // Fallback: Use source display name
        return source.displayName
    }

    /// Determine if a plist key represents a critical check
    private static func isCriticalKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        // Priority 1: Check key mappings for explicit isCritical flag
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let isCritical = mapping.isCritical {
                return isCritical
            }
        }

        // Priority 2: Check critical keys list
        if let criticalKeys = source.criticalKeys {
            return criticalKeys.contains(key)
        }

        return false
    }

    /// Generate human-readable display name from plist key
    private static func getDisplayName(_ key: String, source: InspectConfig.PlistSourceConfig) -> String {
        // Priority 1: Use explicit keyMapping displayName
        if let keyMappings = source.keyMappings,
           let mapping = keyMappings.first(where: { $0.key == key }),
           let displayName = mapping.displayName {
            return displayName
        }

        // Priority 2: Format key by removing category prefix and title-casing
        var cleanedKey = key
        if let categoryPrefix = source.categoryPrefix {
            for (prefix, _) in categoryPrefix where key.hasPrefix(prefix) {
                cleanedKey = String(key.dropFirst(prefix.count))
                break
            }
        }

        // Convert underscores to spaces and title case
        return cleanedKey
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Get default SF Symbol icon for category
    private static func getIconForCategory(_ category: String) -> String {
        let iconMap: [String: String] = [
            "Audit and Accountability": "doc.text.magnifyingglass",
            "Authentication": "person.badge.key.fill",
            "Operating System": "desktopcomputer",
            "Password Policy": "lock.shield.fill",
            "System Preferences": "gearshape.2.fill",
            "Network": "network",
            "Security": "shield.fill",
            "Applications": "square.grid.2x2.fill",
            "Enrollment": "checkmark.seal.fill",
            "Connectivity": "wifi"
        ]
        return iconMap[category] ?? "circle.fill"
    }

    /// Get current timestamp as formatted string
    private static func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
