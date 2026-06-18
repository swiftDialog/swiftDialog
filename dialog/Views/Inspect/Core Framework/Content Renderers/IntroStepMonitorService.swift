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
import AppKit

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
        for monitor in monitors where contentStates[monitor.guidanceBlockIndex] == nil {
            contentStates[monitor.guidanceBlockIndex] = DynamicContentState()
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

        for monitor in monitors where contentStates[monitor.guidanceBlockIndex] == nil {
            contentStates[monitor.guidanceBlockIndex] = DynamicContentState()
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

        // Convert to string with proper date formatting
        if let stringValue = current as? String {
            return stringValue
        } else if let dateValue = current as? Date {
            // Format dates using DateDisplayService for consistent, user-friendly display
            return DateDisplayService.shared.format(dateValue)
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

// MARK: - Cadence Monitor Service

/// Gated-cadence engine (DEPNotify replacement). Drives a single rotating message
/// forward as each entry's REAL monitored attribute is satisfied ("gated advance"),
/// instead of on a dumb timer. Reuses the shared evaluation operators in `Validation`.
/// Attributes are evaluated natively (file/plist/defaults/app/json) or marked satisfied
/// externally via the `cadence:` IPC verb.
///
/// Lives in this file (rather than its own) because the Xcode project lists sources
/// individually; co-locating with `IntroStepMonitorService` avoids a project.pbxproj edit.
@MainActor
class CadenceMonitorService: ObservableObject {
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isComplete: Bool = false

    private(set) var entries: [InspectConfig.CadenceEntry] = []

    /// The currently active entry (read by the view for the per-entry icon/image).
    var currentEntry: InspectConfig.CadenceEntry? {
        guard entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    /// The message for the currently active entry (read by the rotating-message display).
    var currentMessage: String? { currentEntry?.message }

    /// All messages in order — used to seed the existing `sideMessages` display array.
    var messages: [String] { entries.map { $0.message } }

    private var timer: Timer?
    private var interval: Double = 1.0
    private var stepId: String = ""
    private var completion: CompletionTriggerCallback?
    private var entryStart: Date
    private var satisfiedIpcIds: Set<String> = []
    private var didComplete = false
    /// Default minimum dwell applied to entries without their own minDwell. Gives a smooth
    /// replay (each step shows ~0.6s) when all conditions are already satisfied.
    private var defaultMinDwell: Double = 0
    /// Replay mode: the step was already completed once (e.g. returned to via Back). Every entry
    /// is treated as satisfied so it fast-replays at the dwell pace instead of re-gating/hanging.
    private var replayMode = false

    /// Base directory for `managedpref` reads — FIXED to the root-controlled macOS managed-preferences
    /// location that any MDM writes mobileconfig payloads to (Fleet, Jamf, Intune, Mosyle, …).
    /// Deliberately NOT overridable at runtime (no env var): managed prefs are a root-only trust
    /// boundary, so allowing a non-root caller to redirect the read path would let attacker-controlled
    /// values masquerade as managed policy. Unit tests set this `static var` directly, in-process only.
    /// For demos, install the real profile or `sudo`-drop the plist into the real path.
    static var managedPreferencesBase = "/Library/Managed Preferences"

    // MARK: Managed-preference value refs (per-value domain — read from any MDM profile/tenant)

    /// Read a managed-preference domain's plist dictionary from `/Library/Managed Preferences/<domain>.plist`.
    static func managedPrefDict(domain: String) -> [String: Any]? {
        let path = "\(managedPreferencesBase)/\(domain).plist"
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    /// Load structured cadence entries from a managed-pref ref — the key holds an array of
    /// CadenceEntry dicts (a different tenant/profile can supply the claims). Decoded via JSON.
    static func loadEntries(from ref: InspectConfig.ManagedValueRef) -> [InspectConfig.CadenceEntry]? {
        guard let dict = managedPrefDict(domain: ref.domain), let array = dict[ref.key] else { return nil }
        guard JSONSerialization.isValidJSONObject(array),
              let json = try? JSONSerialization.data(withJSONObject: array),
              let entries = try? JSONDecoder().decode([InspectConfig.CadenceEntry].self, from: json)
        else { return nil }
        return entries
    }

    /// Resolve a colour hex string from a managed-pref ref, choosing the dark-mode variant when
    /// `dark` is true and a `darkKey` is present (e.g. CustomColor / CustomColorDarkMode).
    static func resolveColor(from ref: InspectConfig.ManagedValueRef, dark: Bool) -> String? {
        guard let dict = managedPrefDict(domain: ref.domain) else { return nil }
        if dark, let darkKey = ref.darkKey, let v = dict[darkKey] as? String { return v }
        return dict[ref.key] as? String
    }

    /// Injectable clock so gated-advance/minDwell/timeout are unit-testable without real time.
    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
        self.entryStart = now()
    }

    // deinit is nonisolated; invalidate the timer directly (Timer is not main-actor-isolated).
    deinit { timer?.invalidate() }

    // MARK: Lifecycle

    /// Begin driving the cadence for a step. Fires `evaluateOnce()` immediately so
    /// attributes already satisfied at launch advance without waiting a full interval.
    func start(step: InspectConfig.IntroStep, replay: Bool = false,
               onCompletionTrigger: CompletionTriggerCallback? = nil) {
        // Claims come from the inline `cadence` array, or are read from a managed preference
        // (a different MDM profile/tenant) via `cadenceRef`.
        let cadence = step.cadence ?? step.cadenceRef.flatMap { Self.loadEntries(from: $0) }
        guard let cadence, !cadence.isEmpty else { return }
        startWithEntries(
            entries: cadence,
            stepId: step.id,
            interval: step.cadenceInterval ?? step.monitorRefreshInterval ?? 0.3,
            defaultMinDwell: step.cadenceMinDwell ?? 0.6,
            replay: replay,
            onCompletion: onCompletionTrigger)
    }

    /// Load entries directly (used by `start(step:)` and by unit tests). Schedules the poll
    /// timer and fires one immediate evaluation so already-satisfied entries advance at once.
    /// `defaultMinDwell` defaults to 0 here so unit tests advance immediately; production
    /// `start(step:)` passes 0.6 for a smooth replay.
    func startWithEntries(entries: [InspectConfig.CadenceEntry], stepId: String,
                          interval: Double, defaultMinDwell: Double = 0,
                          replay: Bool = false,
                          onCompletion: CompletionTriggerCallback?) {
        stop()
        guard !entries.isEmpty else { return }
        self.entries = entries
        self.interval = interval
        self.defaultMinDwell = defaultMinDwell
        self.replayMode = replay
        self.stepId = stepId
        self.completion = onCompletion
        currentIndex = 0
        isComplete = false
        didComplete = false
        satisfiedIpcIds.removeAll()
        entryStart = now()

        writeLog("CadenceMonitorService: starting cadence step '\(stepId)' with \(entries.count) entries, interval \(interval)s", logLevel: .info)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Timer is scheduled on the main run loop, so we are already on the main actor.
            MainActor.assumeIsolated { _ = self?.evaluateOnce() }
        }
        evaluateOnce()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        completion = nil
    }

    // MARK: External (IPC) drive — `cadence:` verb entry points

    /// Mark a specific entry satisfied (used for `source:"ipc"` entries via `cadence:satisfy:<id>`).
    func satisfyExternally(id: String) {
        satisfiedIpcIds.insert(id)
        writeLog("CadenceMonitorService: external satisfy '\(id)'", logLevel: .info)
        evaluateOnce()
    }

    /// Advance past the current entry regardless of its attribute (`cadence:advance`).
    func advance() { performAdvance() }

    /// Jump to a specific index (`cadence:goto:<index>`), clamped to range.
    func goto(index: Int) {
        guard !entries.isEmpty else { return }
        currentIndex = max(0, min(index, entries.count - 1))
        entryStart = now()
        objectWillChange.send()
    }

    // MARK: Gating

    /// Evaluate the current entry once and advance if its gate is open. Loops so several
    /// already-satisfied entries collapse in a single tick. Returns true if anything advanced.
    @discardableResult
    func evaluateOnce() -> Bool {
        guard !isComplete else { return false }
        var advanced = false
        for _ in 0..<max(entries.count, 1) {
            guard !isComplete, entries.indices.contains(currentIndex) else { break }
            let entry = entries[currentIndex]
            let elapsed = now().timeIntervalSince(entryStart)
            let dwell = entry.minDwell ?? defaultMinDwell
            let dwellMet = elapsed >= dwell
            let satisfied = isAttributeSatisfied(entry.attribute, entryId: entry.id)
            let timedOut = entry.timeout.map { elapsed >= $0 } ?? false

            if (satisfied && dwellMet) || timedOut {
                if timedOut && !satisfied {
                    writeLog("CadenceMonitorService: entry '\(entry.id)' timed out — force advancing", logLevel: .info)
                }
                performAdvance()
                advanced = true
            } else {
                // Not yet advanceable (gate closed, or satisfied but still inside minDwell).
                // The poll timer re-checks on the next tick and advances once the dwell elapses.
                break
            }
        }
        return advanced
    }

    private func performAdvance() {
        guard !isComplete, !entries.isEmpty else { return }
        if currentIndex >= entries.count - 1 {
            isComplete = true
            timer?.invalidate()
            timer = nil
            if !didComplete {
                didComplete = true
                writeLog("CadenceMonitorService: cadence '\(stepId)' complete", logLevel: .info)
                completion?(stepId, .success(message: nil))
            }
        } else {
            currentIndex += 1
            entryStart = now()
            objectWillChange.send()
        }
    }

    // MARK: Attribute evaluation (reuses Validation operators)

    /// Whether an entry's bound attribute is currently satisfied.
    func isAttributeSatisfied(_ attribute: InspectConfig.CadenceAttribute, entryId: String) -> Bool {
        // Replay: the step already completed once — every condition is known-met, so fast-replay.
        if replayMode { return true }
        if (attribute.source ?? "native").lowercased() == "ipc" {
            return satisfiedIpcIds.contains(entryId)
        }

        switch (attribute.type ?? "file").lowercased() {
        case "file":
            guard let path = attribute.path else { return false }
            return FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)

        case "app":
            if let bundleId = attribute.bundleId, !bundleId.isEmpty {
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
            }
            guard let path = attribute.path else { return false }
            return FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)

        case "plist":
            guard let path = attribute.path, let key = attribute.key,
                  let value = Validation.shared.getPlistValue(at: path, key: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: attribute.evaluation ?? "exists",
                expectedValue: attribute.expectedValue,
                key: key)

        case "defaults":
            guard let path = attribute.path, let key = attribute.key,
                  let value = Validation.shared.getUserDefaultsValue(pathOrDomain: path, key: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: attribute.evaluation ?? "exists",
                expectedValue: attribute.expectedValue,
                key: key)

        case "managedpref":
            // Gate on a mobileconfig managed preference. MDM-agnostic — any MDM (Fleet, Jamf,
            // Intune, Mosyle, …) writes profile payloads to /Library/Managed Preferences. Reads the
            // file directly so it sees the value the moment the profile lands (no CFPreferences cache lag).
            guard let domain = attribute.domain ?? attribute.path, let key = attribute.key else { return false }
            let base = Self.managedPreferencesBase
            let prefPath = (attribute.scope ?? "device").lowercased() == "user"
                ? "\(base)/\(NSUserName())/\(domain).plist"
                : "\(base)/\(domain).plist"
            guard let value = Validation.shared.getPlistValue(at: prefPath, key: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: attribute.evaluation ?? "exists",
                expectedValue: attribute.expectedValue,
                key: key)

        case "json":
            guard let path = attribute.path, let key = attribute.key,
                  let value = readJSONValue(path: path, keyPath: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: attribute.evaluation ?? "exists",
                expectedValue: attribute.expectedValue,
                key: key)

        default:
            writeLog("CadenceMonitorService: unknown attribute type '\(attribute.type ?? "nil")' for entry '\(entryId)'", logLevel: .info)
            return false
        }
    }

    /// Minimal JSON value read by dot-notation key path (file/receipt JSON detection).
    private func readJSONValue(path: String, keyPath: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expanded),
              let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var current: Any? = root
        for component in keyPath.split(separator: ".") {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[String(component)]
        }
        guard let value = current else { return nil }
        if let s = value as? String { return s }
        if let b = value as? Bool { return b ? "true" : "false" }
        return "\(value)"
    }
}
