//
//  ComplianceAggregatorService.swift
//  dialog
//
//  Observable wrapper around `PlistAggregator`: loads compliance plists, publishes the
//  aggregated results and re-reads them on a poll. Used by the compliance presets' views.
//

import SwiftUI
import Combine

// MARK: - Compliance Aggregator Service

/// Main-actor compliance aggregation with automatic refresh. Only a source's `rescanCommand`
/// runs off the main actor, on a detached task that returns nothing.
@MainActor
final class ComplianceAggregatorService: ObservableObject {

    // MARK: - Published State

    /// All loaded compliance items (flat list)
    @Published private(set) var allItems: [PlistAggregator.ComplianceItem] = []

    /// Items grouped by category with aggregated statistics
    @Published private(set) var categories: [PlistAggregator.ComplianceCategory] = []

    /// Overall compliance score (0.0-1.0)
    @Published private(set) var overallScore: Double = 0.0

    /// Total passed checks
    @Published private(set) var totalPassed: Int = 0

    /// Total checks
    @Published private(set) var totalChecks: Int = 0

    /// Last refresh timestamp
    @Published private(set) var lastRefresh: Date?

    /// Loading state
    @Published private(set) var isLoading: Bool = false

    /// Error message if loading failed
    @Published private(set) var errorMessage: String?

    // MARK: - Display Labels

    /// User-facing label for a passing check: the first source's `healthyLabel`, else "Healthy".
    var healthyLabel: String {
        sources.first?.healthyLabel ?? "Healthy"
    }

    /// User-facing label for a failing check: the first source's `attentionLabel`, else "Needs Attention".
    var attentionLabel: String {
        sources.first?.attentionLabel ?? "Needs Attention"
    }

    /// The configured baseline's name for the detail sheet's subject line; nil when no source is configured.
    var sourceDisplayName: String? {
        sources.first?.displayName
    }

    // MARK: - Private State

    private var sources: [InspectConfig.PlistSourceConfig] = []
    private var refreshPoll: Poll?
    private var refreshInterval: Double = 5.0

    // MARK: - Initialization

    init() {}

    // No deinit: the poll's task holds this service weakly and ends once the service is released.

    // MARK: - Public Interface

    /// Loads the sources now and re-reads them every `refreshInterval` seconds (minimum 1.0).
    func startMonitoring(sources: [InspectConfig.PlistSourceConfig]?, refreshInterval: Double = 5.0) {
        stopMonitoring()

        guard let sources = sources, !sources.isEmpty else {
            writeLog("ComplianceAggregatorService: No plist sources configured", logLevel: .debug)
            return
        }

        self.sources = sources
        self.refreshInterval = max(1.0, refreshInterval)

        writeLog("ComplianceAggregatorService: Starting monitoring of \(sources.count) sources, refresh: \(self.refreshInterval)s", logLevel: .info)

        loadAllSources()

        let poll = Poll(every: self.refreshInterval)
        poll.start { [weak self] in
            self?.loadAllSources()
        }
        refreshPoll = poll
    }

    /// Stop the refresh poll. Loaded results stay published.
    func stopMonitoring() {
        refreshPoll?.cancel()
        refreshPoll = nil
        writeLog("ComplianceAggregatorService: Stopped monitoring", logLevel: .debug)
    }

    /// Re-reads the sources now.
    func refresh() {
        loadAllSources()
    }

    // MARK: - Re-running the checks

    /// Whether any source declares a `rescanCommand`; views label the button "Re-run checks" only then.
    var canRescan: Bool {
        sources.contains { !($0.rescanCommand ?? "").isEmpty }
    }

    /// Re-runs the checks, then reloads the results. Always writes `rescan:requested` to the
    /// interaction log so an attached orchestrator can run the scan; runs each `rescanCommand` if set.
    func rescan() {
        appendToInteractionLog("rescan:requested")

        let commands = sources.compactMap { $0.rescanCommand }.filter { !$0.isEmpty }
        guard !commands.isEmpty else {
            refresh()
            return
        }

        isLoading = true
        Task { [weak self] in
            // `waitUntilExit` blocks, so the commands run detached; the reload happens back on the main actor.
            await Task.detached(priority: .userInitiated) {
                for command in commands {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/bin/sh")
                    task.arguments = ["-c", command]
                    do {
                        try task.run()
                        task.waitUntilExit()
                        writeLog("ComplianceAggregatorService: rescan exited \(task.terminationStatus)",
                                 logLevel: task.terminationStatus == 0 ? .info : .error)
                    } catch {
                        writeLog("ComplianceAggregatorService: rescan failed to launch — \(error.localizedDescription)",
                                 logLevel: .error)
                    }
                }
            }.value
            self?.isLoading = false
            self?.refresh()
        }
    }

    /// The category with this name, if loaded.
    func category(named name: String) -> PlistAggregator.ComplianceCategory? {
        let result = categories.first { $0.name == name }
        if result == nil && !categories.isEmpty {
            writeLog("ComplianceAggregatorService: Category '\(name)' not found. Available: \(categories.map { $0.name }.joined(separator: ", "))", logLevel: .debug)
        }
        return result
    }

    /// Formatted check list for a category's compliance card.
    func checkDetails(for categoryName: String, maxItems: Int = 15, sortFailedFirst: Bool = true) -> String {
        guard let category = category(named: categoryName) else { return "" }
        return PlistAggregator.generateCheckDetails(
            items: category.items,
            maxItems: maxItems,
            sortFailedFirst: sortFailedFirst
        )
    }

    // MARK: - Private Implementation

    private func loadAllSources() {
        guard !sources.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        var loadedItems: [PlistAggregator.ComplianceItem] = []
        var hasErrors = false

        for source in sources {
            if let result = PlistAggregator.loadPlistSource(source: source) {
                loadedItems.append(contentsOf: result.items)
                writeLog("ComplianceAggregatorService: Loaded \(result.items.count) items from \(source.displayName)", logLevel: .debug)
            } else {
                writeLog("ComplianceAggregatorService: Failed to load \(source.displayName) at \(source.path)", logLevel: .error)
                hasErrors = true
            }
        }

        if loadedItems.isEmpty && hasErrors {
            errorMessage = "Failed to load compliance data"
            isLoading = false
            return
        }

        allItems = loadedItems
        categories = PlistAggregator.categorizeItems(loadedItems)

        totalPassed = loadedItems.filter { $0.finding }.count
        totalChecks = loadedItems.count
        overallScore = totalChecks > 0 ? Double(totalPassed) / Double(totalChecks) : 0.0

        lastRefresh = Date()
        isLoading = false

        writeLog("ComplianceAggregatorService: Loaded \(totalChecks) items, \(totalPassed) passed (\(Int(overallScore * 100))%)", logLevel: .info)
        writeLog("ComplianceAggregatorService: Created \(categories.count) categories: \(categories.map { $0.name }.joined(separator: ", "))", logLevel: .info)
    }
}

// MARK: - Convenience Extensions

extension ComplianceAggregatorService {

    /// Overall score as a percentage string.
    var scorePercentage: String {
        "\(Int(overallScore * 100))%"
    }

    /// Number of failed checks
    var totalFailed: Int {
        totalChecks - totalPassed
    }

    /// Whether all checks are passing
    var isFullyCompliant: Bool {
        totalChecks > 0 && totalPassed == totalChecks
    }

    /// Failing items marked critical.
    var criticalFailures: [PlistAggregator.ComplianceItem] {
        allItems.filter { $0.isCritical && !$0.finding }
    }

    /// Whether there are any critical failures
    var hasCriticalFailures: Bool {
        !criticalFailures.isEmpty
    }
}
