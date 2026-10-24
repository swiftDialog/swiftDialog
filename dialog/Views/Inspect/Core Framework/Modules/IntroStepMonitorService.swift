//
// IntroStepMonitorService.swift
//  Dialog
//
//  Plist monitors that update step content blocks live, the cadence engine (`CadenceMonitorService`),
//  `CadenceProgress` and the measured cadence tokens.
//

import SwiftUI
import Combine
import AppKit
import Observation

// MARK: - Dynamic Content State

/// Observable state for one dynamically updated content block. `@Observable`, so views re-render
/// only when a property they read changes.
@Observable
class DynamicContentState {
    var state: String?
    var progress: Double?
    var currentPhase: Int?
    var label: String?
    var content: String?
    var actual: String?
    var passed: Int?
    var total: Int?
    /// nil means no monitor set visibility and the block's own `visible` stands. Optional because it is
    /// merged into the block: a default `true` would un-hide a `visible: false` block.
    var visible: Bool?

    init() {}
}

// MARK: - Completion Trigger Result

/// Result of a completion trigger.
enum CompletionTriggerResult {
    case success(message: String?)
    case failure(message: String?)
}

/// Called when a completion trigger fires, with the step id and result.
typealias CompletionTriggerCallback = (String, CompletionTriggerResult) -> Void

// MARK: - Intro Step Monitor Service

/// Monitors plist files and updates content block state. `@MainActor`: presets hold it in `@State` and
/// call it from views. `init` and `readKeyPath` stay nonisolated; the reader is pure and tested off-actor.
@MainActor
@Observable
class IntroStepMonitorService {
    // State per monitored block index. Mutating these @Observable objects is the change signal.
    var contentStates: [Int: DynamicContentState] = [:]

    private var polls: [Poll] = []
    private var monitors: [InspectConfig.PlistMonitor] = []
    private var refreshInterval: Double = 1.0

    private var completionCallback: CompletionTriggerCallback?
    private var currentStepId: String = ""
    private var triggeredMonitors: Set<Int> = []  // monitor indices whose trigger fired
    private var completionMode: String = "any"    // "any" (default) | "all" — how multiple completionTriggers combine
    private var monitorsWithTriggers: Int = 0  // monitors with a completionTrigger

    // MARK: - Initialization

    nonisolated init() {}

    // No deinit: a released `Poll` stops at its next tick.

    // MARK: - Public Interface

    /// Starts monitoring a step's plist files.
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

        for monitor in monitors where contentStates[monitor.guidanceBlockIndex] == nil {
            contentStates[monitor.guidanceBlockIndex] = DynamicContentState()
        }

        let poll = Poll(every: refreshInterval)
        poll.start { [weak self] in self?.pollPlistValues() }
        polls.append(poll)

        pollPlistValues()

        writeLog("IntroStepMonitorService: Started monitoring \(monitors.count) plist sources", logLevel: .info)
    }

    /// Stops all monitoring.
    func stopMonitoring() {
        for poll in polls {
            poll.cancel()
        }
        polls.removeAll()
        monitors.removeAll()
        completionCallback = nil
        triggeredMonitors.removeAll()
        completionMode = "any"
        monitorsWithTriggers = 0
        writeLog("IntroStepMonitorService: Stopped monitoring", logLevel: .debug)
    }

    /// Dynamic state for a content block index.
    func stateForBlock(_ index: Int) -> DynamicContentState? {
        return contentStates[index]
    }

    // MARK: - Private Implementation

    private func pollPlistValues() {
        for (monitorIndex, monitor) in monitors.enumerated() {
            let rawValue = readPlistValue(path: monitor.path, key: monitor.key, useUserDefaults: monitor.useUserDefaults ?? false)

            let mappedValue: String
            if let value = rawValue, let mapped = mapMonitorValue(value, through: monitor.valueMap) {
                mappedValue = mapped
            } else {
                mappedValue = rawValue ?? ""
            }

            guard let state = contentStates[monitor.guidanceBlockIndex] else { continue }

            switch monitor.targetProperty {
            case "state":
                if state.state != mappedValue {
                    state.state = mappedValue                }
            case "progress":
                let newProgress = Double(mappedValue) ?? 0
                if state.progress != newProgress {
                    state.progress = newProgress                }
            case "currentPhase":
                let newPhase = Int(mappedValue) ?? 1
                if state.currentPhase != newPhase {
                    state.currentPhase = newPhase                }
            case "label":
                if state.label != mappedValue {
                    state.label = mappedValue                }
            case "content":
                if state.content != mappedValue {
                    state.content = mappedValue                }
            case "actual":
                if state.actual != mappedValue {
                    state.actual = mappedValue                }
            case "passed":
                let newPassed = Int(mappedValue) ?? 0
                if state.passed != newPassed {
                    state.passed = newPassed                }
            case "total":
                let newTotal = Int(mappedValue) ?? 0
                if state.total != newTotal {
                    state.total = newTotal                }
            case "visible":
                let newVisible = mappedValue.lowercased() == "true" || mappedValue == "1"
                if state.visible != newVisible {
                    state.visible = newVisible                }
            default:
                writeLog("IntroStepMonitorService: Unknown target property '\(monitor.targetProperty)'", logLevel: .default)
            }

            // Check the completion trigger, if configured and not yet fired.
            if let trigger = monitor.completionTrigger,
               !triggeredMonitors.contains(monitorIndex),
               evaluateTriggerCondition(trigger, currentValue: rawValue, plistPath: monitor.path) {
                // Each monitor fires once.
                triggeredMonitors.insert(monitorIndex)

                // In "all" mode, wait until every monitor with a trigger has fired.
                if completionMode == "all" && triggeredMonitors.count < monitorsWithTriggers {
                    writeLog("IntroStepMonitorService: Trigger fired for monitor \(monitor.guidanceBlockIndex) (\(triggeredMonitors.count)/\(monitorsWithTriggers)), waiting for all", logLevel: .debug)
                } else {
                    let delay = trigger.delay ?? 0
                    let stepId = currentStepId
                    let callback = completionCallback

                    writeLog("IntroStepMonitorService: Completion trigger fired for step '\(stepId)' with result '\(trigger.result)', delay: \(delay)s (mode: \(completionMode))", logLevel: .info)

                    // Fire the callback after the optional delay.
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
    }

    /// Whether a completion trigger's condition is met. `currentValue` is nil when the file or key is
    /// missing; `plistPath` is used for modification-time checks.
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
            guard let current = currentValue, let pattern = expectedValue else { return false }
            return (try? NSRegularExpression(pattern: pattern).firstMatch(in: current, range: NSRange(current.startIndex..., in: current))) != nil
        case "withinseconds", "modifiedwithinseconds":
            // Whether the plist file was modified within N seconds.
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

    /// Reads a value from a plist file or its UserDefaults domain.
    private func readPlistValue(path: String, key: String, useUserDefaults: Bool) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath

        if useUserDefaults {
            let domain = (expandedPath as NSString).deletingPathExtension
            if let defaults = UserDefaults(suiteName: domain) {
                return readKeyPath(from: defaults.dictionaryRepresentation(), keyPath: key)
            }
            return nil
        }

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        guard let plistData = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        return readKeyPath(from: plist, keyPath: key)
    }

    /// Reads a dot-notation key path. Internal so the stringification tests can call it.
    nonisolated func readKeyPath(from dict: [String: Any], keyPath: String) -> String? {
        let components = keyPath.split(separator: ".").map(String.init)

        var current: Any = dict
        for component in components {
            if let dictValue = current as? [String: Any], let next = dictValue[component] {
                current = next
            } else {
                return nil
            }
        }

        // Shared with Validation.formatValueForDisplay: booleans read as "true"/"false", so `valueMap` matches.
        return canonicalScalarString(current)
    }
}

// MARK: - Cadence Monitor Service

/// Gated cadence engine: advances a rotating message as each entry's monitored attribute is satisfied,
/// not on a timer. Attributes are evaluated natively (file/plist/defaults/app/json) or satisfied over
/// IPC with `cadence:`. Uses the shared evaluation operators in `Validation`.
@MainActor
@Observable
class CadenceMonitorService {
    private(set) var currentIndex: Int = 0
    private(set) var isComplete: Bool = false
    /// Measured wall-clock duration of the completed run. Kept across replays.
    private(set) var completedDuration: TimeInterval?
    /// Entries that force-advanced on timeout without being satisfied ({cadenceTimeouts}). Kept across replays.
    private(set) var timedOutCount: Int = 0
    /// Indices that force-advanced on timeout; they never render as done. A later external satisfy removes one.
    private(set) var timedOutIndices: Set<Int> = []
    /// Timed-out indices whose `onTimeout` outcome `marksFailed` (`fail` or `halt`); a subset of
    /// `timedOutIndices` that renders as failed. A later external satisfy removes one.
    private(set) var failedIndices: Set<Int> = []
    /// The entry whose `onTimeout: "halt"` stopped the cadence; nil otherwise. Reset on every fresh
    /// `startWithEntries`. A halt makes Continue live, like completion.
    private(set) var haltedIndex: Int?
    /// True once the last entry, authored `stay: true`, is satisfied. The cadence holds there:
    /// `isComplete` stays false (no auto-advance or completion trigger) and the entry keeps rendering active.
    private(set) var heldByStay: Bool = false
    /// When the hold began, the base for `stayMaxHold`; nil until held. Reset on every fresh `startWithEntries`.
    private(set) var heldSince: Date?
    /// Seconds since `heldSince`, refreshed on every poll tick while held so observers redraw.
    private(set) var heldElapsedSeconds: Double = 0
    /// Per-entry message overrides from `cadence:message:<index>:<text>`, by entry index; nil uses the authored
    /// message.
    private(set) var messageOverride: [Int: String] = [:]

    private(set) var entries: [InspectConfig.CadenceEntry] = []

    /// The active entry, for its icon or image.
    var currentEntry: InspectConfig.CadenceEntry? {
        guard entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    /// The active entry's message; a live override wins over the authored one.
    var currentMessage: String? { messageOverride[currentIndex] ?? currentEntry?.message }

    /// All authored messages in order (live overrides not applied).
    var messages: [String] { entries.map { $0.message } }

    // A released Poll stops at its next tick, so there is no deinit. Not observed by views.
    @ObservationIgnored private var poll: Poll?
    private var interval: Double = 1.0
    private var stepId: String = ""
    private var completion: CompletionTriggerCallback?
    /// When the active entry started; readable so a renderer can show elapsed time. Only this service sets it.
    private(set) var entryStart: Date
    private var satisfiedIpcIds: Set<String> = []
    /// Satisfies that arrived before their cadence step started.
    private var preArrivalIpcIds: Set<String> = []
    /// The last `cadence:goto:` before the step started, so a late-arriving step joins at the current card.
    private var preArrivalGotoIndex: Int?
    /// `cadence:message:` overlays that arrived before the step started, by entry index.
    private var preArrivalMessages: [Int: String] = [:]
    private var didComplete = false
    /// When the current (non-replay) run began; the base for completedDuration.
    @ObservationIgnored private var runStart: Date?
    /// Minimum dwell for entries without their own minDwell, so a replay of satisfied entries is visible.
    private var defaultMinDwell: Double = 0
    /// Replay mode (e.g. returning via Back): every entry counts as satisfied and replays at the dwell pace.
    private var replayMode = false

    /// Base directory for `managedpref` reads, the root-owned location MDM profiles write to. Not
    /// configurable at runtime: redirecting it would let non-root values pass as managed policy.
    /// Tests set this static directly.
    static var managedPreferencesBase = "/Library/Managed Preferences"

    // MARK: Managed-preference value refs

    /// Reads `/Library/Managed Preferences/<domain>.plist` as a dictionary.
    static func managedPrefDict(domain: String) -> [String: Any]? {
        let path = "\(managedPreferencesBase)/\(domain).plist"
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    /// Why a managed-pref cadence read came up empty; `loadEntries` logs it by name.
    enum CadenceRefFailure: Error, Equatable { case plistUnreadable, keyAbsent, notAnArray, entriesUndecodable }

    /// Classifies a managed-pref cadence read without touching /Library, so failure modes are testable.
    static func classifyEntries(dict: [String: Any]?, key: String)
        -> Result<[InspectConfig.CadenceEntry], CadenceRefFailure> {
        guard let dict else { return .failure(.plistUnreadable) }
        guard let array = dict[key] else { return .failure(.keyAbsent) }
        guard JSONSerialization.isValidJSONObject(array),
              let json = try? JSONSerialization.data(withJSONObject: array) else {
            return .failure(.notAnArray)
        }
        guard let entries = try? JSONDecoder().decode([InspectConfig.CadenceEntry].self, from: json) else {
            return .failure(.entriesUndecodable)
        }
        return .success(entries)
    }

    /// Loads cadence entries from a managed-pref ref (an array of entry dicts, decoded via JSON). Failures
    /// are logged by name, and the caller falls back to inline entries. `logging: false` is for
    /// `resolveEntriesForDisplay`, which may run every frame.
    static func loadEntries(from ref: InspectConfig.ManagedValueRef, logging: Bool = true) -> [InspectConfig.CadenceEntry]? {
        let dict = managedPrefDict(domain: ref.domain)
        switch classifyEntries(dict: dict, key: ref.key) {
        case .success(let entries):
            return entries
        case .failure(let failure):
            if logging {
                writeLog("cadence: cadenceRef \(ref.domain)/\(ref.key) yielded no entries — \(failure)", logLevel: .default)
            }
            return nil
        }
    }

    /// A loadable managed preference wins over inline entries; inline entries are the fallback for a
    /// device that has not received its profile yet.
    static func resolveEntries(refEntries: [InspectConfig.CadenceEntry]?, inline: [InspectConfig.CadenceEntry]?)
        -> [InspectConfig.CadenceEntry]? {
        refEntries ?? inline
    }

    /// The entries to lay out before `start(step:)` runs, with the same ref-over-inline order but no
    /// logging (it can run every frame), so the first frame matches the run.
    static func resolveEntriesForDisplay(step: InspectConfig.IntroStep,
                                         entries derived: [InspectConfig.CadenceEntry]? = nil,
                                         include: (InspectConfig.CadenceEntry) -> Bool = { _ in true },
                                         adjust: (InspectConfig.CadenceEntry) -> InspectConfig.CadenceEntry = { $0 })
        -> [InspectConfig.CadenceEntry]? {
        if let derived { return derived.filter(include).map(adjust) }
        let refEntries = step.cadenceRef.flatMap { loadEntries(from: $0, logging: false) }
        return resolveEntries(refEntries: refEntries, inline: step.cadenceEntries)?.filter(include).map(adjust)
    }

    /// A role → hex map from a managed-pref ref. Non-string values are dropped; an absent or
    /// non-dictionary key returns nil and the caller uses the inline palette.
    static func resolvePalette(from ref: InspectConfig.ManagedValueRef, dark: Bool) -> [String: String]? {
        guard let dict = managedPrefDict(domain: ref.domain) else { return nil }
        if dark, let darkKey = ref.darkKey, let value = dict[darkKey] as? [String: Any] {
            return value.compactMapValues { $0 as? String }
        }
        guard let value = dict[ref.key] as? [String: Any] else { return nil }
        return value.compactMapValues { $0 as? String }
    }

    /// A hex colour from a managed-pref ref, using `darkKey` when `dark` is true and it is set.
    static func resolveColor(from ref: InspectConfig.ManagedValueRef, dark: Bool) -> String? {
        guard let dict = managedPrefDict(domain: ref.domain) else { return nil }
        if dark, let darkKey = ref.darkKey, let v = dict[darkKey] as? String { return v }
        return dict[ref.key] as? String
    }

    /// Injectable clock, so dwell and timeout logic is testable without real time.
    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
        self.entryStart = now()
    }


    // MARK: Lifecycle

    /// Poll interval: `cadenceInterval`, then `monitorRefreshInterval`, then 0.6 s (the default dwell).
    nonisolated static func pollInterval(for step: InspectConfig.IntroStep) -> Double {
        step.cadenceInterval ?? step.monitorRefreshInterval ?? 0.6
    }

    /// Starts the cadence for a step and evaluates at once, so already-satisfied entries advance.
    /// `include` filters entries (the host's `showWhen`), applied the same way by `resolveEntriesForDisplay`.
    /// `entries` replaces ref/inline resolution when the host derives the run; `include` and `adjust` still apply.
    func start(step: InspectConfig.IntroStep, replay: Bool = false,
               entries derived: [InspectConfig.CadenceEntry]? = nil,
               include: (InspectConfig.CadenceEntry) -> Bool = { _ in true },
               adjust: (InspectConfig.CadenceEntry) -> InspectConfig.CadenceEntry = { $0 },
               onCompletionTrigger: CompletionTriggerCallback? = nil) {
        // A loadable `cadenceRef` wins over the inline `cadence` array (see `resolveEntries`).
        let cadence: [InspectConfig.CadenceEntry]?
        if let derived {
            cadence = derived.filter(include).map(adjust)
        } else {
            let refEntries = step.cadenceRef.flatMap { Self.loadEntries(from: $0) }
            cadence = Self.resolveEntries(refEntries: refEntries, inline: step.cadenceEntries)?.filter(include).map(adjust)
        }
        guard let cadence, !cadence.isEmpty else { return }
        startWithEntries(
            entries: cadence,
            stepId: step.id,
            interval: Self.pollInterval(for: step),
            defaultMinDwell: step.cadenceMinDwell ?? 0.6,
            replay: replay,
            onCompletion: onCompletionTrigger)
    }

    /// Loads entries, schedules the poll and evaluates once. `defaultMinDwell` is 0 here for tests;
    /// `start(step:)` passes `cadenceMinDwell`, else 0.6.
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
        heldByStay = false
        heldSince = nil
        heldElapsedSeconds = 0
        // A halt belongs to this run; reset it like `isComplete`.
        haltedIndex = nil
        messageOverride.removeAll()
        didComplete = false
        satisfiedIpcIds.removeAll()
        // Satisfies sent before the step appeared wait in a buffer; consume only ids this step owns.
        let owned = Set(entries.map(\.id))
        let seeded = preArrivalIpcIds.intersection(owned)
        if !seeded.isEmpty {
            satisfiedIpcIds.formUnion(seeded)
            preArrivalIpcIds.subtract(seeded)
            writeLog("CadenceMonitorService: seeding \(seeded.count) pre-arrival satisfies for '\(stepId)'", logLevel: .info)
        }
        if let g = preArrivalGotoIndex {
            currentIndex = max(0, min(g, entries.count - 1))
            preArrivalGotoIndex = nil
            writeLog("CadenceMonitorService: seeding pre-arrival goto → card \(currentIndex)", logLevel: .info)
        }
        if !preArrivalMessages.isEmpty {
            messageOverride = preArrivalMessages.merging(messageOverride) { _, live in live }
            preArrivalMessages.removeAll()
        }
        entryStart = now()
        if !replay {
            // A fresh run is measured; a replay keeps the original figures.
            runStart = now()
            completedDuration = nil
            timedOutCount = 0
            timedOutIndices = []
            failedIndices = []
        }

        writeLog("CadenceMonitorService: starting cadence step '\(stepId)' with \(entries.count) entries, interval \(interval)s", logLevel: .info)

        schedulePolling()
        evaluateOnce()
    }

    /// (Re)schedules the poll. Separate so a halted cadence can resume when its entry is satisfied externally.
    private func schedulePolling() {
        poll?.cancel()
        let poll = Poll(every: interval)
        self.poll = poll
        poll.start { [weak self] in _ = self?.evaluateOnce() }
    }

    func stop() {
        poll?.cancel()
        poll = nil
        completion = nil
    }

    /// Whether the poll is running; the cadence advances and times out only while it is.
    var isMonitoring: Bool { poll != nil }

    /// Stops only if this step still owns the monitor. SwiftUI runs the next step's `onAppear` before
    /// this one's `onDisappear`, so a plain stop would cancel the poll the next step just started.
    func stop(ifOwnedBy stepId: String) {
        guard self.stepId == stepId else { return }
        stop()
    }

    // MARK: IPC entry points (`cadence:`)

    /// Marks an entry satisfied (`cadence:satisfy:<id>`). Before the step runs, the id is buffered.
    func satisfyExternally(id: String) {
        guard !entries.isEmpty else {
            preArrivalIpcIds.insert(id)
            writeLog("CadenceMonitorService: buffered pre-arrival satisfy '\(id)'", logLevel: .info)
            return
        }
        satisfiedIpcIds.insert(id)
        if let index = entries.firstIndex(where: { $0.id == id }), timedOutIndices.contains(index) {
            // Satisfied after its timeout: it now counts as done.
            timedOutIndices.remove(index)
            timedOutCount = max(0, timedOutCount - 1)
            failedIndices.remove(index)
            if haltedIndex == index {
                // The halted entry is satisfied: resume polling.
                haltedIndex = nil
                if poll == nil { schedulePolling() }
            }
        }
        writeLog("CadenceMonitorService: external satisfy '\(id)'", logLevel: .info)
        evaluateOnce()
    }

    /// The run's outcome so far, in run order: entries finished (not timed out) and entries failed.
    /// Recorded as `<step>.done` / `<step>.failed` for later steps' `showWhen`.
    var outcome: (done: [String], failed: [String]) {
        Self.outcome(entries: entries.map(\.id), passed: isComplete ? entries.count : currentIndex,
                     timedOut: timedOutIndices, failed: failedIndices)
    }

    nonisolated static func outcome(entries ids: [String], passed: Int, timedOut: Set<Int>, failed: Set<Int>)
        -> (done: [String], failed: [String]) {
        let done = ids.prefix(max(0, passed)).enumerated()
            .filter { !timedOut.contains($0.offset) }.map(\.element)
        let failedIds = ids.enumerated().filter { failed.contains($0.offset) }.map(\.element)
        return (done, failedIds)
    }

    /// Marks an entry failed and moves on (`cadence:fail:<id>`); it renders as "Didn't finish". Entries
    /// not yet reached are ignored, since scripts report in run order.
    func failExternally(id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }), index <= currentIndex else {
            writeLog("CadenceMonitorService: fail '\(id)' ignored (unknown, or not reached yet)", logLevel: .info)
            return
        }
        satisfiedIpcIds.remove(id)
        failedIndices.insert(index)
        if !timedOutIndices.contains(index) {
            timedOutIndices.insert(index)
            timedOutCount += 1
        }
        appendToInteractionLog("cadence:fail:\(id)")
        writeLog("CadenceMonitorService: external fail '\(id)'", logLevel: .info)
        if index == currentIndex && !isComplete { performAdvance() }
    }

    /// Advances past the current entry regardless of its attribute (`cadence:advance`).
    func advance() { performAdvance() }

    /// Overrides an entry's displayed message (`cadence:message:<index>:<text>`), e.g. with the app installing.
    func setMessage(index: Int, text: String) {
        guard index >= 0 else { return }
        guard !entries.isEmpty else {
            preArrivalMessages[index] = text
            return
        }
        messageOverride[index] = text
    }

    /// Jumps to an index (`cadence:goto:<index>`), clamped to range.
    func goto(index: Int) {
        guard !entries.isEmpty else {
            preArrivalGotoIndex = index
            writeLog("CadenceMonitorService: buffered pre-arrival goto:\(index)", logLevel: .info)
            return
        }
        currentIndex = max(0, min(index, entries.count - 1))
        entryStart = now()
    }

    // MARK: Gating

    /// Evaluates the current entry and advances while gates are open, so several satisfied entries pass in
    /// one tick. Returns whether anything advanced.
    @discardableResult
    func evaluateOnce() -> Bool {
        guard !isComplete else { return false }
        // Held by `stay`: only refresh `heldElapsedSeconds`, which `stayMaxHold` reads.
        if heldByStay {
            if let heldSince { heldElapsedSeconds = now().timeIntervalSince(heldSince) }
            return false
        }
        var advanced = false
        for _ in 0..<max(entries.count, 1) {
            guard !isComplete, !heldByStay, entries.indices.contains(currentIndex) else { break }
            let entry = entries[currentIndex]
            let elapsed = now().timeIntervalSince(entryStart)
            let dwell = entry.minDwell ?? defaultMinDwell
            let dwellMet = elapsed >= dwell
            let satisfied = isAttributeSatisfied(entry.attribute, entryId: entry.id)
            let timedOut = entry.timeout.map { elapsed >= $0 } ?? false

            if (satisfied && dwellMet) || timedOut {
                if timedOut && !satisfied {
                    // `onTimeout` per entry; unknown or absent is `.pass`. Every timeout is recorded in
                    // `timedOutIndices`;
                    // failing outcomes also go to `failedIndices`.
                    let outcome = InspectConfig.CadenceTimeoutOutcome.resolve(entry.onTimeout)
                    timedOutCount += 1
                    timedOutIndices.insert(currentIndex)
                    if outcome.marksFailed {
                        failedIndices.insert(currentIndex)
                    }
                    appendToInteractionLog("cadence:timeout:\(entry.id):\(outcome.rawValue)ed")
                    writeLog("CadenceMonitorService: entry '\(entry.id)' timed out — force advancing (onTimeout: \(outcome.rawValue))", logLevel: .info)
                    guard outcome.advances else {
                        // `halt`: stop without advancing and cancel the poll (see `schedulePolling`).
                        haltedIndex = currentIndex
                        poll?.cancel()
                        poll = nil
                        writeLog("CadenceMonitorService: entry '\(entry.id)' halted the cadence (onTimeout: halt)", logLevel: .info)
                        break
                    }
                }
                performAdvance()
                advanced = true
            } else {
                // Not yet advanceable (gate closed or inside minDwell); the next tick re-checks.
                break
            }
        }
        return advanced
    }

    private func performAdvance() {
        guard !isComplete, !heldByStay, !entries.isEmpty else { return }
        if currentIndex >= entries.count - 1 {
            // `stay: true` on the last entry: hold instead of completing, so no completion fires. The poll keeps
            // running for `stayMaxHold`.
            if entries[currentIndex].stay == true {
                heldByStay = true
                heldSince = now()
                heldElapsedSeconds = 0
                writeLog("CadenceMonitorService: entry '\(entries[currentIndex].id)' holds the screen (stay)", logLevel: .info)
                return
            }
            isComplete = true
            poll?.cancel()
            poll = nil
            if !didComplete {
                didComplete = true
                if completedDuration == nil, let runStart {
                    completedDuration = now().timeIntervalSince(runStart)
                }
                writeLog("CadenceMonitorService: cadence '\(stepId)' complete", logLevel: .info)
                completion?(stepId, .success(message: nil))
            }
        } else {
            currentIndex += 1
            entryStart = now()
        }
    }

    // MARK: Attribute evaluation

    /// Whether an entry's bound attribute is currently satisfied.
    func isAttributeSatisfied(_ attribute: InspectConfig.CadenceAttribute, entryId: String) -> Bool {
        // Replay: every condition is already known to be met.
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
                evaluationType: EvaluationOperator
                    .resolve(evaluation: attribute.evaluation,
                             expectedValue: attribute.expectedValue)?.rawValue
                    ?? (attribute.evaluation ?? ""),
                expectedValue: attribute.expectedValue,
                key: key)

        case "defaults":
            guard let path = attribute.path, let key = attribute.key,
                  let value = Validation.shared.getUserDefaultsValue(pathOrDomain: path, key: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: EvaluationOperator
                    .resolve(evaluation: attribute.evaluation,
                             expectedValue: attribute.expectedValue)?.rawValue
                    ?? (attribute.evaluation ?? ""),
                expectedValue: attribute.expectedValue,
                key: key)

        case "managedpref":
            // Managed preference gate. Reads the file directly so the value is seen as soon as the profile lands.
            guard let domain = attribute.domain ?? attribute.path, let key = attribute.key else { return false }
            let base = Self.managedPreferencesBase
            let prefPath = (attribute.scope ?? "device").lowercased() == "user"
                ? "\(base)/\(NSUserName())/\(domain).plist"
                : "\(base)/\(domain).plist"
            guard let value = Validation.shared.getPlistValue(at: prefPath, key: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: EvaluationOperator
                    .resolve(evaluation: attribute.evaluation,
                             expectedValue: attribute.expectedValue)?.rawValue
                    ?? (attribute.evaluation ?? ""),
                expectedValue: attribute.expectedValue,
                key: key)

        case "json":
            guard let path = attribute.path, let key = attribute.key,
                  let value = readJSONValue(path: path, keyPath: key) else { return false }
            return Validation.shared.performSmartEvaluation(
                value: value,
                evaluationType: EvaluationOperator
                    .resolve(evaluation: attribute.evaluation,
                             expectedValue: attribute.expectedValue)?.rawValue
                    ?? (attribute.evaluation ?? ""),
                expectedValue: attribute.expectedValue,
                key: key)

        default:
            writeLog("CadenceMonitorService: unknown attribute type '\(attribute.type ?? "nil")' for entry '\(entryId)'", logLevel: .info)
            return false
        }
    }

    /// Minimal JSON value read by dot-notation key path.
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

// MARK: - CadenceProgress

/// The measured state of a cadence run, derived once for every renderer. `satisfied` is not `position`:
/// timed-out entries move the cursor without being proven, so "N installed" reads `satisfied` and only
/// the active highlight reads `position`.
struct CadenceProgress {
    let entries: [InspectConfig.CadenceEntry]
    /// The cursor; everything before it was passed, proven or timed out.
    let position: Int
    /// The proven count, never larger than `position`; drives every "installed" claim.
    let satisfied: Int
    /// Indices the flow moved past without a completion signal. They render as waiting.
    let timedOut: Set<Int>
    /// The subset of `timedOut` whose outcome `marksFailed` (`fail`/`halt`), rendered as "Didn't finish".
    let failed: Set<Int>
    let isComplete: Bool
    /// Held at the last entry by `stay: true`; `isComplete` is false during a hold.
    let heldByStay: Bool
    /// Seconds since the hold began, for `stayMaxHold`; 0 when not held.
    let heldElapsedSeconds: Double
    /// The script's latest line per entry (`cadence:message:<index>:<text>`); failed rows show it.
    var messages: [Int: String] = [:]

    var total: Int { entries.count }
    /// Entries still to run; 0 once complete, so failed or timed-out entries never hold Continue.
    var pending: Int { isComplete ? 0 : max(0, total - position) }

    /// A row's text: the script's latest line, else the authored message.
    func message(at index: Int) -> String {
        messages[index] ?? (entries.indices.contains(index) ? entries[index].message : "")
    }
    /// Completion from 0 to 1, from the proven count.
    var fraction: Double { total == 0 ? 0 : Double(satisfied) / Double(total) }
    /// The current entry while running, including while held by `stay`.
    var current: InspectConfig.CadenceEntry? {
        guard !isComplete, entries.indices.contains(position) else { return nil }
        return entries[position]
    }

    /// Splits a step-level `totalTimeEstimate` (seconds) evenly over entries without their own `timeEstimate`.
    /// Without a total, or with nothing left of it, the entries are returned unchanged.
    static func entriesFillingEstimates(_ entries: [InspectConfig.CadenceEntry],
                                        total: Double?) -> [InspectConfig.CadenceEntry] {
        guard let total, total > 0 else { return entries }
        let authored = entries.compactMap(\.timeEstimate).reduce(0, +)
        let blanks = entries.filter { $0.timeEstimate == nil }.count
        guard blanks > 0, total > authored else { return entries }
        let share = (total - authored) / Double(blanks)
        return entries.map { entry in
            guard entry.timeEstimate == nil else { return entry }
            var filled = entry
            filled.timeEstimate = share
            return filled
        }
    }

    /// Explicit memberwise initialiser (the custom init suppresses the synthesized one), so tests can build values.
    init(entries: [InspectConfig.CadenceEntry], position: Int, satisfied: Int,
         timedOut: Set<Int>, failed: Set<Int>, isComplete: Bool,
         heldByStay: Bool, heldElapsedSeconds: Double) {
        self.entries = entries
        self.position = position
        self.satisfied = satisfied
        self.timedOut = timedOut
        self.failed = failed
        self.isComplete = isComplete
        self.heldByStay = heldByStay
        self.heldElapsedSeconds = heldElapsedSeconds
    }

    /// Reads the monitor once started; before that, the same ref-over-inline entries `start()` will use, so the
    /// first frame does not reflow.
    @MainActor
    init(monitor: CadenceMonitorService, step: InspectConfig.IntroStep,
         entries derived: [InspectConfig.CadenceEntry]? = nil,
         include: (InspectConfig.CadenceEntry) -> Bool = { _ in true },
         adjust: (InspectConfig.CadenceEntry) -> InspectConfig.CadenceEntry = { $0 }) {
        let resolved = monitor.entries.isEmpty
            ? (CadenceMonitorService.resolveEntriesForDisplay(step: step, entries: derived,
                                                              include: include, adjust: adjust) ?? [])
            : monitor.entries
        let entries = CadenceProgress.entriesFillingEstimates(resolved, total: step.totalTimeEstimate)
        self.entries = entries
        self.isComplete = monitor.isComplete
        let position = monitor.isComplete ? entries.count : monitor.currentIndex
        self.position = position
        self.timedOut = monitor.timedOutIndices
        self.failed = monitor.failedIndices
        self.messages = monitor.messageOverride
        // Count only timed-out indices behind the cursor; at a halt the halted index equals `position`.
        self.satisfied = max(0, position - monitor.timedOutIndices.filter { $0 < position }.count)
        self.heldByStay = monitor.heldByStay
        self.heldElapsedSeconds = monitor.heldElapsedSeconds
    }
}

// MARK: - Measured cadence tokens

/// Resolves measured tokens: `{cadenceCount}` (entries), `{cadenceDuration}` (worded run time, "–" until
/// measured) and `{cadenceTimeouts}`. Used by `GuidanceContentView` for any `CadenceContext` and by the recap.
enum CadenceTokens {

    /// The run's measured duration worded in `languageCode` (system locale when nil); nil when not measured.
    @MainActor
    static func duration(_ monitor: CadenceMonitorService, languageCode: String?) -> String? {
        guard let secs = monitor.completedDuration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = secs >= 60 ? [.minute] : [.second]
        formatter.unitsStyle = .full
        var calendar = Calendar.current
        if let lang = languageCode { calendar.locale = Locale(identifier: lang) }
        formatter.calendar = calendar
        return formatter.string(from: max(secs.rounded(), 1))
    }

    /// Substitutes the tokens in a block's content, stat cells and checklist lines. Blocks without `{cadence`
    /// are returned untouched.
    @MainActor
    static func resolve(_ block: InspectConfig.GuidanceContent,
                        monitor: CadenceMonitorService,
                        languageCode: String?) -> InspectConfig.GuidanceContent {
        let worded = duration(monitor, languageCode: languageCode) ?? "–"
        func swap(_ text: String) -> String {
            guard text.contains("{cadence") else { return text }
            return text
                .replacingOccurrences(of: "{cadenceCount}", with: "\(monitor.entries.count)")
                .replacingOccurrences(of: "{cadenceDuration}", with: worded)
                .replacingOccurrences(of: "{cadenceTimeouts}", with: "\(monitor.timedOutCount)")
        }
        var resolved = block
        if let content = resolved.content { resolved.content = swap(content) }
        if let stats = resolved.stats {
            resolved.stats = stats.map { cell in
                var cell = cell
                cell.value = swap(cell.value)
                cell.label = swap(cell.label)
                return cell
            }
        }
        if let lines = resolved.checklist {
            resolved.checklist = lines.map { line in
                var line = line
                line.text = swap(line.text)
                return line
            }
        }
        return resolved
    }

    /// Whether any token-bearing string in a block mentions a cadence token.
    static func mentioned(in block: InspectConfig.GuidanceContent) -> Bool {
        if block.content?.contains("{cadence") == true { return true }
        if block.stats?.contains(where: { $0.value.contains("{cadence") || $0.label.contains("{cadence") }) == true { return true }
        if block.checklist?.contains(where: { $0.text.contains("{cadence") }) == true { return true }
        return false
    }
}
