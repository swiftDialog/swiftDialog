//
//  PlistAggregator.swift
//  dialog
//
//  Loads plist sources into compliance items and categories.
//

import Foundation

/// Loads and aggregates plist data; used by the compliance aggregator, compliance sheets, findings
/// blocks and bento cells.
class PlistAggregator {

    // MARK: - Data Models

    /// User-visible severity, derived from the evaluated pass/fail (see `evaluateValue`), not the raw
    /// `finding` literal. `severity: "warning"` in keyMapping softens a failing check in the detail sheet.
    enum CellSeverity: String {
        case healthy
        case warning
        case failure
    }

    /// One compliance check from a plist.
    struct ComplianceItem {
        let id: String              // Original plist key
        let category: String        // Category (from prefix or explicit mapping)
        /// The evaluated result: true means the check passed. Source polarity is already applied, so a
        /// `finding: true` (rule failed) arrives as `false`.
        let finding: Bool
        let isCritical: Bool       // Whether this is a critical check
        let displayName: String    // Human-readable name for UI display
        // Remediation fields; plist values override keyMapping defaults.
        let severity: CellSeverity
        let explanation: String?
        let remediation: String?
        let actionButtonText: String?
        let actionURL: String?
        /// The value the baseline requires, e.g. `expire_after ≥ 90`.
        let expected: String?
        /// The value actually found, e.g. `expire_after = 30`.
        let found: String?
        /// When this check last passed; nil if it never has, and the UI must not show a placeholder date.
        let lastPassed: Date?
        /// Baseline reference, e.g. `CIS 3.4`.
        let reference: String?
    }

    /// Result of parsing one plist value: the pass/fail bit, plus sibling-key strings when the value is
    /// a nested dictionary (e.g. `{ finding: false, explanation: ... }`).
    struct EvaluatedValue {
        let finding: Bool
        let explanation: String?
        let remediation: String?
        let actionButtonText: String?
        let actionURL: String?
        var expected: String?
        var found: String?
        var lastPassed: Date?
        var reference: String?
    }

    /// A category with compliance statistics.
    struct ComplianceCategory {
        let name: String            // Category display name
        let passed: Int            // Number of passed checks
        let total: Int             // Total number of checks
        let score: Double          // Compliance score (0.0-1.0)
        let icon: String           // SF Symbol icon name
        let items: [ComplianceItem] // All items in this category
    }

    // MARK: - Core Methods

    /// Loads a plist source into compliance items and the last check timestamp, if any.
    static func loadPlistSource(source: InspectConfig.PlistSourceConfig) -> (items: [ComplianceItem], lastCheck: String)? {

        // Check the file size first to avoid loading huge plists.
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let fileSize = fileAttributes[.size] as? Int64 else {
            writeLog("PlistAggregator: Unable to get file attributes for \(source.path)", logLevel: .error)
            return nil
        }

        // Skip files over 10 MB.
        let maxFileSize: Int64 = 10 * 1024 * 1024
        if fileSize > maxFileSize {
            writeLog("PlistAggregator: Plist file too large (\(fileSize) bytes) at \(source.path)", logLevel: .error)
            return nil
        }

        return autoreleasepool { () -> (items: [ComplianceItem], lastCheck: String)? in
            guard let fileData = FileManager.default.contents(atPath: source.path) else {
                writeLog("PlistAggregator: Unable to read plist at \(source.path)", logLevel: .error)
                return nil
            }

            do {
                let plistObject = try PropertyListSerialization.propertyList(from: fileData, format: nil)

                guard let plistContents = plistObject as? [String: Any] else {
                    writeLog("PlistAggregator: Invalid plist format at \(source.path)", logLevel: .error)
                    return nil
                }

                var items: [ComplianceItem] = []
                // Last check timestamp: the configured timestampKey, else common key names.
                let lastCheckValue: Any? = {
                    if let configuredKey = source.timestampKey {
                        return plistContents[configuredKey]
                    }
                    let fallbackKeys = ["lastComplianceCheck", "LastUpdateCheck", "lastCheck", "timestamp", "lastModified", "updatedAt"]
                    for key in fallbackKeys {
                        if let value = plistContents[key] {
                            return value
                        }
                    }
                    return nil
                }()
                let lastCheck = DateDisplayService.shared.parseAndFormat(lastCheckValue, fallback: getCurrentTimestamp())

                let maxItems = 1000 // Prevent processing too many items
                var processedCount = 0

                for (key, value) in plistContents {
                    if processedCount >= maxItems {
                        writeLog("PlistAggregator: Limiting plist processing to \(maxItems) items for \(source.path)", logLevel: .info)
                        break
                    }

                    if shouldProcessKey(key, source: source) {
                        if let evaluated = evaluateValue(value, source: source) {
                            // Plist sibling values override keyMapping defaults.
                            let mapping = source.keyMappings?.first(where: { $0.key == key })
                            let severity: CellSeverity = {
                                if let raw = mapping?.severity, let parsed = CellSeverity(rawValue: raw) {
                                    return parsed
                                }
                                return evaluated.finding ? .healthy : .failure
                            }()
                            let item = ComplianceItem(
                                id: String(key),
                                category: getCategoryForKey(key, source: source),
                                finding: evaluated.finding,
                                isCritical: isCriticalKey(key, source: source),
                                displayName: getDisplayName(key, source: source),
                                severity: severity,
                                explanation: evaluated.explanation ?? mapping?.explanation,
                                remediation: evaluated.remediation ?? mapping?.remediation,
                                actionButtonText: evaluated.actionButtonText ?? mapping?.actionButtonText,
                                actionURL: evaluated.actionURL ?? mapping?.actionURL,
                                expected: evaluated.expected ?? mapping?.expected,
                                found: evaluated.found,
                                lastPassed: evaluated.lastPassed,
                                reference: evaluated.reference ?? mapping?.reference
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

    /// Groups items by category with pass/fail statistics.
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
        }.sorted { $0.name < $1.name }  // alphabetical for a stable UI
    }

    /// Compact ✓/✗ bullet list for compliance cards, at most `maxItems` lines, failed first by default.
    static func generateCheckDetails(
        items: [ComplianceItem],
        maxItems: Int = 15,
        sortFailedFirst: Bool = true
    ) -> String {

        // Failed first, then by display name.
        let sorted = sortFailedFirst
            ? items.sorted { lhs, rhs in
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

        // Ellipsis when truncated.
        if items.count > maxItems {
            let remaining = items.count - maxItems
            lines.append("... and \(remaining) more")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helper Methods

    /// Whether a plist key should be processed for this source.
    private static func shouldProcessKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        // Skip conventional timestamp and metadata keys; configured keys are checked below.
        let skipKeys = ["lastComplianceCheck", "LastUpdateCheck", "lastCheck", "timestamp",
                        "CFBundleVersion", "_"]
        if skipKeys.contains(key) || key.hasPrefix("_") { return false }

        // The configured timestamp key is never read as a check.
        if let timestampKey = source.timestampKey, key == timestampKey { return false }

        // Honour `excludeKeys` and `includePattern`, as the auto-discovery path in `Config+Helpers.swift` does.
        if let excluded = source.excludeKeys, excluded.contains(key) { return false }

        if let pattern = source.includePattern, !pattern.isEmpty,
           key.range(of: pattern, options: .regularExpression) == nil {
            return false
        }

        // With key mappings, only mapped keys are processed.
        if let keyMappings = source.keyMappings {
            return keyMappings.contains { $0.key == key }
        }

        // Compliance sources process all non-metadata keys.
        if source.type == "compliance" {
            return true
        }

        return true
    }

    /// Evaluates a plist value to pass/fail, plus remediation strings for a nested dictionary.
    private static func evaluateValue(_ value: Any, source: InspectConfig.PlistSourceConfig) -> EvaluatedValue? {
        let successValues = source.successValues ?? ["true", "1", "YES"]

        if let boolValue = value as? Bool {
            return EvaluatedValue(finding: successValues.contains(String(boolValue)),
                                  explanation: nil, remediation: nil,
                                  actionButtonText: nil, actionURL: nil)
        }

        if let stringValue = value as? String {
            return EvaluatedValue(finding: successValues.contains(stringValue),
                                  explanation: nil, remediation: nil,
                                  actionButtonText: nil, actionURL: nil)
        }

        if let numberValue = value as? NSNumber {
            return EvaluatedValue(finding: successValues.contains(numberValue.stringValue),
                                  explanation: nil, remediation: nil,
                                  actionButtonText: nil, actionURL: nil)
        }

        // Nested dictionary (e.g. `{ "finding": false, "explanation": "..." }`). `finding: true` means the
        // rule failed, the opposite of a bare scalar, so the default success value is `expectedValue ?? "false"`,
        // matching `Config+Helpers.swift`. An explicit `successValues` still wins.
        if let dictValue = value as? [String: Any] {
            let findingKey = source.findingKey ?? "finding"
            let expectedValue = source.expectedValue ?? "false"
            let finding: Bool? = {
                if let finding = dictValue[findingKey] as? Bool {
                    if let explicit = source.successValues { return explicit.contains(String(finding)) }
                    return String(finding) == expectedValue
                }
                if let status = dictValue["status"] as? String {
                    return successValues.contains(status)
                }
                return nil
            }()
            guard let finding else { return nil }
            return EvaluatedValue(
                finding: finding,
                explanation: dictValue["explanation"] as? String,
                remediation: dictValue["remediation"] as? String,
                actionButtonText: dictValue["actionButtonText"] as? String,
                actionURL: dictValue["actionURL"] as? String,
                expected: dictValue["expected"] as? String,
                found: dictValue["found"] as? String,
                // Accept a plist <date> or an ISO-8601 string; anything else stays nil rather than guessed.
                lastPassed: (dictValue["lastPassed"] as? Date)
                    ?? (dictValue["lastPassed"] as? String).flatMap {
                        ISO8601DateFormatter().date(from: $0)
                    },
                reference: dictValue["reference"] as? String
            )
        }

        return nil
    }

    /// Category for a key: explicit key mapping, then category prefix, then the source display name.
    private static func getCategoryForKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> String {
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let category = mapping.category {
                return category
            }
        }

        // Category prefixes, e.g. "os_*" → "Operating System".
        if let categoryPrefix = source.categoryPrefix {
            for (prefix, category) in categoryPrefix where key.hasPrefix(prefix) {
                return category
            }
        }

        return source.displayName
    }

    /// Whether a key is critical: the key mapping's isCritical flag, then the criticalKeys list.
    private static func isCriticalKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let isCritical = mapping.isCritical {
                return isCritical
            }
        }

        if let criticalKeys = source.criticalKeys {
            return criticalKeys.contains(key)
        }

        return false
    }

    /// Display name for a key: the keyMapping displayName, else the key without its prefix, title-cased.
    private static func getDisplayName(_ key: String, source: InspectConfig.PlistSourceConfig) -> String {
        if let keyMappings = source.keyMappings,
           let mapping = keyMappings.first(where: { $0.key == key }),
           let displayName = mapping.displayName {
            return displayName
        }

        var cleanedKey = key
        if let categoryPrefix = source.categoryPrefix {
            for (prefix, _) in categoryPrefix where key.hasPrefix(prefix) {
                cleanedKey = String(key.dropFirst(prefix.count))
                break
            }
        }

        return cleanedKey
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Default SF Symbol for a category.
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

    /// Current timestamp as a formatted string.
    private static func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
