//
//  InspectState+PlistMonitors.swift
//  dialog
//
//  Plist monitors: start, stop, read and evaluate a watched value on a poll.
//

import SwiftUI

extension InspectState {
    // MARK: - Plist Monitoring

    /// Polls a plist value every `recheckInterval` seconds (1-3600) and stops after the first
    /// change, calling `onValueChanged(oldValue, newValue)`.
    func startPlistMonitoring(
        itemId: String,
        item: InspectConfig.ItemConfig,
        recheckInterval: Int,
        onValueChanged: @escaping (String, String) -> Void
    ) {
        guard item.plistKey != nil, recheckInterval > 0 else {
            writeLog("InspectState: Cannot start monitoring for '\(itemId)' - missing plistKey or invalid interval", logLevel: .error)
            return
        }

        guard recheckInterval >= 1 && recheckInterval <= 3600 else {
            writeLog("InspectState: Invalid recheckInterval \(recheckInterval) for '\(itemId)', must be 1-3600", logLevel: .error)
            return
        }

        stopPlistMonitoring(itemId: itemId)

        let useUserDefaults = item.useUserDefaults == true
        let readingMethod = useUserDefaults ? "UserDefaults" : "file"

        if useUserDefaults {
            guard let path = item.paths.first, Validation.shared.extractDomainFromPath(path) != nil else {
                writeLog("InspectState: Cannot extract UserDefaults domain from path for '\(itemId)'", logLevel: .error)
                return
            }
        }

        let initialValue = currentPlistValue(item: item, useUserDefaults: useUserDefaults)
        writeLog("InspectState: Starting plist monitoring (\(readingMethod)) for '\(itemId)' - initial: \(initialValue), interval: \(recheckInterval)s", logLevel: .info)

        let poll = Poll(every: TimeInterval(recheckInterval))
        poll.start { [weak self] in
            guard let self else { return }
            let currentValue = self.currentPlistValue(item: item, useUserDefaults: useUserDefaults)
            if currentValue != initialValue {
                writeLog("InspectState: Plist value changed (\(readingMethod)) for '\(itemId)': \(initialValue) → \(currentValue)", logLevel: .info)
                onValueChanged(initialValue, currentValue)
                self.stopPlistMonitoring(itemId: itemId)
            }
        }

        plistMonitors[itemId] = PlistMonitorTask(
            poll: poll,
            initialValue: initialValue,
            currentValue: initialValue,
            recheckInterval: recheckInterval
        )
    }

    /// UserDefaults by the first path's domain, or the first path whose plist carries the key;
    /// "(not set)" when neither yields a value.
    private func currentPlistValue(item: InspectConfig.ItemConfig, useUserDefaults: Bool) -> String {
        guard let key = item.plistKey else { return "(not set)" }
        if useUserDefaults {
            guard let path = item.paths.first,
                  let domain = Validation.shared.extractDomainFromPath(path) else { return "(not set)" }
            return Validation.shared.getUserDefaultsValue(domain: domain, key: key) ?? "(not set)"
        }
        for path in item.paths {
            if let value = Validation.shared.getPlistValue(at: path, key: key, basePath: uiConfiguration.iconBasePath) {
                return value
            }
        }
        return "(not set)"
    }

    func stopPlistMonitoring(itemId: String) {
        guard let monitor = plistMonitors[itemId] else { return }

        monitor.poll.cancel()
        plistMonitors.removeValue(forKey: itemId)
        writeLog("InspectState: Stopped plist monitoring for '\(itemId)'", logLevel: .info)
    }

    func stopAllPlistMonitors() {
        for (itemId, monitor) in plistMonitors {
            monitor.poll.cancel()
            writeLog("InspectState: Stopped plist monitoring for '\(itemId)'", logLevel: .debug)
        }
        plistMonitors.removeAll()
    }

    /// The monitor's value as a string. For "exists"/"notExists" evaluations the file's presence
    /// decides, read as "Present" / "Not detected"; missing values read "(not set)".
    @MainActor
    func readPlistMonitorValue(monitor: InspectConfig.PlistMonitor, useUserDefaults: Bool) -> String {
        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            // Present: show the actual value when there is one.
            if fileExists {
                if useUserDefaults {
                    return Validation.shared.getUserDefaultsValue(pathOrDomain: monitor.path, key: monitor.key) ?? "Present"
                } else {
                    return Validation.shared.getPlistValue(path: monitor.path, key: monitor.key) ?? "Present"
                }
            } else {
                return "Not detected"
            }
        }

        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "notexists" || evaluation == "not_exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            if fileExists {
                return "Present"
            } else {
                return "Not detected"
            }
        }

        if useUserDefaults {
            return Validation.shared.getUserDefaultsValue(pathOrDomain: monitor.path, key: monitor.key) ?? "(not set)"
        } else {
            return Validation.shared.getPlistValue(path: monitor.path, key: monitor.key) ?? "(not set)"
        }
    }

    /// Evaluates a completion trigger. `condition` is case-insensitive: "equals", "notEquals",
    /// "exists", "notExists", "withinSeconds" (expectedValue in seconds), "match"/"contains",
    /// "greaterThan", "lessThan".
    func evaluateTriggerCondition(condition: String, currentValue: String, expectedValue: String?) -> Bool {
        let normalizedCondition = condition.lowercased()

        switch normalizedCondition {
        case "equals":
            guard let expected = expectedValue else { return false }
            return currentValue == expected

        case "notequals", "not_equals":
            guard let expected = expectedValue else { return false }
            return currentValue != expected

        case "exists":
            return !currentValue.isEmpty && currentValue != "(not set)" && currentValue != "Not detected"

        case "notexists", "not_exists":
            return currentValue == "Not detected"

        case "withinseconds", "within_seconds", "recentseconds", "recent":
            guard let expected = expectedValue, let maxSeconds = Double(expected) else {
                writeLog("InspectState: withinSeconds requires numeric expectedValue (seconds)", logLevel: .error)
                return false
            }

            // Accepts a Unix timestamp, ISO 8601, or common plist date formats.
            let now = Date()
            var parsedDate: Date?

            if let timestamp = Double(currentValue) {
                parsedDate = Date(timeIntervalSince1970: timestamp)
            }

            if parsedDate == nil {
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsedDate = iso8601Formatter.date(from: currentValue)

                if parsedDate == nil {
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    parsedDate = iso8601Formatter.date(from: currentValue)
                }
            }

            if parsedDate == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd HH:mm:ss Z",
                    "yyyy-MM-dd HH:mm:ss",
                    "MMM d, yyyy 'at' h:mm:ss a",
                    "MMM d, yyyy, h:mm:ss a"
                ]

                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: currentValue) {
                        parsedDate = date
                        break
                    }
                }
            }

            guard let date = parsedDate else {
                writeLog("InspectState: withinSeconds could not parse date from '\(currentValue)'", logLevel: .error)
                return false
            }

            let secondsAgo = now.timeIntervalSince(date)
            let isWithin = secondsAgo >= 0 && secondsAgo <= maxSeconds
            writeLog("InspectState: withinSeconds check - date=\(date), secondsAgo=\(secondsAgo), maxSeconds=\(maxSeconds), pass=\(isWithin)", logLevel: .debug)
            return isWithin

        case "match", "contains":
            guard let expected = expectedValue else { return false }
            return currentValue.contains(expected)

        case "greaterthan", "greater_than", ">":
            guard let expected = expectedValue else { return false }
            // Numeric when both parse, else string order.
            if let currentNum = Double(currentValue), let expectedNum = Double(expected) {
                return currentNum > expectedNum
            }
            return currentValue > expected

        case "lessthan", "less_than", "<":
            guard let expected = expectedValue else { return false }
            if let currentNum = Double(currentValue), let expectedNum = Double(expected) {
                return currentNum < expectedNum
            }
            return currentValue < expected

        default:
            writeLog("InspectState: Unknown completion trigger condition '\(condition)' - returning false", logLevel: .error)
            return false
        }
    }

}

// MARK: - Item Status Polling

/// Marks plist-backed items completed or failed on the shared state. The caller owns the timer
/// (Presets 3 and 4 use `InspectConstants.plistPollInterval`).
enum PlistStatusPoller {
    @MainActor
    static func pollItemStatuses(state: InspectState, basePath: String?) {
        for item in state.items {
            guard !state.completedItems.contains(item.id),
                  !state.failedItems.contains(item.id),
                  let plistKey = item.plistKey else { continue }

            for path in item.paths {
                let resolvedPath = resolve(path, basePath: basePath)
                if let dict = PlistHelper.readPlistAsDict(at: resolvedPath),
                   let value = readNestedKey(from: dict, keyPath: plistKey) {
                    // The string form is for logging and the failure-keyword check only; evaluation uses the typed
                    // value.
                    let stringValue = "\(value)"
                    // The shared default: an expectedValue means "equals", a bare key means "exists".
                    guard let op = EvaluationOperator.resolve(evaluation: item.evaluation,
                                                              expectedValue: item.expectedValue) else {
                        writeLog("PlistStatusPoller: unknown evaluation '\(item.evaluation ?? "")' "
                                 + "on \(item.id) — treating as not satisfied", logLevel: .error)
                        continue
                    }
                    if let note = EvaluationOperator.derivationNote(evaluation: item.evaluation,
                                                                    expectedValue: item.expectedValue) {
                        writeLog("PlistStatusPoller: \(item.id): \(note)", logLevel: .debug)
                    }

                    if evaluate(value, expected: item.expectedValue, evaluation: op.rawValue) {
                        state.completedItems.insert(item.id)
                        writeLog("PlistStatusPoller: check passed for \(item.id) — \(plistKey)=\(stringValue)", logLevel: .info)
                    } else if isFailureValue(stringValue) {
                        state.failedItems.insert(item.id)
                        writeLog("PlistStatusPoller: check failed for \(item.id) — \(plistKey)=\(stringValue)", logLevel: .info)
                    }
                }
            }
        }
    }

    /// Resolve a relative path against a base path (absolute paths pass through).
    static func resolve(_ path: String, basePath: String?) -> String {
        if path.hasPrefix("/") { return path }
        guard let base = basePath else { return path }
        return (base as NSString).appendingPathComponent(path)
    }

    /// Reads a dot-notation key path (e.g. "Settings.Network.enabled"). An exact key wins over the dotted
    /// walk, as in `Validation.getPlistValue`.
    static func readNestedKey(from dict: [String: Any], keyPath: String) -> Any? {
        if let direct = dict[keyPath] { return direct }
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = dict
        for key in keys {
            guard let currentDict = current as? [String: Any],
                  let next = currentDict[key] else { return nil }
            current = next
        }
        return current
    }

    /// Evaluates a value with the given operator (case-insensitive via `EvaluationOperator`). Unknown
    /// operators fail closed. Takes the typed value because `contains` depends on string vs list.
    static func evaluate(_ actual: Any, expected: String?, evaluation: String) -> Bool {
        guard let op = EvaluationOperator(authored: evaluation) else { return false }
        // The other operators compare text; `contains` uses the typed value.
        let text = (actual as? String) ?? String(describing: actual)
        // Exhaustive so a new operator must be handled here.
        switch op {
        case .exists:
            return true
        case .boolean:
            return ["true", "1", "yes"].contains(text.lowercased())
        case .equals:
            return text == (expected ?? "")
        case .contains:
            return EvaluationOperator.containsMatch(value: actual, expected: expected)
        case .range:
            guard let parts = expected?.split(separator: "-"), parts.count == 2,
                  let value = Int(text), let lower = Int(parts[0]), let upper = Int(parts[1])
            else { return false }
            return value >= lower && value <= upper
        case .changed:
            // `changed` needs a recorded baseline, which only InspectState+InstallationDetection keeps.
            return false
        case .withinSeconds:
            // Recency needs date parsing, which `Validation` owns; fail closed.
            return false
        }
    }

    /// Whether a plist value indicates explicit failure.
    static func isFailureValue(_ value: String) -> Bool {
        let failureKeywords = ["failed", "error", "disabled", "fail", "false", "no", "blocked", "denied", "outdated", "missing"]
        return failureKeywords.contains(value.lowercased())
    }
}
