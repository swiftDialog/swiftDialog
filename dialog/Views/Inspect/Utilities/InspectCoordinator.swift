//
//  InspectStateCoordinator.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 20/09/2025
//
//  Coordinates between specialized services for Inspect mode
//  As code explodes, my silly attempt in getting to a clean separation of concerns with each service handling its specific domain
//

import Foundation
import SwiftUI
import Combine

// MARK: - State Coordinator

class InspectStateCoordinator: ObservableObject {

    // MARK: - Core Published State

    @Published var loadingState: LoadingState = .loading
    @Published var items: [InspectConfig.ItemConfig] = []
    @Published var config: InspectConfig?

    // MARK: - Configuration State

    @Published var uiConfiguration = UIConfiguration()
    @Published var backgroundConfiguration = BackgroundConfiguration()
    @Published var buttonConfiguration = ButtonConfiguration()

    // MARK: - Dynamic State (from Progress)

    @Published var completedItems: Set<String> = []
    @Published var downloadingItems: Set<String> = []

    // MARK: - Services (Composition over Inheritance)

    private let configurationService = Config()
    private let monitoringService = Monitoring()
    private let progressService: Progress

    // MARK: - Additional State

    @Published var plistSources: [InspectConfig.PlistSourceConfig]?
    @Published var colorThresholds = InspectConfig.ColorThresholds.default
    @Published var plistValidationResults: [String: Bool] = [:]

    private var sideMessageTimer: Timer?
    private var configPath: String?

    // MARK: - Initialization

    init() {
        self.progressService = Progress()

        // Setup service delegates
        monitoringService.delegate = self

        // Observe progress changes
        setupProgressObservers()

        writeLog("InspectStateCoordinator: Initialized with service architecture", logLevel: .info)
    }

    // MARK: - Public API

    func initialize() {
        writeLog("InspectStateCoordinator: Starting initialization", logLevel: .info)

        loadConfiguration()
        // startMonitoring() will be called after config loads
    }

    func retryConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingState = .loading
        }
        loadConfiguration()
    }

    // MARK: - Configuration Loading

    private func loadConfiguration() {
        let result = configurationService.loadConfiguration()

        switch result {
        case .success(let configResult):
            handleSuccessfulConfiguration(configResult)

        case .failure(let error):
            handleConfigurationError(error)
        }
    }

    private func handleSuccessfulConfiguration(_ configResult: ConfigurationResult) {
        // Log warnings
        for warning in configResult.warnings {
            writeLog("InspectStateCoordinator: Config warning - \(warning)", logLevel: .info)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let loadedConfig = configResult.config

            // Set core configuration
            self.config = loadedConfig
            self.items = loadedConfig.items.sorted { $0.guiIndex < $1.guiIndex }

            // Set additional config
            self.plistSources = loadedConfig.plistSources
            self.colorThresholds = loadedConfig.colorThresholds ?? InspectConfig.ColorThresholds.default

            // Extract UI configurations
            self.uiConfiguration = self.configurationService.extractUIConfiguration(from: loadedConfig)
            self.backgroundConfiguration = self.configurationService.extractBackgroundConfiguration(from: loadedConfig)
            self.buttonConfiguration = self.configurationService.extractButtonConfiguration(from: loadedConfig)

            // Setup side message rotation if needed
            if self.uiConfiguration.sideMessages.count > 1,
               let interval = loadedConfig.sideInterval {
                self.startSideMessageRotation(interval: TimeInterval(interval))
            }

            // Initialize progress service with items
            self.progressService.configureItems(self.items)

            // Store config path
            if case .file(let path) = configResult.source {
                self.configPath = path
            }

            // Mark as loaded
            self.loadingState = .loaded

            // Start monitoring AFTER config is loaded
            self.startMonitoring()

            // Setup AppInspector integration for external tools
            self.writeAppInspectorConfig()

            // Validate all items
            self.validateAllItems()

            writeLog("InspectStateCoordinator: Configuration loaded successfully", logLevel: .info)
        }
    }

    private func handleConfigurationError(_ error: ConfigurationError) {
        writeLog("InspectStateCoordinator: Configuration failed - \(error.localizedDescription)", logLevel: .error)

        DispatchQueue.main.async { [weak self] in
            self?.loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        guard let config = config else {
            writeLog("InspectStateCoordinator: No config available for monitoring", logLevel: .info)
            return
        }

        // Start monitoring service
        monitoringService.startMonitoring(
            items: items,
            cachePaths: config.cachePaths ?? []
        )

        // Simulate downloading state for pending items
        simulateDownloadingForPendingItems()

        writeLog("InspectStateCoordinator: Monitoring started", logLevel: .info)
    }

    private func simulateDownloadingForPendingItems() {
        // Simulate items as downloading that aren't yet installed - wasted too much nhours in debugging this  
        for item in items {
            if !completedItems.contains(item.id) && !plistValidationResults[item.id, default: false] {
                // Randomly simulate some as downloading
                if Int.random(in: 0...2) == 0 {
                    progressService.setItemDownloading(item.id)

                    // Simulate completion after random delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...8)) { [weak self] in
                        guard let self = self else { return }

                        // Re-validate to check if actually installed
                        let isValid = self.validatePlistItem(item)
                        if isValid {
                            self.progressService.setItemCompleted(item.id)
                        } else {
                            // Keep checking
                            self.progressService.setItemPending(item.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Observers

    private func setupProgressObservers() {
        // Observe progress service changes
        progressService.$overallProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateButtonStateIfNeeded(progress: progress)
            }
            .store(in: &cancellables)

        progressService.$itemStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                self?.updateItemSets(from: statuses)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateItemSets(from statuses: [String: InspectItemStatus]) {
        completedItems = progressService.getCompletedItems()
        downloadingItems = progressService.getDownloadingItems()
    }

    private func updateButtonStateIfNeeded(progress: OverallProgress) {
        if progress.isComplete && buttonConfiguration.autoEnableButton {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.buttonConfiguration.button1Text = self.config?.autoEnableButtonText ?? "OK"
                self.buttonConfiguration.button1Disabled = false
                writeLog("InspectStateCoordinator: Auto-enabled button with text: \(self.buttonConfiguration.button1Text)", logLevel: .info)
            }
        }
    }

    // MARK: - Side Messages

    private func startSideMessageRotation(interval: TimeInterval) {
        sideMessageTimer?.invalidate()

        sideMessageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let count = self.uiConfiguration.sideMessages.count
                if count > 1 {
                    self.uiConfiguration.currentSideMessageIndex =
                        (self.uiConfiguration.currentSideMessageIndex + 1) % count
                }
            }
        }

        writeLog("InspectStateCoordinator: Started side message rotation", logLevel: .debug)
    }

    func getCurrentSideMessage() -> String? {
        guard !uiConfiguration.sideMessages.isEmpty else { return nil }
        let index = min(uiConfiguration.currentSideMessageIndex, uiConfiguration.sideMessages.count - 1)
        return uiConfiguration.sideMessages[index]
    }

    // MARK: - AppInspector Integration

    private func writeAppInspectorConfig() {
        guard let config = config else { return }

        // Create AppInspector-compatible configuration for external tools
        do {
            let appInspectorApps = items.map { item in
                return [
                    "id": item.id,
                    "displayName": item.displayName,
                    "guiIndex": item.guiIndex,
                    "paths": item.paths
                ] as [String: Any]
            }

            var appInspectConfig: [String: Any] = [
                "apps": appInspectorApps
            ]

            if let cachePaths = config.cachePaths {
                appInspectConfig["cachePaths"] = cachePaths
            }

            // Write to temporary config file for AppInspector
            let jsonData = try JSONSerialization.data(withJSONObject: appInspectConfig, options: .prettyPrinted)
            let tempConfigPath = InspectConstants.tempConfigPath
            try jsonData.write(to: URL(fileURLWithPath: tempConfigPath))

            writeLog("InspectStateCoordinator: Created AppInspector config at \(tempConfigPath)", logLevel: .info)

        } catch {
            writeLog("InspectStateCoordinator: Failed to create AppInspector config: \(error)", logLevel: .error)
        }
    }

    // MARK: - Validation

    @MainActor
    func validatePlistItem(_ item: InspectConfig.ItemConfig) -> Bool {
        let request = ValidationRequest(
            item: item,
            plistSources: plistSources,
            basePath: uiConfiguration.iconBasePath
        )

        let result = Validation.shared.validateItem(request)
        plistValidationResults[item.id] = result.isValid

        // Update progress service based on validation result
        if result.isValid {
            progressService.updateItemStatus(item.id, status: .completed)
            completedItems.insert(item.id)
        } else {
            progressService.updateItemStatus(item.id, status: .pending)
            completedItems.remove(item.id)
        }

        return result.isValid
    }

    func validateAllItems() {
        Task { @MainActor in
            for item in items {
                _ = validatePlistItem(item)
            }
            writeLog("InspectStateCoordinator: Validated \(items.count) items", logLevel: .debug)
        }
    }

    @MainActor
    func getPlistValueForDisplay(item: InspectConfig.ItemConfig) -> String? {
        guard let plistKey = item.plistKey else { return nil }

        // Use validation service to get the actual plist value
        // Pass iconBasePath for relative path resolution
        for path in item.paths {
            if let value = Validation.shared.getPlistValue(at: path, key: plistKey, basePath: uiConfiguration.iconBasePath) {
                return value
            }
        }
        return nil
    }

    // MARK: - Button State

    func checkAndUpdateButtonState() {
        let progress = progressService.overallProgress
        updateButtonStateIfNeeded(progress: progress)
    }

    // MARK: - Cleanup

    deinit {
        writeLog("InspectStateCoordinator: Starting cleanup", logLevel: .info)

        // Stop monitoring
        monitoringService.stopMonitoring()

        // Stop timers
        sideMessageTimer?.invalidate()
        sideMessageTimer = nil

        // Clear subscriptions
        cancellables.removeAll()

        writeLog("InspectStateCoordinator: Cleanup completed", logLevel: .info)
    }
}

// MARK: - Monitoring Delegate

extension InspectStateCoordinator: InspectMonitoringDelegate {

    func monitoringService(_ service: Monitoring, didDetectInstallation itemId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressService.setItemCompleted(itemId)
            writeLog("InspectStateCoordinator: Item '\(itemId)' installed", logLevel: .info)
        }
    }

    func monitoringService(_ service: Monitoring, didDetectDownload itemId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressService.setItemDownloading(itemId)
            writeLog("InspectStateCoordinator: Item '\(itemId)' downloading", logLevel: .info)
        }
    }

    func monitoringService(_ service: Monitoring, didDetectRemoval itemId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressService.setItemPending(itemId)
            writeLog("InspectStateCoordinator: Item '\(itemId)' removed", logLevel: .info)
        }
    }

    func monitoringServiceDidDetectChanges(_ service: Monitoring) {
        // Update UI if needed
        objectWillChange.send()
    }
}
