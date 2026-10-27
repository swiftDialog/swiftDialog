//
//  MonitoringModule.swift
//  dialog
//
//  `UnifiedMonitoringService`: install detection, plist/JSON monitoring, log monitor status and
//  receipt census for Preset 5 (one @StateObject per preset).
//

import Foundation
import SwiftUI
import Combine

// MARK: - Item Status Enum

/// Lifecycle predicates on the shared `StepStatus` vocabulary.
extension StepStatus {
    /// Work is happening right now.
    var isActive: Bool { self == .active }

    /// The state is decided and will not change on its own.
    var isTerminal: Bool { self == .completed || self == .failed || self == .skipped }
}

// MARK: - Validation Result

/// Result of validating an item against expected values
struct MonitoringValidationResult: Equatable {
    let isValid: Bool
    let actualValue: String?
    let expectedValue: String?
    let evaluationType: String?
    let message: String?

    init(
        isValid: Bool,
        actualValue: String? = nil,
        expectedValue: String? = nil,
        evaluationType: String? = nil,
        message: String? = nil
    ) {
        self.isValid = isValid
        self.actualValue = actualValue
        self.expectedValue = expectedValue
        self.evaluationType = evaluationType
        self.message = message
    }

    static let unknown = MonitoringValidationResult(isValid: false, message: "Not validated")
}

// MARK: - Unified Monitoring Service

/// What a detection pass may do to a status it did not produce. Pure, so tests can check it.
/// A completed item may fall back only in catalogue mode (`reflectsCurrentState`); install runs latch.
/// Absence never overwrites a reported `.failed` (or `.skipped`): only progress (`satisfied > 0`) or
/// the app itself (`done`) can, so an orchestrator's `failure:` stays visible. Used by the requirement
/// branch only.
enum CatalogueStatusRule {

    /// The status to publish, or nil to leave the item unchanged.
    static func resolve(previous: StepStatus?,
                        done: Bool,
                        satisfied: Int,
                        reflectsCurrentState: Bool) -> StepStatus? {
        if done { return previous == .completed ? nil : .completed }

        // The one-way completion latch, released only for a catalogue.
        if previous == .completed && !reflectsCurrentState { return nil }

        // Detection sees only presence, so it cannot refute a failure or a skip decision.
        if (previous == .failed || previous == .skipped) && satisfied == 0 { return nil }

        let candidate: StepStatus = satisfied > 0 ? .active : .pending
        return previous == candidate ? nil : candidate
    }
}

/// Coordinates install detection, plist and JSON monitoring, and log monitor statuses for a set of items.
/// `@MainActor`: it is UI state on one `@StateObject` in `Preset5View`, its polls are main-actor `Poll`s
/// and its Combine feed receives on main, so `Task { @MainActor … }` only defers, never changes thread.
@MainActor
final class UnifiedMonitoringService: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var itemStatuses: [String: StepStatus] = [:]
    /// When an installed item disappeared (`[id: Date]`), for the removal notice. Separate from
    /// `InspectState.removedItems`, which tracks the config-level `items[]`; this tracks the step-authored
    /// items a Preset 5 flow passes in, and Preset 5 screens read removals here.
    @Published public private(set) var removedItems: [String: Date] = [:]
    @Published public private(set) var validationResults: [String: MonitoringValidationResult] = [:]
    @Published public private(set) var progressValues: [String: Double] = [:]
    @Published public private(set) var statusMessages: [String: String] = [:]

    // MARK: - Private Properties

    private var items: [any MonitoredItem] = []
    private var plistMonitorTasks: [String: PlistMonitorTask] = [:]
    private var jsonMonitorTasks: [String: JsonMonitorTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let fileSystemCache = FileSystemCache()
    private var statusCheck: Poll?
    private var cachePaths: [String] = []
    private var cacheExtensions: [String] = [".download", ".pkg", ".dmg"]
    private var receiptsBasePath: String = "/var/db/receipts"
    /// Status poll interval, from the config's `scanInterval`.
    private(set) var statusInterval: TimeInterval = InspectConstants.robustUpdateInterval
    /// `receiptCensus`: the receipts present at start; nil when the census is off.
    private var receiptBaseline: Set<String>?
    /// Rows the census completed. A one-way latch the other engines respect, so a row does not flap.
    private var censusCompleted: Set<String> = []
    private var lastCensusFiles = -1
    private var plistBaselines: [String: String?] = [:]  // Change detection baselines
    private var plistBaselinesInitialized: Set<String> = []

    // MARK: - Plist Monitor Task

    private struct PlistMonitorTask {
        let poll: Poll
        let itemId: String
        let plistPath: String
        let plistKey: String
        let expectedValue: String?
        let evaluation: String?
        var lastValue: String?
    }

    // MARK: - JSON Monitor Task

    private struct JsonMonitorTask {
        let poll: Poll
        let itemId: String
        let jsonPath: String
        let jsonKey: String
        let expectedValue: String?
        var lastValue: String?
    }

    // MARK: - Initialization

    init() {
        LogMonitorService.shared.$latestStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                // `.receive(on: .main)` guarantees isolation; the closure's type cannot express it.
                MainActor.assumeIsolated { self?.handleLogMonitorStatuses(statuses) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Catalogue mode: report current state instead of latching completion, so a removed app reads as missing.
    private var reflectsCurrentState = false

    /// The step id that owns the current session. SwiftUI runs the next view's `onAppear` before the
    /// previous view's `onDisappear`, so stops are checked against this owner. nil means unowned:
    /// `stopMonitoring()` still stops it, `stopMonitoring(owner:)` never does.
    private(set) var monitoringOwner: String?

    /// Starts monitoring the given items.
    /// - Parameters:
    ///   - items: Items to monitor
    ///   - cachePaths: Optional cache paths for download detection
    ///   - receiptsBasePath: Base directory for `receipt` requirements (overridable for tests)
    func startMonitoring(items: [any MonitoredItem], cachePaths: [String] = [], cacheExtensions: [String]? = nil,
                         receiptsBasePath: String? = nil, reflectsCurrentState: Bool = false,
                         receiptCensus: Bool = false, scanInterval: Int? = nil,
                         owner: String? = nil) {
        self.statusInterval = InspectConstants.scanInterval(scanInterval)
        self.monitoringOwner = owner
        self.items = items
        self.cachePaths = cachePaths
        self.cacheExtensions = cacheExtensions ?? [".download", ".pkg", ".dmg"]
        self.receiptsBasePath = receiptsBasePath ?? "/var/db/receipts"
        self.reflectsCurrentState = reflectsCurrentState
        // The receipt baseline is taken once here; only receipts that appear later count.
        self.receiptBaseline = receiptCensus ? ReceiptCensus.identifiers(in: self.receiptsBasePath) : nil
        self.censusCompleted = []
        if let baseline = receiptBaseline {
            DetectionLog.trace("receipt census ON: \(baseline.count) receipts at baseline in \(self.receiptsBasePath)")
        }

        writeLog("UnifiedMonitoringService: Starting monitoring for \(items.count) items", logLevel: .info)

        for item in items where itemStatuses[item.id] == nil {
            itemStatuses[item.id] = .pending
        }

        LogMonitorService.shared.setItems(items)

        for item in items {
            startPlistMonitoringIfNeeded(for: item)
            startJsonMonitoringIfNeeded(for: item)
        }

        startStatusCheckTimer()

        performStatusCheck()
    }

    /// Ownership-checked stop, for screens: a no-op unless `owner` still holds the session. Returns whether it
    /// stopped, so the caller gates its own teardown (the shared log monitor) on the same answer.
    @discardableResult
    func stopMonitoring(owner: String) -> Bool {
        guard monitoringOwner == owner else {
            writeLog("UnifiedMonitoringService: Ignoring stop from '\(owner)' — the session belongs to '\(monitoringOwner ?? "no one")'",
                     logLevel: .debug)
            return false
        }
        stopMonitoring()
        return true
    }

    /// Stops all monitoring unconditionally, for shutdown and tests. Screens use `stopMonitoring(owner:)`.
    func stopMonitoring() {
        writeLog("UnifiedMonitoringService: Stopping all monitoring", logLevel: .info)
        monitoringOwner = nil

        statusCheck?.cancel()
        statusCheck = nil

        for (_, task) in plistMonitorTasks {
            task.poll.cancel()
        }
        plistMonitorTasks.removeAll()

        for (_, task) in jsonMonitorTasks {
            task.poll.cancel()
        }
        jsonMonitorTasks.removeAll()

        cancellables.removeAll()
    }

    /// Runs a status check now.
    func forceStatusCheck() {
        performStatusCheck()
    }

    /// Validates one item.
    func validateItem(_ item: any MonitoredItem) -> MonitoringValidationResult {
        guard let plistKey = item.plistKey else {
            return .unknown
        }

        let plistPath = item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? ""
        guard !plistPath.isEmpty else {
            return MonitoringValidationResult(isValid: false, message: "No plist path configured")
        }

        return validatePlistValue(
            at: plistPath,
            key: plistKey,
            expectedValue: item.expectedValue,
            evaluation: item.evaluation
        )
    }

    /// Marks an item completed (external trigger).
    func markCompleted(_ itemId: String) {
        Task { @MainActor [weak self] in
            self?.itemStatuses[itemId] = .completed
            writeLog("UnifiedMonitoringService: Item '\(itemId)' marked completed (external)", logLevel: .info)
        }
    }

    /// Marks an item failed (external trigger).
    func markFailed(_ itemId: String, reason: String?) {
        Task { @MainActor [weak self] in
            self?.statusMessages[itemId] = reason
            self?.itemStatuses[itemId] = .failed
            writeLog("UnifiedMonitoringService: Item '\(itemId)' marked failed (external): \(reason ?? "unknown")", logLevel: .info)
        }
    }

    /// Sets an item's status from an external command.
    func setItemStatus(_ itemId: String, status: StepStatus) {
        Task { @MainActor [weak self] in
            self?.itemStatuses[itemId] = status
            writeLog("UnifiedMonitoringService: Item '\(itemId)' set to \(status.rawValue) (trigger)", logLevel: .info)
        }
    }

    /// Sets a custom status message for an item.
    func setStatusMessage(_ itemId: String, message: String) {
        Task { @MainActor [weak self] in
            self?.statusMessages[itemId] = message
        }
    }

    /// Sets only the percent (0–100) for `progress:<id>`; the status stays as the last status command set it.
    func setProgress(_ itemId: String, percent: Double) {
        Task { @MainActor [weak self] in
            self?.progressValues[itemId] = min(100, max(0, percent))
        }
    }

    /// Updates an item's progress.
    func updateProgress(_ itemId: String, progress: Double, message: String? = nil) {
        Task { @MainActor [weak self] in
            self?.progressValues[itemId] = progress
            if let message = message {
                self?.statusMessages[itemId] = message
            }
            self?.itemStatuses[itemId] = .active
        }
    }

    // MARK: - Private Methods

    /// Status, plist and JSON polls are `Poll`s (Clocks.swift), main-actor by type.
    private func startStatusCheckTimer() {
        statusCheck?.cancel()
        let poll = Poll(every: statusInterval)
        statusCheck = poll
        poll.start { [weak self] in self?.performStatusCheck() }
    }

    private func performStatusCheck() {
        pruneRemovalNotices()
        // Completions decided this pass but not yet published; the census must count them.
        var completedThisPass = Set<String>()
        for item in items {
            // A census completion is final for this run.
            if censusCompleted.contains(item.id) { continue }
            // Requirement-based card: the group verdict replaces the path/plist checks, and partial satisfaction
            // shows as installing.
            if let group = RequirementEvaluator.evaluate(item, receiptsBasePath: receiptsBasePath) {
                let previous = itemStatuses[item.id]
                // `CatalogueStatusRule` decides what this pass may publish.
                let verdict = CatalogueStatusRule.resolve(previous: previous,
                                                          done: group.done,
                                                          satisfied: group.satisfied,
                                                          reflectsCurrentState: reflectsCurrentState)
                if group.done {
                    if verdict == .completed {
                        // Log the transition with its evidence (`resolve` returns nil for a row already completed).
                        DetectionLog.note(itemId: item.id,
                                          from: previous == .active ? "installing" : "pending",
                                          to: "completed", by: .requirements)
                        let satisfied = (item.requirements ?? [])
                            .filter { RequirementEvaluator.isSatisfied($0, receiptsBasePath: receiptsBasePath) }
                            .map(DetectionLog.evidence)
                        DetectionLog.trace("  \(item.id) satisfied by: " + satisfied.joined(separator: ", "))
                        completedThisPass.insert(item.id)
                        Task { @MainActor [weak self] in
                            self?.itemStatuses[item.id] = .completed
                            writeLog("UnifiedMonitoringService: Item '\(item.displayName)' requirements satisfied (\(group.satisfied)/\(group.total))", logLevel: .info)
                        }
                    }
                } else {
                    if verdict == .active {
                        DetectionLog.note(itemId: item.id, from: "pending", to: "installing", by: .requirements)
                        DetectionLog.trace("  \(item.id) partial \(group.satisfied)/\(group.total)")
                    }
                    // Requirement progress goes to the progress and message stores; the state is active.
                    if group.satisfied > 0 {
                        // Progress is in percent here (CircularProgressIndicator trims at progress/100).
                        progressValues[item.id] = Double(group.satisfied) / Double(group.total) * 100
                        statusMessages[item.id] = "\(group.satisfied) of \(group.total)"
                    }
                    if let status = verdict {
                        Task { @MainActor [weak self] in
                            self?.itemStatuses[item.id] = status
                        }
                    }
                }
                continue
            }

            // Items without paths are managed externally.
            guard !item.paths.isEmpty else { continue }

            let wasCompleted = itemStatuses[item.id] == .completed

            let fileExists = item.paths.first { path in
                FileManager.default.fileExists(atPath: path)
            } != nil

            // With plist validation (plistKey + evaluation), the value must pass, not just the file exist.
            let isInstalled: Bool
            if fileExists, let plistKey = item.plistKey, !plistKey.isEmpty, item.evaluation != nil {
                if item.evaluation == "changed" {
                    // Change detection: compare the current value to the baseline.
                    let plistPath = item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? ""
                    let currentValue: String?
                    if item.useUserDefaults == true {
                        let expandedPath = (plistPath as NSString).expandingTildeInPath
                        let domain = expandedPath.contains("/") ?
                            ((expandedPath as NSString).lastPathComponent as NSString).deletingPathExtension :
                            expandedPath
                        if domain == ".GlobalPreferences" {
                            currentValue = UserDefaults.standard.string(forKey: plistKey)
                        } else {
                            currentValue = UserDefaults(suiteName: domain)?.string(forKey: plistKey)
                        }
                    } else if let plist = PlistHelper.readPlist(at: plistPath) {
                        currentValue = plist.value(forKeyPath: plistKey).map { String(describing: $0) }
                    } else {
                        currentValue = nil
                    }
                    if !plistBaselinesInitialized.contains(item.id) {
                        plistBaselines[item.id] = currentValue
                        plistBaselinesInitialized.insert(item.id)
                        writeLog("MonitoringModule: Plist baseline for \(item.id): \(currentValue ?? "nil")", logLevel: .debug)
                        isInstalled = false
                    } else {
                        let baseline = plistBaselines[item.id] ?? nil
                        let changed = (baseline != currentValue)
                        if changed {
                            writeLog("MonitoringModule: Plist value changed for \(item.id): \(baseline ?? "nil") → \(currentValue ?? "nil")", logLevel: .info)
                        }
                        isInstalled = changed
                    }
                } else {
                    let result = validatePlistValue(
                        at: item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? "",
                        key: plistKey,
                        expectedValue: item.expectedValue,
                        evaluation: item.evaluation
                    )
                    isInstalled = result.isValid
                    Task { @MainActor [weak self] in
                        self?.validationResults[item.id] = result
                    }
                }
            } else {
                isInstalled = fileExists
            }

            // A reinstall clears the removal notice, whether or not this pass also changes the status.
            if isInstalled, removedItems[item.id] != nil {
                Task { @MainActor [weak self] in
                    self?.removedItems.removeValue(forKey: item.id)
                }
            }

            if isInstalled && !wasCompleted {
                completedThisPass.insert(item.id)
                Task { @MainActor [weak self] in
                    self?.itemStatuses[item.id] = .completed
                    writeLog("UnifiedMonitoringService: Item '\(item.displayName)' detected as installed", logLevel: .info)
                }
            } else if !isInstalled && wasCompleted {
                Task { @MainActor [weak self] in
                    // The state stays pending; the date records that it was removed rather than never installed.
                    self?.itemStatuses[item.id] = .pending
                    self?.removedItems[item.id] = Date()
                    writeLog("UnifiedMonitoringService: Item '\(item.displayName)' no longer installed — recorded a removal notice", logLevel: .info)
                }
            } else if !isInstalled {
                let isDownloading = checkIfDownloading(item)
                if isDownloading {
                    Task { @MainActor [weak self] in
                        self?.itemStatuses[item.id] = .active
                    }
                }
            }
        }
        // The receipt census runs after every row; rows already completed by other means are counted first
        // so a receipt is never counted twice.
        if let baseline = receiptBaseline {
            let isDone = { (id: String) in
                self.itemStatuses[id] == .completed || self.censusCompleted.contains(id) || completedThisPass.contains(id)
            }
            let now = ReceiptCensus.receipts(in: receiptsBasePath)
            let done = ReceiptCensus.newInstalls(now: now, baseline: baseline, total: items.count)
            let already = items.filter { isDone($0.id) }.count
            // Log the counts whenever they change, so a field log can be read without the receipts directory.
            let files = now.filter { !baseline.contains($0.id) }.count
            if files != lastCensusFiles {
                lastCensusFiles = files
                let owned = items.filter { isDone($0.id) }
                    .map { "\($0.id)=\(itemStatuses[$0.id]?.rawValue ?? "nil")\(censusCompleted.contains($0.id) ? "(census)" : "")" }
                DetectionLog.trace("  census sees \(files) new receipt file(s) = \(done) install(s); \(already) row(s) already done by other engines: \(owned.joined(separator: " "))")
            }
            var toMark = done - already
            if toMark > 0 {
                for item in items where toMark > 0 && !isDone(item.id)
                        && itemStatuses[item.id] != .failed && itemStatuses[item.id] != .skipped {
                    let previous = itemStatuses[item.id]
                    censusCompleted.insert(item.id)
                    Task { @MainActor [weak self] in self?.itemStatuses[item.id] = .completed }
                    DetectionLog.note(itemId: item.id, from: previous == .active ? "installing" : "pending",
                                      to: "completed", by: .census)
                    toMark -= 1
                }
                DetectionLog.trace("  census: \(files) new receipt file(s) in \(done) install(s) since baseline → \(done) of \(items.count) rows")
            }
        }

    }

    /// Removes expired removal notices using `AppInspector.expiredNotices` and the shared
    /// `removalNoticeDwell`. `now` is for tests.
    func pruneRemovalNotices(now: Date = Date()) {
        let expired = AppInspector.expiredNotices(removedItems, now: now)
        guard !expired.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for id in expired { self.removedItems.removeValue(forKey: id) }
        }    }

    private func checkIfDownloading(_ item: any MonitoredItem) -> Bool {
        for cachePath in cachePaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: cachePath) else {
                continue
            }

            for file in contents where !file.hasPrefix(".") {
                if isDownloadFile(file) && fileMatchesItem(file, item: item) {
                    return true
                }
            }
        }
        return false
    }

    private func isDownloadFile(_ filename: String) -> Bool {
        FilenameMatching.isDownloadFile(filename, cacheExtensions: cacheExtensions,
                                        includeInstallerMarkers: false)
    }

    private func fileMatchesItem(_ filename: String, item: any MonitoredItem) -> Bool {
        FilenameMatching.directMatch(itemId: item.id, displayName: item.displayName,
                                     filename: filename)
    }

    // MARK: - Plist Monitoring

    private func startPlistMonitoringIfNeeded(for item: any MonitoredItem) {
        guard let recheckInterval = item.plistRecheckInterval, recheckInterval > 0,
              let plistKey = item.plistKey else {
            return
        }

        let plistPath = item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? ""
        guard !plistPath.isEmpty else { return }

        plistMonitorTasks[item.id]?.poll.cancel()

        let poll = Poll(every: Double(recheckInterval))
        poll.start { [weak self] in self?.checkPlistValue(for: item, at: plistPath, key: plistKey) }

        plistMonitorTasks[item.id] = PlistMonitorTask(
            poll: poll,
            itemId: item.id,
            plistPath: plistPath,
            plistKey: plistKey,
            expectedValue: item.expectedValue,
            evaluation: item.evaluation,
            lastValue: nil
        )

        writeLog("UnifiedMonitoringService: Started plist monitoring for \(item.id)", logLevel: .info)
    }

    private func checkPlistValue(for item: any MonitoredItem, at plistPath: String, key plistKey: String) {
        // useUserDefaults gives cached reads (e.g. global preferences).
        let result: MonitoringValidationResult
        if item.useUserDefaults == true {
            result = validatePlistValueViaUserDefaults(for: item, at: plistPath, key: plistKey)
        } else {
            result = validatePlistValue(
                at: plistPath,
                key: plistKey,
                expectedValue: item.expectedValue,
                evaluation: item.evaluation
            )
        }

        Task { @MainActor [weak self] in
            let oldResult = self?.validationResults[item.id]
            self?.validationResults[item.id] = result

            if oldResult?.isValid != result.isValid {
                writeLog("UnifiedMonitoringService: Validation changed for \(item.id): \(result.isValid)", logLevel: .info)

                if result.isValid {
                    self?.itemStatuses[item.id] = .completed
                    writeLog("UnifiedMonitoringService: Item '\(item.displayName)' completed via plist validation", logLevel: .info)
                } else if self?.itemStatuses[item.id] == .completed {
                    self?.itemStatuses[item.id] = .pending
                    writeLog("UnifiedMonitoringService: Item '\(item.displayName)' reset to pending (plist validation no longer passes)", logLevel: .info)
                }
            }
        }
    }

    /// Reads a plist value through UserDefaults for cached reads (especially global preferences).
    private func validatePlistValueViaUserDefaults(for item: any MonitoredItem, at plistPath: String, key plistKey: String) -> MonitoringValidationResult {
        let expandedPath = (plistPath as NSString).expandingTildeInPath

        // Domain from path: ~/Library/Preferences/com.example.plist → com.example
        let filename = (expandedPath as NSString).lastPathComponent
        let domain = (filename as NSString).deletingPathExtension

        let actualValue: String?
        if domain == ".GlobalPreferences" {
            // Global preferences: UserDefaults.standard includes the global domain.
            actualValue = UserDefaults.standard.string(forKey: plistKey)
        } else {
            actualValue = UserDefaults(suiteName: domain)?.string(forKey: plistKey)
        }

        // The shared default operator, as on the poller paths.
        guard let op = EvaluationOperator.resolve(evaluation: item.evaluation,
                                                  expectedValue: item.expectedValue) else {
            return MonitoringValidationResult(isValid: false, actualValue: actualValue,
                                              message: "Unknown evaluation '\(item.evaluation ?? "")'")
        }
        let isValid: Bool
        switch op {
        case .exists:
            isValid = actualValue != nil && !(actualValue?.isEmpty ?? true)
        case .boolean:
            isValid = actualValue == "1" || actualValue?.lowercased() == "true"
        case .contains:
            // Stringified upstream; see EvaluationOperator.containsMatch.
            isValid = EvaluationOperator.containsMatch(value: actualValue as Any,
                                                       expected: item.expectedValue)
        case .range:
            if let actual = Int(actualValue ?? ""),
               let parts = item.expectedValue?.split(separator: "-"),
               parts.count == 2,
               let lo = Int(parts[0]), let hi = Int(parts[1]) {
                isValid = actual >= lo && actual <= hi
            } else {
                isValid = false
            }
        case .equals:
            isValid = actualValue == item.expectedValue
        case .changed, .withinSeconds:
            // `changed` and recency are not supported here; fail closed.
            isValid = false
        }

        return MonitoringValidationResult(isValid: isValid, actualValue: actualValue, message: isValid ? "Validated" : "Not yet valid")
    }

    private func validatePlistValue(at path: String, key: String, expectedValue: String?, evaluation: String?) -> MonitoringValidationResult {
        guard PlistHelper.plistExists(at: path) else {
            return MonitoringValidationResult(isValid: false, message: "File not found")
        }

        guard let plist = PlistHelper.readPlist(at: path) else {
            return MonitoringValidationResult(isValid: false, message: "Unable to read plist")
        }

        let actualValue: String?
        if let value = plist.value(forKeyPath: key) {
            actualValue = String(describing: value)
        } else {
            actualValue = nil
        }

        // The shared default operator; unknown operators fail closed.
        guard let op = EvaluationOperator.resolve(evaluation: evaluation,
                                                  expectedValue: expectedValue) else {
            return MonitoringValidationResult(isValid: false, actualValue: actualValue,
                                              message: "Unknown evaluation '\(evaluation ?? "")'")
        }
        let isValid: Bool

        switch op {
        case .exists:
            isValid = actualValue != nil
        case .boolean:
            isValid = actualValue == "1" || actualValue?.lowercased() == "true"
        case .contains:
            // Stringified upstream; see EvaluationOperator.containsMatch.
            isValid = EvaluationOperator.containsMatch(value: actualValue as Any,
                                                       expected: expectedValue)
        case .equals:
            isValid = actualValue == expectedValue
        case .range:
            // Range such as "1-10".
            if let actual = Int(actualValue ?? ""),
               let range = expectedValue?.split(separator: "-"),
               range.count == 2,
               let lower = Int(range[0]),
               let upper = Int(range[1]) {
                isValid = actual >= lower && actual <= upper
            } else {
                isValid = false
            }
        case .changed, .withinSeconds:
            isValid = false
        }

        return MonitoringValidationResult(
            isValid: isValid,
            actualValue: actualValue,
            expectedValue: expectedValue,
            evaluationType: op.rawValue
        )
    }

    // MARK: - JSON Monitoring

    private func startJsonMonitoringIfNeeded(for item: any MonitoredItem) {
        guard let monitors = item.jsonMonitors else { return }

        for monitor in monitors {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let interval = Double(monitor.recheckInterval)

            let taskId = "\(item.id)_\(monitor.path.hashValue)"
            // Cancel the poll being replaced so it does not keep firing.
            jsonMonitorTasks[taskId]?.poll.cancel()

            let poll = Poll(every: interval)
            poll.start { [weak self] in self?.checkJsonValue(for: item.id, at: expandedPath, config: monitor) }

            jsonMonitorTasks[taskId] = JsonMonitorTask(
                poll: poll,
                itemId: item.id,
                jsonPath: expandedPath,
                jsonKey: monitor.key,
                expectedValue: nil,  // JsonMonitor doesn't have expectedValue, use evaluation instead
                lastValue: nil
            )
        }
    }

    // Internal for JsonMonitorTests.
    func checkJsonValue(for itemId: String, at path: String, config: InspectConfig.JsonMonitor) {
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let key = config.key
        guard let value = json[key] else { return }

        let stringValue = String(describing: value)

        Task { @MainActor [weak self] in
            self?.statusMessages[itemId] = stringValue

            if let evaluation = config.evaluation {
                // Case-insensitive via the shared vocabulary.
                switch EvaluationOperator(authored: evaluation) {
                case .boolean:
                    let isTrue = stringValue == "true" || stringValue == "1"
                    if isTrue {
                        self?.itemStatuses[itemId] = .completed
                    }
                case .exists:
                    self?.itemStatuses[itemId] = .completed
                case nil:
                    writeLog("UnifiedMonitoringService: unknown evaluation '\(evaluation)' on "
                             + "json monitor for \(itemId) — leaving pending", logLevel: .error)
                default:
                    // Other operators are not supported for JSON monitors; the item stays pending.
                    break
                }
            }
        }
    }

    // MARK: - Log Monitor Integration

    private func handleLogMonitorStatuses(_ statuses: [String: String]) {
        for (itemId, status) in statuses {
            let lowerStatus = status.lowercased()

            if lowerStatus.contains("fail") || lowerStatus.contains("error") {
                statusMessages[itemId] = status
                itemStatuses[itemId] = .failed
            } else if lowerStatus.contains("complet") || lowerStatus.contains("success") || lowerStatus == "completed" {
                itemStatuses[itemId] = .completed
            } else if lowerStatus.contains("install") {
                itemStatuses[itemId] = .active
            } else if lowerStatus.contains("download") {
                itemStatuses[itemId] = .active
            }

            statusMessages[itemId] = status
        }
    }

    // MARK: - Cleanup

    deinit {
        // `deinit` is nonisolated; SwiftUI and the tests release this object on the main actor, and
        // `assumeIsolated` traps otherwise. The normal path is `stopMonitoring(owner:)` from `onDisappear`.
        MainActor.assumeIsolated { stopMonitoring() }
    }
}

