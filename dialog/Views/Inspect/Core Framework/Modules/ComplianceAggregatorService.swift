//
//  ComplianceAggregatorService.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 23/01/2026
//
//  Observable service for loading and aggregating compliance plist data.
//  Wraps PlistAggregator static methods with reactive state and refresh capabilities.
//
//  Usage:
//    @StateObject private var complianceService = ComplianceAggregatorService()
//    complianceService.startMonitoring(sources: config.plistSources, refreshInterval: 5.0)
//

import SwiftUI
import Combine

// MARK: - Compliance Aggregator Service

/// Observable service for compliance plist aggregation with automatic refresh
class ComplianceAggregatorService: ObservableObject {

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

    // MARK: - Private State

    private var sources: [InspectConfig.PlistSourceConfig] = []
    private var refreshTimer: Timer?
    private var refreshInterval: Double = 5.0

    // MARK: - Initialization

    init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Interface

    /// Start monitoring plist sources with automatic refresh
    /// - Parameters:
    ///   - sources: Array of plist source configurations
    ///   - refreshInterval: Refresh interval in seconds (default: 5.0, min: 1.0)
    func startMonitoring(sources: [InspectConfig.PlistSourceConfig]?, refreshInterval: Double = 5.0) {
        stopMonitoring()

        guard let sources = sources, !sources.isEmpty else {
            writeLog("ComplianceAggregatorService: No plist sources configured", logLevel: .debug)
            return
        }

        self.sources = sources
        self.refreshInterval = max(1.0, refreshInterval)

        writeLog("ComplianceAggregatorService: Starting monitoring of \(sources.count) sources, refresh: \(self.refreshInterval)s", logLevel: .info)

        // Initial load
        loadAllSources()

        // Start refresh timer
        refreshTimer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { [weak self] _ in
            self?.loadAllSources()
        }
    }

    /// Stop monitoring and clear state
    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        writeLog("ComplianceAggregatorService: Stopped monitoring", logLevel: .debug)
    }

    /// Force immediate refresh
    func refresh() {
        loadAllSources()
    }

    /// Get category by name
    func category(named name: String) -> PlistAggregator.ComplianceCategory? {
        let result = categories.first { $0.name == name }
        if result == nil && !categories.isEmpty {
            writeLog("ComplianceAggregatorService: Category '\(name)' not found. Available: \(categories.map { $0.name }.joined(separator: ", "))", logLevel: .debug)
        }
        return result
    }

    /// Get check details for a category (formatted string for compliance cards)
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

        // Update state
        allItems = loadedItems
        categories = PlistAggregator.categorizeItems(loadedItems)

        // Calculate totals
        totalPassed = loadedItems.filter { $0.finding }.count
        totalChecks = loadedItems.count
        overallScore = totalChecks > 0 ? Double(totalPassed) / Double(totalChecks) : 0.0

        lastRefresh = Date()
        isLoading = false

        // Log results at INFO level for visibility
        writeLog("ComplianceAggregatorService: Loaded \(totalChecks) items, \(totalPassed) passed (\(Int(overallScore * 100))%)", logLevel: .info)
        writeLog("ComplianceAggregatorService: Created \(categories.count) categories: \(categories.map { $0.name }.joined(separator: ", "))", logLevel: .info)
    }
}

// MARK: - Convenience Extensions

extension ComplianceAggregatorService {

    /// Formatted overall score as percentage string
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

    /// Critical failures (items marked as critical that are failing)
    var criticalFailures: [PlistAggregator.ComplianceItem] {
        allItems.filter { $0.isCritical && !$0.finding }
    }

    /// Whether there are any critical failures
    var hasCriticalFailures: Bool {
        !criticalFailures.isEmpty
    }
}
