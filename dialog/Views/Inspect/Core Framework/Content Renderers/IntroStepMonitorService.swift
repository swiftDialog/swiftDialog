//
// IntroStepMonitorService.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Plist monitoring service for dynamic intro step content updates
//  Watches plist files and updates content block state in real-time
//

import SwiftUI
import Combine

// MARK: - Dynamic Content State

/// Observable state for a single content block that can be updated dynamically
class DynamicContentState: ObservableObject {
    @Published var state: String?
    @Published var progress: Double?
    @Published var currentPhase: Int?
    @Published var label: String?
    @Published var content: String?
    @Published var actual: String?
    @Published var passed: Int?
    @Published var total: Int?
    @Published var visible: Bool = true

    init() {}
}

// MARK: - Completion Trigger Result

/// Result type for completion triggers
enum CompletionTriggerResult {
    case success(message: String?)
    case failure(message: String?)
}

/// Callback for when a completion trigger fires
/// Parameters: stepId, result, optional message
typealias CompletionTriggerCallback = (String, CompletionTriggerResult) -> Void

// MARK: - Intro Step Monitor Service

/// Service that monitors plist files and updates content block state
class IntroStepMonitorService: ObservableObject {
    // Published state for each monitored content block (indexed by block index)
    @Published var contentStates: [Int: DynamicContentState] = [:]

    private var timers: [Timer] = []
    private var monitors: [InspectConfig.PlistMonitor] = []
    private var refreshInterval: Double = 1.0

    // Completion trigger support
    private var completionCallback: CompletionTriggerCallback?
    private var currentStepId: String = ""
    private var triggeredMonitors: Set<Int> = []  // Track which monitors have already triggered (by guidanceBlockIndex)
    private var completionMode: String = "any"    // "any" (default) | "all" — how multiple completionTriggers combine
    private var monitorsWithTriggers: Int = 0     // Count of monitors that have a completionTrigger configured

    // MARK: - Initialization

    init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Interface

    /// Start monitoring plist files for a step
    /// - Parameters:
    ///   - step: The intro step configuration
    ///   - onCompletionTrigger: Optional callback when a completion trigger fires
    func startMonitoring(step: InspectConfig.IntroStep, onCompletionTrigger: CompletionTriggerCallback? = nil) {
        stopMonitoring()

        writeLog("IntroStepMonitorService: startMonitoring called for step '\(step.id)', plistMonitors count: \(step.plistMonitors?.count ?? 0)", logLevel: .debug)

        guard let plistMonitors = step.plistMonitors, !plistMonitors.isEmpty else {
            writeLog("IntroStepMonitorService: No plistMonitors configured for step '\(step.id)'", logLevel: .debug)
            return
        }

        monitors = plistMonitors
        refreshInterval = step.monitorRefreshInterval ?? 1.0
        completionCallback = onCompletionTrigger
        currentStepId = step.id
        triggeredMonitors.removeAll()
        completionMode = step.completionMode ?? "any"
        monitorsWithTriggers = plistMonitors.filter { $0.completionTrigger != nil }.count

        // Initialize content states for each monitored block
        for monitor in monitors {
            if contentStates[monitor.guidanceBlockIndex] == nil {
                contentStates[monitor.guidanceBlockIndex] = DynamicContentState()
            }
        }

        // Start polling timer
        let timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.pollPlistValues()
        }
        timers.append(timer)

        // Perform initial poll
        pollPlistValues()

        writeLog("IntroStepMonitorService: Started monitoring \(monitors.count) plist sources", logLevel: .info)
    }

    /// Start monitoring plist files for an item (Preset6 item-based model)
    /// - Parameters:
    ///   - item: The item configuration
    ///   - onCompletionTrigger: Optional callback when a completion trigger fires
    func startMonitoring(item: InspectConfig.ItemConfig, onCompletionTrigger: CompletionTriggerCallback? = nil) {
        stopMonitoring()

        guard let plistMonitors = item.plistMonitors, !plistMonitors.isEmpty else {
            writeLog("IntroStepMonitorService: No plistMonitors configured for item '\(item.id)'", logLevel: .debug)
            return
        }

        monitors = plistMonitors
        refreshInterval = 1.0  // Default refresh interval for items
        completionCallback = onCompletionTrigger
        currentStepId = item.id
        triggeredMonitors.removeAll()
        completionMode = item.completionMode ?? "any"
        monitorsWithTriggers = plistMonitors.filter { $0.completionTrigger != nil }.count

        for monitor in monitors {
            if contentStates[monitor.guidanceBlockIndex] == nil {
                contentStates[monitor.guidanceBlockIndex] = DynamicContentState()
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.pollPlistValues()
        }
        timers.append(timer)
        pollPlistValues()

        writeLog("IntroStepMonitorService: Started monitoring \(monitors.count) plist sources for item '\(item.id)'", logLevel: .info)
    }

    /// Stop all monitoring
    func stopMonitoring() {
        for timer in timers {
            timer.invalidate()
        }
        timers.removeAll()
        monitors.removeAll()
        completionCallback = nil
        triggeredMonitors.removeAll()
        completionMode = "any"
        monitorsWithTriggers = 0
        writeLog("IntroStepMonitorService: Stopped monitoring", logLevel: .debug)
    }

    /// Get dynamic state for a content block index
    func stateForBlock(_ index: Int) -> DynamicContentState? {
        return contentStates[index]
    }

    // MARK: - Private Implementation

    private func pollPlistValues() {
        var hasUpdates = false

        for monitor in monitors {
            let rawValue = readPlistValue(path: monitor.path, key: monitor.key, useUserDefaults: monitor.useUserDefaults ?? false)

            // Apply value mapping if configured
            let mappedValue: String
            if let valueMap = monitor.valueMap, let value = rawValue, let mapped = valueMap[value] {
                mappedValue = mapped
            } else {
                mappedValue = rawValue ?? ""
            }

            // Update the appropriate property on the content state
            guard let state = contentStates[monitor.guidanceBlockIndex] else { continue }

            switch monitor.targetProperty {
            case "state":
                if state.state != mappedValue {
                    state.state = mappedValue
                    hasUpdates = true
                }
            case "progress":
                let newProgress = Double(mappedValue) ?? 0
                if state.progress != newProgress {
                    state.progress = newProgress
                    hasUpdates = true
                }
            case "currentPhase":
                let newPhase = Int(mappedValue) ?? 1
                if state.currentPhase != newPhase {
                    state.currentPhase = newPhase
                    hasUpdates = true
                }
            case "label":
                if state.label != mappedValue {
                    state.label = mappedValue
                    hasUpdates = true
                }
            case "content":
                if state.content != mappedValue {
                    state.content = mappedValue
                    hasUpdates = true
                }
            case "actual":
                if state.actual != mappedValue {
                    state.actual = mappedValue
                    hasUpdates = true
                }
            case "passed":
                let newPassed = Int(mappedValue) ?? 0
                if state.passed != newPassed {
                    state.passed = newPassed
                    hasUpdates = true
                }
            case "total":
                let newTotal = Int(mappedValue) ?? 0
                if state.total != newTotal {
                    state.total = newTotal
                    hasUpdates = true
                }
            case "visible":
                let newVisible = mappedValue.lowercased() == "true" || mappedValue == "1"
                if state.visible != newVisible {
                    state.visible = newVisible
                    hasUpdates = true
                }
            default:
                writeLog("IntroStepMonitorService: Unknown target property '\(monitor.targetProperty)'", logLevel: .default)
            }

            // Check completion trigger if configured and not already triggered
            if let trigger = monitor.completionTrigger,
               !triggeredMonitors.contains(monitor.guidanceBlockIndex),
               evaluateTriggerCondition(trigger, currentValue: rawValue, plistPath: monitor.path) {
                // Mark this monitor as triggered (only fires once)
                triggeredMonitors.insert(monitor.guidanceBlockIndex)

                // In "all" mode, wait until every monitor with a trigger has fired
                if completionMode == "all" && triggeredMonitors.count < monitorsWithTriggers {
                    writeLog("IntroStepMonitorService: Trigger fired for monitor \(monitor.guidanceBlockIndex) (\(triggeredMonitors.count)/\(monitorsWithTriggers)), waiting for all", logLevel: .debug)
                } else {
                    let delay = trigger.delay ?? 0
                    let stepId = currentStepId
                    let callback = completionCallback

                    writeLog("IntroStepMonitorService: Completion trigger fired for step '\(stepId)' with result '\(trigger.result)', delay: \(delay)s (mode: \(completionMode))", logLevel: .info)

                    // Fire callback after optional delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let result: CompletionTriggerResult
                        if trigger.result.lowercased() == "success" {
                            result = .success(message: trigger.message)
                        } else {
                            result = .failure(message: trigger.message)
                        }
                        callback?(stepId, result)
                    }
                }
            }
        }

        // Trigger UI refresh if any values changed
        if hasUpdates {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    /// Evaluate if a completion trigger condition is met
    /// - Parameters:
    ///   - trigger: The completion trigger configuration
    ///   - currentValue: The current plist value (nil if file/key doesn't exist)
    ///   - plistPath: The path to the plist file (for file modification time checks)
    /// - Returns: true if the condition is met
    private func evaluateTriggerCondition(_ trigger: InspectConfig.CompletionTrigger, currentValue: String?, plistPath: String) -> Bool {
        let condition = trigger.condition.lowercased()
        let expectedValue = trigger.value

        switch condition {
        case "equals":
            return currentValue == expectedValue
        case "notequals":
            return currentValue != expectedValue
        case "exists":
            return currentValue != nil && !currentValue!.isEmpty
        case "notexists":
            return currentValue == nil || currentValue!.isEmpty
        case "contains":
            guard let current = currentValue, let expected = expectedValue else { return false }
            return current.contains(expected)
        case "greaterthan":
            guard let current = currentValue, let expected = expectedValue,
                  let currentNum = Double(current), let expectedNum = Double(expected) else { return false }
            return currentNum > expectedNum
        case "lessthan":
            guard let current = currentValue, let expected = expectedValue,
                  let currentNum = Double(current), let expectedNum = Double(expected) else { return false }
            return currentNum < expectedNum
        case "match":
            // Regex match
            guard let current = currentValue, let pattern = expectedValue else { return false }
            return (try? NSRegularExpression(pattern: pattern).firstMatch(in: current, range: NSRange(current.startIndex..., in: current))) != nil
        case "withinseconds", "modifiedwithinseconds":
            // Check if plist file was modified within N seconds
            guard let secondsStr = expectedValue,
                  let seconds = Double(secondsStr) else { return false }
            let expandedPath = (plistPath as NSString).expandingTildeInPath
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                  let modDate = attrs[.modificationDate] as? Date else { return false }
            return Date().timeIntervalSince(modDate) <= seconds
        default:
            writeLog("IntroStepMonitorService: Unknown trigger condition '\(condition)'", logLevel: .default)
            return false
        }
    }

    /// Read a value from a plist file
    private func readPlistValue(path: String, key: String, useUserDefaults: Bool) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath

        if useUserDefaults {
            // Read from UserDefaults domain
            let domain = (expandedPath as NSString).deletingPathExtension
            if let defaults = UserDefaults(suiteName: domain) {
                return readKeyPath(from: defaults.dictionaryRepresentation(), keyPath: key)
            }
            return nil
        }

        // Read from plist file
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        guard let plistData = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        return readKeyPath(from: plist, keyPath: key)
    }

    /// Read a value using dot-notation key path
    private func readKeyPath(from dict: [String: Any], keyPath: String) -> String? {
        let components = keyPath.split(separator: ".").map(String.init)

        var current: Any = dict
        for component in components {
            if let dictValue = current as? [String: Any], let next = dictValue[component] {
                current = next
            } else {
                return nil
            }
        }

        // Convert to string
        if let stringValue = current as? String {
            return stringValue
        } else if let intValue = current as? Int {
            return String(intValue)
        } else if let doubleValue = current as? Double {
            return String(doubleValue)
        } else if let boolValue = current as? Bool {
            return boolValue ? "true" : "false"
        }

        return nil
    }
}

// MARK: - Dynamic Content Block Wrapper

/// A view wrapper that applies dynamic state to content blocks
struct DynamicContentBlockWrapper<Content: View>: View {
    let blockIndex: Int
    @ObservedObject var monitorService: IntroStepMonitorService
    let content: (DynamicContentState?) -> Content

    var body: some View {
        let state = monitorService.stateForBlock(blockIndex)

        if state?.visible ?? true {
            content(state)
        }
    }
}
