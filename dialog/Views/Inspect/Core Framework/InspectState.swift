//
//  InspectState.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//

import Foundation
import SwiftUI
import Combine

enum LoadingState: Equatable {
    case loading
    case loaded
    case failed(String)
}

enum ConfigurationSource: Equatable {
    case file(path: String)
    case testData
    case fallback
}

// MARK: - Form Input State Structure

/// Stores form input values for guidance content (checkboxes, dropdowns, radios, toggles, sliders)
/// Universal structure usable across all presets with guidance content
struct GuidanceFormInputState: Codable {
    var checkboxes: [String: Bool] = [:]      // checkbox id -> checked state
    var dropdowns: [String: String] = [:]     // dropdown id -> selected value
    var radios: [String: String] = [:]        // radio id -> selected option
    var toggles: [String: Bool] = [:]         // toggle id -> enabled state
    var sliders: [String: Double] = [:]       // slider id -> current value
    var textfields: [String: String] = [:]    // textfield id -> text value
}

// MARK: - Configuration Structs for Grouped State

struct UIConfiguration {
    var windowTitle: String = "System Inspection"
    var statusMessage: String = "Inspection active - Items will appear as they are detected"
    var iconPath: String?
    var iconBasePath: String?  // Base path for relative icon paths
    var overlayIcon: String?   // Overlay icon for brand identity badges
    var sideMessages: [String] = []
    var currentSideMessageIndex: Int = 0
    var popupButtonText: String = "Install details..."
    var preset: String = "preset1"
    var highlightColor: String = "#808080"
    var secondaryColor: String = "#A0A0A0"
    var iconSize: Int = 120
    var subtitleMessage: String?

    // Window sizing configuration
    var width: Int?                // Custom width override
    var height: Int?               // Custom height override
    var size: String?              // Size mode: "compact", "standard", or "large"

    // Banner configuration (optional - preserves logo display when not set)
    var bannerImage: String?        // Path to banner image
    var bannerHeight: Int = 100     // Default banner height
    var bannerTitle: String?        // Optional title overlay on banner

    // Preset6 specific properties
    var rotatingImages: [String] = []
    var imageRotationInterval: Double = 4.0
    var imageFormat: String = "square"     // "square" | "rectangle" | "round"
    var imageSyncMode: String = "manual"   // "manual" | "sync" | "auto"
    var stepStyle: String = "plain"        // "plain" | "colored" | "cards"
    var listIndicatorStyle: String = "numbers"  // "letters" | "numbers" | "roman" - defaults to "numbers"
}

struct BackgroundConfiguration {
    var backgroundColor: String?
    var backgroundImage: String?
    var backgroundOpacity: Double = 1.0
    var textOverlayColor: String?
    var gradientColors: [String] = []
}

struct ButtonConfiguration {
    var button1Text: String = ""             // Text for primary button (loaded from config)
    var button1Disabled: Bool = false
    var button2Text: String = ""             // Text for secondary button (loaded from config)
    var button2Visible: Bool = false          // Show second button when complete
    var autoEnableButton: Bool = true
    // Note: button2Disabled removed - button2 is always enabled when shown
    // Note: buttonStyle removed - not used in Inspect mode
}

class InspectState: ObservableObject, FileMonitorDelegate, @unchecked Sendable {
    // MARK: - Core State (Keep as @Published)
    @Published var loadingState: LoadingState = .loading
    @Published var items: [InspectConfig.ItemConfig] = []
    @Published var config: InspectConfig?

    // MARK: - Debug Mode (Cross-Preset)

    /// Determines if presets should skip completed steps on subsequent launches.
    /// Returns `false` (don't skip) when debug mode is active via:
    /// 1. `--debug` CLI flag
    /// 2. `DIALOG_DEBUG_MODE=1` environment variable
    /// 3. `debugMode: true` in config JSON
    /// 4. `--inspect-mode` (always fresh start for development/testing)
    /// This allows testing/demo scenarios to always start from step 1 while preserving form values.
    var shouldSkipCompletedSteps: Bool {
        // CLI --debug flag
        if appvars.debugMode {
            writeLog("InspectState: Debug mode enabled via --debug CLI flag", logLevel: .info)
            return false
        }
        // Inspect mode always implies debug mode (fresh start every launch)
        if !appvars.inspectConfigPath.isEmpty {
            writeLog("InspectState: Debug mode enabled via --inspect-mode (always fresh start)", logLevel: .info)
            return false
        }
        // Environment variable override
        if ProcessInfo.processInfo.environment["DIALOG_DEBUG_MODE"] != nil {
            writeLog("InspectState: Debug mode enabled via DIALOG_DEBUG_MODE environment variable", logLevel: .info)
            return false
        }
        // Config-based debug mode
        if config?.debugMode == true {
            writeLog("InspectState: Debug mode enabled via config debugMode: true", logLevel: .info)
            return false
        }
        return true  // Normal behavior: skip if completed
    }

    // MARK: - Grouped Configuration State
    @Published var uiConfiguration = UIConfiguration()
    @Published var backgroundConfiguration = BackgroundConfiguration()
    @Published var buttonConfiguration = ButtonConfiguration()
    
    // MARK: - Preset-specific State
    @Published var plistSources: [InspectConfig.PlistSourceConfig]?
    @Published var colorThresholds = InspectConfig.ColorThresholds.default
    @Published var plistValidationResults: [String: Bool] = [:] // Track plist validation results

    // MARK: - Pre-cache Progress State (for "Loading configuration files..." indicator)
    @Published var preCacheProgress: (loaded: Int, total: Int)? = nil  // nil = not started, (x, y) = loading

    // MARK: - Plist Monitoring - Generalized from Preset6
    private var plistMonitors: [String: PlistMonitorTask] = [:] // Track active monitoring tasks
    private var jsonMonitors: [String: JsonMonitorTask] = [:] // Track active JSON monitoring tasks

    /// Encapsulates a plist monitoring task with timer and state
    private struct PlistMonitorTask {
        let timer: Timer
        let initialValue: String
        let currentValue: String
        let recheckInterval: Int
    }

    /// Encapsulates a JSON monitoring task with timer and state
    private struct JsonMonitorTask {
        let timer: Timer
        let initialValue: String
        let currentValue: String
        let recheckInterval: Int
    }

    // MARK: - View-specific State (Should be @State in views, but keeping for now)
    @Published var scrollOffset: Int = 0 // Manual scroll offset, currently needed in preset3
    @Published var lastManualScrollTime: Date? // Track manual scrolling
    
    // MARK: - Dynamic State (Needs @Published for UI updates)
    @Published var completedItems: Set<String> = []
    @Published var downloadingItems: Set<String> = []
    @Published var failedItems: Set<String> = []  // Items that failed installation (detected from log monitor)

    // MARK: - Wallpaper Selection State (Preset6 wallpaper-picker)
    @Published var wallpaperSelection: [String: String] = [:]  // selectionKey → full image path

    // MARK: - Form Input State (guidance content)
    @Published var guidanceFormInputs: [String: GuidanceFormInputState] = [:]

    // MARK: - Log Monitor State (Cross-Preset)
    @Published var logMonitorStatuses: [String: String] = [:]  // itemId -> status from log monitoring
    private var logMonitorCancellable: AnyCancellable?

    // MARK: - User Values (for override results, etc.)
    @Published var userValues: [String: String] = [:]  // General key-value store for user selections/results

    private var appInspector: AppInspector?
    @Published var configurationSource: ConfigurationSource = .testData
    private var configPath: String?
    private var lastCommandFileSize: Int = 0
    private var lastProcessedLineCount: Int = 0
    private var commandFileMonitor: DispatchSourceFileSystemObject?
    private var updateTimer: Timer?
    private var fileSystemCheckTimer: Timer?
    private var sideMessageTimer: Timer?
    private var debouncedUpdater = DebouncedUpdater()
    private let fileSystemCache = FileSystemCache()

    // Plist change detection baselines - stores initial values for "changed" evaluation
    private var plistBaselines: [String: String?] = [:]  // itemId -> initial plist value (nil = key absent)
    private var plistBaselinesInitialized: Set<String> = []

    // FSEvents priority tracking - prevent timer interference
    private var fsEventsTimestamps: [String: Date] = [:]
    private let fsEventsPriorityWindow: TimeInterval = 10.0 // 10 seconds

    private let fsEventsMonitor = FileMonitor()
    private var lastFSEventTime: Date?
    private var lastLogTime = Date()
    
    // MARK: - Base Business Logic Services initialize
    private let configurationService = Config()
    
    func initialize() {
        writeLog("InspectState.initialize() - Starting initialization", logLevel: .info)
        
        loadConfiguration()
        startMonitoring()
        
        writeLog("InspectState: Memory-safe initialization complete", logLevel: .info)
    }
    
    private func loadConfiguration() {
        // Use configuration service to load config
        // TODO: this works when calling the global appvars but really should be passed in as a config item.
        // Pass the inspect config path from appvars if available
        let result = configurationService.loadConfiguration(fromFile: appvars.inspectConfigPath)
        
        switch result {
        case .success(let configResult):
            // Log warnings from configuration validation 
            // TODO: Learn how best type-chcek in swift
            for warning in configResult.warnings {
                writeLog("InspectState: Configuration warning - \(warning)", logLevel: .info)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let loadedConfig = configResult.config

                // Set core configuration
                self.config = loadedConfig

                // PRIORITY: Set UI configuration FIRST before items
                // This ensures button text, title, etc. are ready before view transitions from loading
                print("InspectState: About to extract configurations")
                print("InspectState: loadedConfig.banner = \(loadedConfig.banner ?? "nil")")
                print("InspectState: loadedConfig.listIndicatorStyle = \(loadedConfig.listIndicatorStyle ?? "nil")")
                print("InspectState: loadedConfig.stepStyle = \(loadedConfig.stepStyle ?? "nil")")
                self.uiConfiguration = self.configurationService.extractUIConfiguration(from: loadedConfig)
                print("InspectState: After extraction - uiConfiguration.bannerImage = \(self.uiConfiguration.bannerImage ?? "nil")")
                print("InspectState: After extraction - uiConfiguration.iconBasePath = \(self.uiConfiguration.iconBasePath ?? "nil")")
                print("InspectState: After extraction - uiConfiguration.listIndicatorStyle = \(self.uiConfiguration.listIndicatorStyle)")
                print("InspectState: After extraction - uiConfiguration.stepStyle = \(self.uiConfiguration.stepStyle)")
                self.backgroundConfiguration = self.configurationService.extractBackgroundConfiguration(from: loadedConfig)
                self.buttonConfiguration = self.configurationService.extractButtonConfiguration(from: loadedConfig)

                // Set plist sources from config - required in preset5
                self.plistSources = loadedConfig.plistSources

                // Set color thresholds from config or use defaults
                if let colorThresholds = loadedConfig.colorThresholds {
                    self.colorThresholds = colorThresholds
                    writeLog("InspectState: Using custom color thresholds - Excellent: \(colorThresholds.excellent), Good: \(colorThresholds.good), Warning: \(colorThresholds.warning)", logLevel: .info)
                } else {
                    self.colorThresholds = InspectConfig.ColorThresholds.default
                    writeLog("InspectState: Using default color thresholds", logLevel: .info)
                }

                // Set items LAST - this triggers view transition from loading to main content
                self.items = loadedConfig.items.sorted { $0.guiIndex < $1.guiIndex }
                
                // Set side message rotation if multiple messages exist
                if self.uiConfiguration.sideMessages.count > 1, let interval = loadedConfig.sideInterval {
                    self.startSideMessageRotation(interval: TimeInterval(interval))
                }
                
                // Debug logging for preset detection
                if appvars.debugMode { print("DEBUG: loadedConfig.preset = \(loadedConfig.preset)") }
                if appvars.debugMode { print("DEBUG: Setting preset to: \(self.uiConfiguration.preset)") }
                
                writeLog("InspectState: Loaded \(loadedConfig.items.count) items from config", logLevel: .info)
                writeLog("InspectState: Title: \(self.uiConfiguration.windowTitle)", logLevel: .debug)
                writeLog("InspectState: Using preset: \(self.uiConfiguration.preset)", logLevel: .info)
                if !self.uiConfiguration.sideMessages.isEmpty {
                    writeLog("InspectState: Side messages: \(self.uiConfiguration.sideMessages.count)", logLevel: .debug)
                }
                
                // Log configuration source
                self.configurationSource = configResult.source
                switch configResult.source {
                case .file(let path):
                    writeLog("InspectState: Configuration loaded from file: \(path)", logLevel: .info)
                    self.configPath = path
                case .testData:
                    writeLog("InspectState: Using fallback test data configuration", logLevel: .info)
                case .fallback:
                    writeLog("InspectState: Using fallback configuration", logLevel: .info)
                }
                
                // Here, configuration loaded successfully
                self.loadingState = .loaded
                
                // Validate items to populate results dict
                self.validateAllItems()

                // Once config is loaded, start FSEvents monitoring for UI updates
                self.setupOptimizedFileMonitoring()

                // Initialize progress tracker
                self.initializeProgressTracker()

                // Setup log monitoring (cross-preset feature)
                self.setupLogMonitoring(config: loadedConfig)
            }

        case .failure(let error):
            writeLog("InspectState: Configuration loading failed - \(error.localizedDescription)", logLevel: .error)
            DispatchQueue.main.async { [weak self] in
                self?.loadingState = .failed(error.localizedDescription)
            }
        }
    }
    
    
    func retryConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingState = .loading
        }
        loadConfiguration()
    }
    
    
    private func startMonitoring() {
        writeLog("InspectState.startMonitoring() - Starting all monitoring components", logLevel: .info)
        
        // Create AppInspector for filesystem monitoring
        appInspector = AppInspector()
        
        // Next, configure AppInspector if we have config data
        if let config = config {
            loadAppInspectConfig(config: config, originalPath: configPath ?? "")
        }
        
        // Setup command file monitoring for continued status updates
        setupCommandFileMonitoring()
        
        // Setup periodic updates as backup detection method
        setupOptimizedPeriodicUpdates()

        // Note: FSEvents monitoring is setup in loadConfiguration() after config is loaded
        // Don't call setupOptimizedFileMonitoring() here as config isn't loaded yet

        writeLog("InspectState: All monitoring components started successfully", logLevel: .info)
    }
    
    private func setupCommandFileMonitoring() {
        // Look into this for memory-safety checks - our command file monitoring setup is sensitive, we want avoid leaks
        let commandFilePath = InspectConstants.commandFilePath
        
        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            writeLog("InspectState: Command file doesn't exist yet: \(commandFilePath)", logLevel: .debug)
            return
        }
        
        // Prevent multiple monitoring setups
        guard commandFileMonitor == nil else {
            writeLog("InspectState: Command file monitoring already set up", logLevel: .debug)
            return
        }
        
        // Create command file monitor with weak self to prevent retain cycles
        let fileHandle = open(commandFilePath, O_EVTONLY)
        guard fileHandle >= 0 else {
            writeLog("InspectState: Unable to open command file for monitoring: \(commandFilePath)", logLevel: .error)
            return
        }
        
        commandFileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        
        commandFileMonitor?.setEventHandler { [weak self] in
            // Use weak self to prevent memory leaks in nested closures
            guard let self = self else { return }
            self.debouncedUpdater.debounce(key: "command-file-update") { [weak self] in
                self?.updateAppStatus()
            }
        }
        
        commandFileMonitor?.setCancelHandler {
            close(fileHandle)
        }
        
        commandFileMonitor?.resume()
        writeLog("DispatchSource file monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedPeriodicUpdates() {
        // Periodic updates with weak self references
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: InspectConstants.robustUpdateInterval, repeats: true) { [weak self] _ in
            // Again, use weak self to prevent memory leaks
            self?.performRobustAppCheck()
        }
        
        writeLog("Timer-based monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedFileMonitoring() {
        // Instantiate FSEvents monitoring setup
        let cachePaths = config?.cachePaths ?? []
        
        guard !cachePaths.isEmpty else {
            writeLog("InspectState: No cache paths configured for FSEvents monitoring", logLevel: .debug)
            return
        }
        
        // Set up FSEvents monitor with our delegate pattern
        fsEventsMonitor.delegate = self
        fsEventsMonitor.startMonitoring(items: items, cachePaths: cachePaths)
        
        writeLog("FSEvents monitoring active", logLevel: .info)
    }

    // MARK: - Log Monitoring Setup

    private func setupLogMonitoring(config: InspectConfig) {
        // Check if log monitoring is configured
        guard config.logMonitor != nil || config.logMonitors != nil else {
            return
        }

        writeLog("InspectState: Setting up log monitoring", logLevel: .info)

        // Set items for auto-matching
        LogMonitorService.shared.setItems(items)

        // Configure the service
        LogMonitorService.shared.configure(with: config)

        // Subscribe to status changes — only react to NEW or CHANGED statuses
        // Without this guard, Combine publishes the entire dictionary on every change,
        // causing stale "Installing..." statuses to demote already-completed items.
        var previousStatuses: [String: String] = [:]
        logMonitorCancellable = LogMonitorService.shared.$latestStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                guard let self = self else { return }
                self.logMonitorStatuses = statuses

                // Only process items whose status actually changed
                for (itemId, status) in statuses {
                    guard status != previousStatuses[itemId] else { continue }
                    previousStatuses[itemId] = status

                    if status.hasPrefix("Failed") {
                        self.failedItems.insert(itemId)
                        self.downloadingItems.remove(itemId)
                        writeLog("InspectState: Item '\(itemId)' marked as failed from log monitor", logLevel: .info)
                    } else if status == "Completed" {
                        self.completedItems.insert(itemId)
                        self.downloadingItems.remove(itemId)
                        self.failedItems.remove(itemId)
                        writeLog("InspectState: Item '\(itemId)' marked as completed from log monitor", logLevel: .info)
                    } else if self.isUpdatingStatus(status) {
                        if self.completedItems.contains(itemId) {
                            self.completedItems.remove(itemId)
                            self.downloadingItems.insert(itemId)
                            writeLog("InspectState: Item '\(itemId)' moved to updating state from log monitor: \(status)", logLevel: .info)
                        } else if !self.downloadingItems.contains(itemId) {
                            self.downloadingItems.insert(itemId)
                            writeLog("InspectState: Item '\(itemId)' marked as downloading from log monitor: \(status)", logLevel: .info)
                        }
                    }
                }
            }
    }

    /// Check if a log monitor status indicates an update/install is in progress
    /// These statuses should move an item from "completed" to "updating" state
    private func isUpdatingStatus(_ status: String) -> Bool {
        let updatingPrefixes = [
            "Installing",
            "Extracting",
            "Downloading",
            "Mounting",
            "Copying",
            "Unpacking",
            "Verifying",
            "Updating",
            "Running script"
        ]

        for prefix in updatingPrefixes where status.hasPrefix(prefix) {
            return true
        }

        // Also check for percentage progress (e.g., "Downloading 45%")
        if status.contains("%") {
            return true
        }

        return false
    }

    private func performRobustAppCheck() {
        // Simple, timer-based monitoring - checks all app states every 2 seconds
        // This ensures 100% reliability for detecting app installations
        
        // Only log every 30 seconds to avoid memory accumulation
        if Date().timeIntervalSince(lastLogTime) > 30.0 {
            writeLog("InspectState: App status monitoring active", logLevel: .debug)
            lastLogTime = Date()
        }
        
        // Always check command file for updates (external status changes)
        checkCommandFileForUpdates()
        
        // Check all app installation statuses directly
        checkDirectInstallationStatus()
    }
    
    // MARK: - FileMonitorDelegate Implementation (Cache-only)
    
    func appInstalled(_ appId: String, at path: String) {
        // App installations are handled by robust timer polling
        // FSEvents only used for pre-loaded cachePaths monitoring
        writeLog("InspectState: FSEvents app install ignored - handled by timer polling", logLevel: .debug)
    }
    
    func appUninstalled(_ appId: String, at path: String) {
        // App uninstalls are handled by robust timer polling
        // FSEvents only used for pre-loaded cachePaths  monitoring 
        writeLog("InspectState: FSEvents app uninstall ignored - handled by timer polling", logLevel: .debug)
    }
    
    func cacheFileCreated(_ path: String) {
        lastFSEventTime = Date()

        // Extract just the filename from the full path for logging
        let filename = (path as NSString).lastPathComponent
        writeLog("InspectState: FSEvents detected new cache file: '\(filename)' at path: \(path)", logLevel: .info)

        // Simply invalidate cache - let timer polling handle state updates
        // This prevents race conditions between FSEvents and timer
        let parentPath = (path as NSString).deletingLastPathComponent
        fileSystemCache.invalidateCache(for: parentPath)
        writeLog("InspectState: Invalidated cache for directory: \(parentPath) - timer will update status", logLevel: .debug)

        // Optionally trigger immediate timer check for responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.performRobustAppCheck()
        }
    }
    
    func cacheFileRemoved(_ path: String) {
        lastFSEventTime = Date()

        // Extract just the filename from the full path for logging
        let filename = (path as NSString).lastPathComponent
        writeLog("InspectState: FSEvents detected cache file removal: '\(filename)' at path: \(path)", logLevel: .info)

        // Simply invalidate cache - let timer polling handle state updates
        // This prevents race conditions between FSEvents and timer
        let parentPath = (path as NSString).deletingLastPathComponent
        fileSystemCache.invalidateCache(for: parentPath)
        writeLog("InspectState: Invalidated cache for directory: \(parentPath) - timer will update status", logLevel: .debug)

        // Optionally trigger immediate timer check for responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.performRobustAppCheck()
        }
    }
    
    private func cacheFileMatchesItem(_ filePath: String, item: InspectConfig.ItemConfig) -> Bool {
        let filename = (filePath as NSString).lastPathComponent
        let lowercaseFile = filename.lowercased()
        _ = item.id.lowercased()
        _ = item.displayName.lowercased().replacingOccurrences(of: " ", with: "")

        let isDownloadFile = lowercaseFile.hasSuffix(".download") ||
                            lowercaseFile.hasSuffix(".pkg") ||
                            lowercaseFile.hasSuffix(".dmg")

        guard isDownloadFile else { return false }

        // Use smart matching for better detection
        return smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: filename)
    }
    
    private func updateAppStatus() {
        // Check for command file updates and direct filesystem status
        checkCommandFileForUpdates()
        checkDirectInstallationStatus()
    }
    
    private func checkCommandFileForUpdates() {
        let commandFilePath = InspectConstants.commandFilePath

        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            return
        }

        do {
            let content = try String(contentsOfFile: commandFilePath, encoding: .utf8)
            let currentSize = content.count

            // Only process if file has actually changed (byte-level check)
            guard currentSize != lastCommandFileSize else { return }

            // Filter empty lines before counting — trailing newlines from echo/append
            // produce empty strings that caused an off-by-one: lastProcessedLineCount
            // included the trailing "" element, so dropFirst() would skip real content.
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            let newLines = Array(lines.dropFirst(max(0, lastProcessedLineCount)))

            if !newLines.isEmpty {
                writeLog("InspectState: Processing \(newLines.count) new command lines", logLevel: .debug)

                for line in newLines {
                    parseCommandLine(line)
                }
            }

            lastCommandFileSize = currentSize
            lastProcessedLineCount = lines.count
            writeLog("InspectState: Command file updated (size: \(currentSize), lines: \(lines.count))", logLevel: .debug)
        } catch {
            writeLog("InspectState: Error reading command file: \(error)", logLevel: .error)
        }
    }
    
    private func checkDirectInstallationStatus() {
        // Direct filesystem check - this is our backup detection method
        guard !items.isEmpty else { return }
        
        var changesDetected = false
        
        for item in items {
            // Skip filesystem monitoring for items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                writeLog("InspectState: Skipping filesystem check for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            let wasCompleted = completedItems.contains(item.id)
            let wasDownloading = downloadingItems.contains(item.id)
            
            // Path checking - stop at first found path
            let fileExists = item.paths.first { path in
                FileManager.default.fileExists(atPath: path)
            } != nil

            // If item has plist validation (plistKey + evaluation), require it to pass
            // before marking as completed. This prevents items that monitor plist VALUES
            // (e.g., Dark Mode detection) from completing just because the plist file exists.
            let isInstalled: Bool
            if fileExists, let plistKey = item.plistKey, !plistKey.isEmpty, let evaluation = item.evaluation {
                // Read plist value directly (thread-safe, no actor isolation needed)
                let plistPath = item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? ""
                let expandedPath = (plistPath as NSString).expandingTildeInPath
                let actualValue: String?
                if item.useUserDefaults == true {
                    // UserDefaults-based read (faster for system preferences)
                    let domain = expandedPath.contains("/") ?
                        ((expandedPath as NSString).lastPathComponent as NSString).deletingPathExtension :
                        expandedPath
                    if domain == ".GlobalPreferences" {
                        actualValue = UserDefaults.standard.string(forKey: plistKey)
                    } else {
                        actualValue = UserDefaults(suiteName: domain)?.string(forKey: plistKey)
                    }
                } else if let plist = NSDictionary(contentsOfFile: expandedPath) {
                    actualValue = plist.value(forKeyPath: plistKey).map { String(describing: $0) }
                } else {
                    actualValue = nil
                }
                // Evaluate condition
                switch evaluation {
                case "changed":
                    // Change detection: record baseline on first check, complete when value differs
                    if !plistBaselinesInitialized.contains(item.id) {
                        plistBaselines[item.id] = actualValue
                        plistBaselinesInitialized.insert(item.id)
                        writeLog("InspectState: Plist baseline for \(item.id): \(actualValue ?? "nil")", logLevel: .debug)
                        isInstalled = false
                    } else {
                        let baseline = plistBaselines[item.id] ?? nil
                        let changed = (baseline != actualValue)
                        if changed {
                            writeLog("InspectState: Plist value changed for \(item.id): \(baseline ?? "nil") → \(actualValue ?? "nil")", logLevel: .info)
                        }
                        isInstalled = changed
                    }
                case "exists":
                    isInstalled = actualValue != nil && !actualValue!.isEmpty
                case "boolean":
                    isInstalled = actualValue == "1" || actualValue?.lowercased() == "true"
                case "contains":
                    isInstalled = actualValue?.contains(item.expectedValue ?? "") ?? false
                case "range":
                    if let actual = Int(actualValue ?? ""),
                       let parts = item.expectedValue?.split(separator: "-"),
                       parts.count == 2,
                       let lo = Int(parts[0]), let hi = Int(parts[1]) {
                        isInstalled = actual >= lo && actual <= hi
                    } else {
                        isInstalled = false
                    }
                default: // "equals"
                    isInstalled = actualValue == item.expectedValue
                }
            } else {
                isInstalled = fileExists
            }

            // Only check cache if not already installed (for performance optimization)
            let isDownloading = !isInstalled && checkCacheForItem(item)

            // Apply changes only if status actually changed
            if isInstalled && !wasCompleted {
                self.debouncedUpdater.debounce(key: "item-install-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    self.completedItems.insert(item.id)
                    self.downloadingItems.remove(item.id)
                    
                    // Check if this was the last item to complete
                    if self.completedItems.count == self.items.count {
                        writeLog("InspectState: All items completed - triggering button state update", logLevel: .info)
                        // Introduce a small delay to ensure UI state is updated
                        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay) { [weak self] in
                            self?.checkAndUpdateButtonState()
                        }
                    }
                }
                writeLog("InspectState: FILESYSTEM - \(item.displayName) detection completed", logLevel: .info)
                changesDetected = true

            } else if !isInstalled && wasCompleted {
                // App was installed but now deleted - check if still downloading
                if isDownloading {
                    self.debouncedUpdater.debounce(key: "item-download-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.insert(item.id)
                    }
                    writeLog("InspectState: FILESYSTEM - \(item.displayName) deleted but still downloading", logLevel: .info)
                } else {
                    self.debouncedUpdater.debounce(key: "item-remove-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.remove(item.id)
                    }
                    writeLog("InspectState: FILESYSTEM - \(item.displayName) deleted, reset to pending", logLevel: .info)
                }
                changesDetected = true

            } else if isDownloading && !wasDownloading {
                self.debouncedUpdater.debounce(key: "item-downloading-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    self.downloadingItems.insert(item.id)
                    writeLog("InspectState: Added \(item.id) to downloadingItems (cache detected)", logLevel: .info)
                }
                writeLog("InspectState: FILESYSTEM - \(item.displayName) downloading", logLevel: .info)
                changesDetected = true
                
            } else if !isDownloading && !isInstalled && (wasDownloading || wasCompleted) {
                // Simplified state management - single source of truth
                // Only reset to pending if cache file doesn't exist AND logMonitor
                // doesn't have an active status for this item (logMonitor is authoritative
                // for download/install state, especially with itemIds routing)
                let hasLogMonitorStatus = self.logMonitorStatuses[item.id] != nil
                if !checkCacheForItem(item) && !hasLogMonitorStatus {
                    self.debouncedUpdater.debounce(key: "item-pending-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.downloadingItems.remove(item.id)
                        self.completedItems.remove(item.id)
                        // Clear any tracking timestamps
                        self.fsEventsTimestamps.removeValue(forKey: item.id)
                        writeLog("InspectState: \(item.displayName) reset to pending (no cache file)", logLevel: .info)
                    }
                }
                changesDetected = true
            }
        }
        
        if changesDetected {
            writeLog("InspectState: Filesystem check detected status changes", logLevel: .debug)
        }
    }
    
    private func loadAppInspectConfig(config: InspectConfig, originalPath: String) {
        // Convert InspectConfig to AppInspector.AppConfig format
        // TODO: Consolidate this with AppInspector/AppInspectorConfig structures
        do {
            // Create AppInspector compatible structure
            let appInspectorApps = config.items.map { item in
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
            
            // Convert to JSON data and write to a temporary file for AppInspector to load
            let jsonData = try JSONSerialization.data(withJSONObject: appInspectConfig, options: [])
            let tempConfigPath = InspectConstants.tempConfigPath
            try jsonData.write(to: URL(fileURLWithPath: tempConfigPath))
            
            // Load the converted config into AppInspector
            appInspector?.loadConfig(from: tempConfigPath)
            
            // Start AppInspector filesystem monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appInspector?.start()
                writeLog("InspectState: AppInspector filesystem monitoring started", logLevel: .info)
            }
            
            writeLog("InspectState: Successfully converted and loaded config for AppInspector", logLevel: .info)
            
        } catch {
            writeLog("InspectState: Failed to convert config for AppInspector: \(error)", logLevel: .error)
        }
    }
    
    private func checkCacheForItem(_ item: InspectConfig.ItemConfig) -> Bool {
        guard let config = config, let cachePaths = config.cachePaths else { return false }

        writeLog("InspectState: Checking cache for item '\(item.id)' (display: '\(item.displayName)')", logLevel: .debug)

        // Use the optimized containsMatchingFile method to avoid unnecessary memory allocations
        for cachePath in cachePaths {
            // ALWAYS invalidate and re-read the cache to ensure we have fresh data
            fileSystemCache.invalidateCache(for: cachePath)
            let cacheContents = fileSystemCache.cacheDirectoryContents(cachePath)

            // Log what's actually in the cache for debugging
            if cacheContents.isEmpty {
                writeLog("InspectState:   Cache directory '\(cachePath)' is empty", logLevel: .debug)
            } else {
                writeLog("InspectState:   Files in cache (\(cacheContents.count) total): \(cacheContents.prefix(3).joined(separator: ", "))\(cacheContents.count > 3 ? "..." : "")", logLevel: .debug)
            }

            // Filter for download files
            let downloadFiles = cacheContents.filter { file in
                // Skip hidden files like .DS_Store
                guard !file.hasPrefix(".") else { return false }

                return file.lowercased().hasSuffix(".download") ||
                       file.lowercased().hasSuffix(".pkg") ||
                       file.lowercased().hasSuffix(".dmg")
            }

            if downloadFiles.isEmpty {
                writeLog("InspectState:   No package files found (looked for .pkg, .dmg, .download)", logLevel: .debug)
            } else {
                for file in downloadFiles {
                    writeLog("InspectState:   Found package: '\(file)'", logLevel: .debug)
                }
            }

            // Now check if any match this item
            let hasMatchingFile = downloadFiles.contains { file in
                let matches = smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: file)

                if matches {
                    writeLog("InspectState:   ✓ SMART MATCH: '\(file)' matches item '\(item.id)'", logLevel: .info)
                } else {
                    writeLog("InspectState:   ✗ No match: '\(file)' vs item '\(item.id)'", logLevel: .debug)
                }

                return matches
            }

            if hasMatchingFile {
                writeLog("InspectState: ✓ Cache match found for '\(item.id)' in \(cachePath)", logLevel: .info)
                return true
            }
        }
        writeLog("InspectState: No cache match for '\(item.id)'", logLevel: .debug)
        return false
    }

    /// Smart filename matching algorithm for package cache detection
    /// Handles cases like: microsoft_outlook → Microsoft_Outlook_16.101.25091314_Installer.pkg
    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        let cleanFilename = filename.lowercased()
        let cleanItemId = itemId.lowercased()
        let cleanDisplayName = displayName.lowercased().replacingOccurrences(of: " ", with: "")

        // Additional normalization: also remove underscores from display name for better matching
        let cleanDisplayNameNoUnderscore = displayName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Strategy 1: Direct substring match (current approach - fast path)
        let strategy1Match = cleanFilename.contains(cleanItemId) ||
                           cleanFilename.contains(cleanDisplayName) ||
                           cleanFilename.contains(cleanDisplayNameNoUnderscore)
        if strategy1Match {
            writeLog("InspectState:     ✓ Strategy 1 match: '\(filename)' matched", logLevel: .info)
            return true
        }

        // Strategy 2: Split and match components (handle underscores/spaces)
        // microsoft_outlook → ["microsoft", "outlook"]
        let itemComponents = cleanItemId.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }  // Filter out small words

        let displayComponents = cleanDisplayName.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }

        // Check if all significant components from item ID are present in filename
        let allItemComponentsMatch = !itemComponents.isEmpty && itemComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        let allDisplayComponentsMatch = !displayComponents.isEmpty && displayComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        let strategy2Match = allItemComponentsMatch || allDisplayComponentsMatch
        if strategy2Match {
            writeLog("InspectState:     ✓ Strategy 2 match: '\(filename)' component match", logLevel: .info)
            return true
        }

        // Strategy 3: Handle common patterns
        // microsoft_outlook → microsoftoutlook, microsoft.outlook, Microsoft_Outlook, etc.
        let condensedItemId = cleanItemId.replacingOccurrences(of: "_", with: "")
        let condensedDisplayName = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        let strategy3Match = cleanFilename.contains(condensedItemId) || cleanFilename.contains(condensedDisplayName)
        if strategy3Match {
            writeLog("InspectState:     ✓ Strategy 3 match: '\(filename)' contains condensed form", logLevel: .debug)
            return true
        }

        // Strategy 4: Fuzzy matching for brand names
        // Handle cases where "microsoft_office" should match "Office_365" packages
        if let primaryComponent = itemComponents.first, primaryComponent.count >= 4 {
            // For microsoft_*, look for the main app name (second component)
            if primaryComponent == "microsoft" && itemComponents.count > 1 {
                let appName = itemComponents[1]
                let strategy4Match = cleanFilename.contains(appName)
                if strategy4Match {
                    writeLog("InspectState:     ✓ Strategy 4 match: '\(filename)' contains app name '\(appName)'", logLevel: .debug)
                    return true
                }
            }
        }

        // No match found - only log this at debug level
        return false
    }

    private func fsEventsRecentlyDetected(_ itemId: String) -> Bool {
        guard let timestamp = fsEventsTimestamps[itemId] else { return false }
        return Date().timeIntervalSince(timestamp) < fsEventsPriorityWindow
    }
    
    /// This works but might be a bit solved too complex - 
    private func parseCommandLine(_ line: String) {
        // Enhanced parsing to handle multiple command formats from AppInspector
        writeLog("InspectState: Parsing command line: \(line)", logLevel: .debug)

        // Format 2: "item:itemId:status" or "item:itemId:status:message"
        // This is the modern format that works with both Preset 1 and Preset 5
        if line.hasPrefix("item:") {
            let parts = line.dropFirst(5).split(separator: ":", maxSplits: 2)
            guard parts.count >= 2 else {
                writeLog("InspectState: Invalid item command format: \(line)", logLevel: .error)
                return
            }
            let itemId = String(parts[0])
            let status = String(parts[1]).lowercased()
            let message = parts.count > 2 ? String(parts[2]) : nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch status {
                case "pending":
                    self.completedItems.remove(itemId)
                    self.downloadingItems.remove(itemId)
                    self.failedItems.remove(itemId)
                case "downloading", "installing":
                    self.downloadingItems.insert(itemId)
                    self.completedItems.remove(itemId)
                    self.failedItems.remove(itemId)
                case "success", "completed":
                    self.completedItems.insert(itemId)
                    self.downloadingItems.remove(itemId)
                    self.failedItems.remove(itemId)
                    // Check if all items now complete — enable button if autoEnableButton is on
                    if self.completedItems.count == self.items.count {
                        self.checkAndUpdateButtonState()
                    }
                case "failed", "error":
                    self.failedItems.insert(itemId)
                    self.downloadingItems.remove(itemId)
                default:
                    writeLog("InspectState: Unknown item status '\(status)' for '\(itemId)'", logLevel: .debug)
                    return
                }
                if let message = message {
                    self.logMonitorStatuses[itemId] = message
                }
                writeLog("InspectState: Item '\(itemId)' → \(status)\(message.map { ": \($0)" } ?? "")", logLevel: .info)
            }
            return
        }

        // Format 1: "listitem: index: X, status: Y, statustext: Z" (legacy)
        var appIndex: Int?
        var status: String?
        var statusText: String?

        if let indexRange = line.range(of: "index: "),
           let commaRange = line.range(of: ",", range: indexRange.upperBound..<line.endIndex) {
            let indexStr = String(line[indexRange.upperBound..<commaRange.lowerBound])
            appIndex = Int(indexStr)
        }

        // Extract status
        if let statusRange = line.range(of: "status: "),
           let nextCommaRange = line.range(of: ",", range: statusRange.upperBound..<line.endIndex) {
            status = String(line[statusRange.upperBound..<nextCommaRange.lowerBound])
        } else if let statusRange = line.range(of: "status: ") {
            status = String(line[statusRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract status text
        if let statusTextRange = line.range(of: "statustext: ") {
            statusText = String(line[statusTextRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Apply updates based on parsed information
        guard let index = appIndex, index < items.count else {
            writeLog("InspectState: Invalid or missing index in command: \(line)", logLevel: .debug)
            return
        }

        let app = items[index]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let status = status {
                switch status.lowercased() {
                case "success":
                    self.completedItems.insert(app.id)
                    self.downloadingItems.remove(app.id)
                    self.failedItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) completed (from command)", logLevel: .info)
                case "wait":
                    self.downloadingItems.insert(app.id)
                    writeLog("InspectState: \(app.displayName) downloading (from command)", logLevel: .info)
                case "pending":
                    self.downloadingItems.remove(app.id)
                    self.completedItems.remove(app.id)
                    self.failedItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) pending (from command)", logLevel: .info)
                case "fail", "error":
                    self.failedItems.insert(app.id)
                    self.downloadingItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) failed (from command)", logLevel: .info)
                default:
                    writeLog("InspectState: Unknown status '\(status)' for \(app.displayName)", logLevel: .debug)
                }
            }

            if let statusText = statusText {
                self.logMonitorStatuses[app.id] = statusText
            }
        }
    }
    
    private func startSideMessageRotation(interval: TimeInterval) {
        // Stop existing timer if any
        sideMessageTimer?.invalidate()

        writeLog("InspectState: Starting side message rotation with \(uiConfiguration.sideMessages.count) messages, interval: \(interval)s", logLevel: .info)

        // Start new timer - ensure it runs on the main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.sideMessageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, self.uiConfiguration.sideMessages.count > 1 else {
                    writeLog("InspectState: Timer fired but no messages to rotate (count: \(self?.uiConfiguration.sideMessages.count ?? 0))", logLevel: .debug)
                    return
                }

                self.uiConfiguration.currentSideMessageIndex = (self.uiConfiguration.currentSideMessageIndex + 1) % self.uiConfiguration.sideMessages.count
                writeLog("InspectState: Rotated to side message index \(self.uiConfiguration.currentSideMessageIndex) of \(self.uiConfiguration.sideMessages.count)", logLevel: .info)
            }

            // Also fire immediately to start rotation
            if self.uiConfiguration.sideMessages.count > 1 {
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    writeLog("InspectState: Initial rotation trigger", logLevel: .info)
                }
            }
        }

        writeLog("InspectState: Side message rotation timer configured", logLevel: .info)
    }
    
    func getCurrentSideMessage() -> String? {
        guard !uiConfiguration.sideMessages.isEmpty else { return nil }
        let index = min(uiConfiguration.currentSideMessageIndex, uiConfiguration.sideMessages.count - 1)
        return uiConfiguration.sideMessages[index]
    }
    
    /// Create a sample Preset 5 configuration file and print launch instructions.
    /// Called automatically in `.testData` mode. Writes a 3-step workflow
    /// (intro → bento → deployment) using only SF Symbols — no external assets needed.
    func createSampleConfiguration() {
        // Only works in test data mode
        guard configurationSource == .testData else {
            writeLog("InspectState: createSampleConfiguration called but not in test mode", logLevel: .debug)
            return
        }

        let sampleConfig = """
        {
            "preset": "5",
            "width": 1000,
            "height": 650,
            "highlightColor": "#007AFF",
            "showAccentBorder": false,
            "introSteps": [
                {
                    "id": "welcome",
                    "stepType": "intro",
                    "title": "swiftDialog — Inspect Mode",
                    "subtitle": "A sample configuration to get you started.",
                    "heroImage": "SF=macbook.gen2",
                    "heroImageSize": 180,
                    "content": [
                        {
                            "type": "text",
                            "content": "This is a Preset 5 workflow. Each step uses a different layout — intro, bento grid, and deployment — to demonstrate what's possible."
                        }
                    ],
                    "continueButtonText": "Explore",
                    "showBackButton": false
                },
                {
                    "id": "presets-overview",
                    "stepType": "bento",
                    "bentoLayout": "grid",
                    "title": "6 Preset Layouts",
                    "subtitle": "Tap any card to learn more",
                    "bentoColumns": 3,
                    "bentoRowHeight": 140,
                    "bentoGap": 12,
                    "bentoCells": [
                        {
                            "id": "preset1",
                            "column": 0, "row": 0, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "sidebar.leading",
                            "iconSize": 36,
                            "title": "Preset 1",
                            "label": "DEPLOYMENT",
                            "detailOverlay": {
                                "title": "Preset 1 — Deployment",
                                "subtitle": "Sidebar + scrollable item list",
                                "icon": "sidebar.leading",
                                "content": [
                                    { "type": "text", "content": "The classic deployment layout. A sidebar shows a hero icon and overall progress, while the main area lists items with real-time status updates." },
                                    { "type": "bullets", "items": ["Sidebar with hero icon and progress bar", "Scrollable item list with status indicators", "File-system monitoring via paths array", "Rotating status messages"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "1", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset2",
                            "column": 1, "row": 0, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "rectangle.split.3x1",
                            "iconSize": 36,
                            "title": "Preset 2",
                            "label": "CARDS",
                            "detailOverlay": {
                                "title": "Preset 2 — Cards",
                                "subtitle": "Horizontal card carousel",
                                "icon": "rectangle.split.3x1",
                                "content": [
                                    { "type": "text", "content": "Items displayed as cards in a horizontal carousel. Great for visual app catalogs where each card shows an icon, name, and install status." },
                                    { "type": "bullets", "items": ["Horizontal scrolling card layout", "Large app icons with status badges", "Progress bar across the top", "Auto-advances on completion"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "2", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset3",
                            "column": 2, "row": 0, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "list.bullet.rectangle",
                            "iconSize": 36,
                            "title": "Preset 3",
                            "label": "COMPACT",
                            "detailOverlay": {
                                "title": "Preset 3 — Compact",
                                "subtitle": "Compact list with gradient background",
                                "icon": "list.bullet.rectangle",
                                "content": [
                                    { "type": "text", "content": "A space-efficient list layout with a gradient background. Ideal for quick installations where you want minimal screen footprint." },
                                    { "type": "bullets", "items": ["Compact item rows", "Gradient background from brand colors", "Small window footprint", "Clean, minimal design"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "3", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset4",
                            "column": 0, "row": 1, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "bell.badge",
                            "iconSize": 36,
                            "title": "Preset 4",
                            "label": "TOAST",
                            "detailOverlay": {
                                "title": "Preset 4 — Toast Installer",
                                "subtitle": "Compact notification-style installer",
                                "icon": "bell.badge",
                                "content": [
                                    { "type": "text", "content": "A small, unobtrusive toast notification that tracks installations in the corner of the screen. Stays out of the user's way." },
                                    { "type": "bullets", "items": ["Notification-sized window", "Corner-anchored positioning", "Progress tracking with minimal UI", "Non-intrusive for background installs"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "4", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset5",
                            "column": 1, "row": 1, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "macwindow.on.rectangle",
                            "iconSize": 36,
                            "title": "Preset 5",
                            "label": "UNIFIED",
                            "detailOverlay": {
                                "title": "Preset 5 — Unified Portal",
                                "subtitle": "The most flexible preset (this sample)",
                                "icon": "macwindow.on.rectangle",
                                "content": [
                                    { "type": "text", "content": "A multi-step wizard with 9 step types. Combine intro screens, bento grids, deployment tracking, carousels, guides, and more in a single workflow." },
                                    { "type": "bullets", "items": ["9 step types: intro, bento, deployment, carousel, guide, showcase, portal, processing, outro", "Linear navigation with back/continue", "55+ content block types", "Branding, forms, compliance checks"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "5", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset6",
                            "column": 2, "row": 1, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "sidebar.squares.leading",
                            "iconSize": 36,
                            "title": "Preset 6",
                            "label": "GUIDANCE",
                            "detailOverlay": {
                                "title": "Preset 6 — Modern Sidebar",
                                "subtitle": "Sidebar navigation with guided content",
                                "icon": "sidebar.squares.leading",
                                "content": [
                                    { "type": "text", "content": "A modern sidebar navigation layout. Users can jump between sections freely rather than following a linear path." },
                                    { "type": "bullets", "items": ["Sidebar with section navigation", "Non-linear — jump to any section", "Rich guidance content per section", "Great for self-service portals"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "6", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        }
                    ],
                    "continueButtonText": "Continue",
                    "backButtonText": "Back"
                },
                {
                    "id": "apps",
                    "stepType": "deployment",
                    "title": "App Installation",
                    "subtitle": "Simulated deployment step with progress tracking.",
                    "heroImage": "SF=arrow.down.app.fill",
                    "items": [
                        { "id": "word", "displayName": "Microsoft Word", "guiIndex": 0, "icon": "/Applications/Microsoft Word.app", "paths": ["/Applications/Microsoft Word.app"], "showBundleInfo": "all" },
                        { "id": "excel", "displayName": "Microsoft Excel", "guiIndex": 1, "icon": "/Applications/Microsoft Excel.app", "paths": ["/Applications/Microsoft Excel.app"], "showBundleInfo": "all" },
                        { "id": "1password", "displayName": "1Password", "guiIndex": 2, "icon": "/Applications/1Password.app", "paths": ["/Applications/1Password.app"], "showBundleInfo": "all" },
                        { "id": "slack", "displayName": "Slack", "guiIndex": 3, "icon": "/Applications/Slack.app", "paths": ["/Applications/Slack.app"], "showBundleInfo": "all" },
                        { "id": "chrome", "displayName": "Google Chrome", "guiIndex": 4, "icon": "/Applications/Google Chrome.app", "paths": ["/Applications/Google Chrome.app"], "showBundleInfo": "all" }
                    ],
                    "autoEnableButton": false,
                    "allowOverride": true,
                    "continueButtonText": "Finish",
                    "showBackButton": true
                }
            ]
        }
        """

        let configPath = NSTemporaryDirectory() + "inspect-config-sample.json"
        let divider = String(repeating: "━", count: 66)

        do {
            try sampleConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
            writeLog("InspectState: Sample configuration created at: \(configPath)", logLevel: .info)

            print("")
            print(divider)
            print("  Sample Configuration Created")
            print(divider)
            print("")
            print("  ✓ Preset: 5 (unified)")
            print("  ✓ Steps:  3 (intro → bento → deployment)")
            print("  ✓ File:   \(configPath)")
            print("")
            print("  Launch it:")
            print("  → dialog --inspect-config \"\(configPath)\" --inspect-mode")
            print("")
            print("  Or copy and customize:")
            print("  → cp \"\(configPath)\" ~/Desktop/my-config.json")
            print("")
            print(divider)
            print("")

            // Exit with special code to indicate config was created
            exit(10)
        } catch {
            writeLog("InspectState: Failed to create sample configuration: \(error)", logLevel: .error)
        }
    }

    /// For best UX, especially in Enrollment scenarios - check if all apps are completed and update button state accordingly
    func checkAndUpdateButtonState() {
        let totalApps = items.count
        let completedCount = completedItems.count
        
        writeLog("InspectState: Button state check - Total: \(totalApps), Completed: \(completedCount), AutoEnable: \(buttonConfiguration.autoEnableButton)", logLevel: .info)
        
        // If all apps are completed
        if totalApps > 0 && completedCount == totalApps {
            writeLog("InspectState: All apps completed (\(completedCount)/\(totalApps))", logLevel: .info)
            
            // Validate all completed items to ensure plist validation results are up-to-date
            Task { @MainActor in
                let completedItemsToValidate = items.filter { completedItems.contains($0.id) }
                writeLog("InspectState: Re-validating \(completedItemsToValidate.count) completed items for button state update", logLevel: .info)
                
                for item in completedItemsToValidate {
                    if item.plistKey != nil || plistSources?.contains(where: { source in
                        item.paths.contains(source.path)
                    }) == true {
                        let isValid = validatePlistItem(item)
                        writeLog("InspectState: Re-validated completed item '\(item.id)': \(isValid)", logLevel: .info)
                    }
                }
            }
            
            // Update button state directly since InspectView uses independent state management
            DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay) { [weak self] in
                guard let self = self else { return }
                if self.buttonConfiguration.autoEnableButton {
                    self.buttonConfiguration.button1Text = self.config?.autoEnableButtonText ?? "OK"
                    self.buttonConfiguration.button1Disabled = false
                    writeLog("InspectState: Auto-enabling button with text: \(self.buttonConfiguration.button1Text)", logLevel: .info)
                }
            }
        }
    }
    
    // MARK: - Unified Plist Validation

    /// TODO: this can be build better, however plist are oftentime pretty complex, our actual at least works for the current use cases tested
    
    @MainActor
    func validatePlistItem(_ item: InspectConfig.ItemConfig) -> Bool {
        writeLog("InspectState: validatePlistItem called for '\(item.id)' (\(item.displayName))", logLevel: .info)
        writeLog("InspectState: Item details - plistKey: '\(item.plistKey ?? "nil")', expectedValue: '\(item.expectedValue ?? "nil")', evaluation: '\(item.evaluation ?? "nil")'", logLevel: .info)
        writeLog("InspectState: Item paths: \(item.paths)", logLevel: .info)
        writeLog("InspectState: iconBasePath for relative path resolution: \(uiConfiguration.iconBasePath ?? "nil")", logLevel: .info)

        // Use validation service for all validation logic
        // Pass iconBasePath to allow resolution of relative paths in item.paths
        let request = ValidationRequest(
            item: item,
            plistSources: plistSources,
            basePath: uiConfiguration.iconBasePath
        )

        let result = Validation.shared.validateItem(request)
        
        // Cache the result for UI consistency
        plistValidationResults[item.id] = result.isValid
        
        writeLog("InspectState: Validation result for '\(item.id)': isValid=\(result.isValid), type=\(result.validationType)", logLevel: .info)
        
        // Log validation details for debugging
        if let details = result.details {
            writeLog("InspectState: Validation details - Path: \(details.path), Key: \(details.key ?? "N/A"), Expected: \(details.expectedValue ?? "N/A"), Actual: \(details.actualValue ?? "N/A"), EvalType: \(details.evaluationType ?? "N/A")", logLevel: .info)
        } else {
            writeLog("InspectState: No validation details available for '\(item.id)'", logLevel: .info)
        }
        
        return result.isValid
    }
    
    // MARK: - Validation Initialization
    
    /// Validate all items to populate the validation results dictionary
    /// ✅ FIXED: Now uses modern Swift Concurrency instead of DispatchSemaphore
    /// This eliminates potential deadlocks and silent crashes in production builds
    func validateAllItems() {
        writeLog("InspectState: Starting async validation of \(items.count) items", logLevel: .info)

        // RING BUFFER: Sort items by category so cards complete in visual order (top-to-bottom)
        // This creates a smoother loading UX where each category card completes before the next
        let sortedItems = items.sorted { item1, item2 in
            let cat1 = item1.category ?? getCategoryPrefix(item1.id)
            let cat2 = item2.category ?? getCategoryPrefix(item2.id)
            return cat1 < cat2
        }

        // Log each item being validated (in sorted order)
        for item in sortedItems {
            writeLog("InspectState: Will validate item '\(item.id)' - plistKey: '\(item.plistKey ?? "nil")', expectedValue: '\(item.expectedValue ?? "nil")', evaluation: '\(item.evaluation ?? "nil")'", logLevel: .debug)
        }

        // Use STREAMING validation for per-card progressive updates
        // Each result is emitted immediately, triggering Preset5's onChange handler
        Task { @MainActor in
            Validation.shared.validateItemsBatchStreaming(
                sortedItems,
                plistSources: self.plistSources,
                onPreCacheProgress: { [weak self] loaded, total in
                    // Update pre-cache progress for "Loading configuration files..." indicator
                    self?.preCacheProgress = (loaded, total)
                },
                onItemValidated: { [weak self] itemId, isValid in
                    // Clear pre-cache progress once validation starts
                    if self?.preCacheProgress != nil {
                        self?.preCacheProgress = nil
                    }
                    // STREAM: Update dictionary immediately for each result
                    // This triggers onChange in Preset5View for per-card progress
                    self?.plistValidationResults[itemId] = isValid
                },
                completion: { [weak self] results in
                    guard let self = self else { return }
                    writeLog("InspectState: Streaming validation complete. \(results.filter { $0.value }.count) valid items out of \(results.count) total", logLevel: .info)

                    // Just clear pre-cache state - no objectWillChange.send() needed
                    // The streaming updates already triggered all necessary UI refreshes
                    self.preCacheProgress = nil
                }
            )
        }
    }

    /// Extract category prefix from item ID (e.g., "os_gatekeeper_enable" → "os")
    /// Used for ring buffer sorting when no explicit category is set
    private func getCategoryPrefix(_ itemId: String) -> String {
        // Common prefixes used in mSCP/NIST compliance rules
        let parts = itemId.components(separatedBy: "_")
        if let first = parts.first, !first.isEmpty {
            return first.lowercased()
        }
        return itemId
    }

    // NEW: Get actual plist value for display purposes
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

    // MARK: - Plist Monitoring Methods - Generalized from Preset6

    /// Start monitoring a plist value with periodic rechecks
    /// - Parameters:
    ///   - itemId: Unique identifier for the monitoring task
    ///   - item: Item configuration containing plist details
    ///   - recheckInterval: Seconds between checks (1-3600)
    ///   - onValueChanged: Callback when value changes (oldValue, newValue)
    nonisolated func startPlistMonitoring(
        itemId: String,
        item: InspectConfig.ItemConfig,
        recheckInterval: Int,
        onValueChanged: @escaping (String, String) -> Void
    ) {
        guard let plistKey = item.plistKey, recheckInterval > 0 else {
            writeLog("InspectState: Cannot start monitoring for '\(itemId)' - missing plistKey or invalid interval", logLevel: .error)
            return
        }

        // Validate interval range
        guard recheckInterval >= 1 && recheckInterval <= 3600 else {
            writeLog("InspectState: Invalid recheckInterval \(recheckInterval) for '\(itemId)', must be 1-3600", logLevel: .error)
            return
        }

        // Stop existing monitor if any
        Task { @MainActor in
            self.stopPlistMonitoring(itemId: itemId)
        }

        // Determine reading method based on useUserDefaults flag 
        let useUserDefaults = item.useUserDefaults == true
        let readingMethod = useUserDefaults ? "UserDefaults" : "file"

        // Capture initial value from main actor context
        Task { @MainActor in
            // Get initial value using appropriate method
            let initialValue: String
            if useUserDefaults {
                // Extract domain for UserDefaults reading
                guard let path = item.paths.first,
                      let domain = Validation.shared.extractDomainFromPath(path) else {
                    writeLog("InspectState: Cannot extract UserDefaults domain from path for '\(itemId)'", logLevel: .error)
                    return
                }
                initialValue = Validation.shared.getUserDefaultsValue(domain: domain, key: plistKey) ?? "(not set)"
                writeLog("InspectState: Starting plist monitoring (UserDefaults) for '\(itemId)' - initial: \(initialValue), interval: \(recheckInterval)s", logLevel: .info)
            } else {
                initialValue = self.getPlistValueForDisplay(item: item) ?? "(not set)"
                writeLog("InspectState: Starting plist monitoring (file) for '\(itemId)' - initial: \(initialValue), interval: \(recheckInterval)s", logLevel: .info)
            }

            // Start periodic recheck timer (same for both methods)
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(recheckInterval), repeats: true) { [weak self] _ in
                guard let self = self else { return }

                // Access main actor-isolated methods from main actor context
                Task { @MainActor in
                    // Get current value using same method as initial
                    let currentValue: String
                    if useUserDefaults {
                        guard let path = item.paths.first,
                              let domain = Validation.shared.extractDomainFromPath(path) else {
                            return
                        }
                        currentValue = Validation.shared.getUserDefaultsValue(domain: domain, key: plistKey) ?? "(not set)"
                    } else {
                        currentValue = self.getPlistValueForDisplay(item: item) ?? "(not set)"
                    }

                    // Check if value changed from initial
                    if currentValue != initialValue {
                        writeLog("InspectState: Plist value changed (\(readingMethod)) for '\(itemId)': \(initialValue) → \(currentValue)", logLevel: .info)

                        // Notify callback
                        onValueChanged(initialValue, currentValue)

                        // Stop monitoring after change detected
                        self.stopPlistMonitoring(itemId: itemId)
                    }
                }
            }

            // Store monitoring task
            self.plistMonitors[itemId] = PlistMonitorTask(
                timer: timer,
                initialValue: initialValue,
                currentValue: initialValue,
                recheckInterval: recheckInterval
            )
        }
    }

    /// Stop monitoring a specific plist item
    /// - Parameter itemId: The item to stop monitoring
    func stopPlistMonitoring(itemId: String) {
        guard let monitor = plistMonitors[itemId] else { return }

        monitor.timer.invalidate()
        plistMonitors.removeValue(forKey: itemId)
        writeLog("InspectState: Stopped plist monitoring for '\(itemId)'", logLevel: .info)
    }

    /// Stop all active plist monitors (cleanup)
    func stopAllPlistMonitors() {
        for (itemId, monitor) in plistMonitors {
            monitor.timer.invalidate()
            writeLog("InspectState: Stopped plist monitoring for '\(itemId)'", logLevel: .debug)
        }
        plistMonitors.removeAll()
    }

    // MARK: - Multiple Plist Monitors

    /// Start multiple plist monitors for an item that auto-update guidance components
    /// - Parameters:
    ///   - item: The item configuration containing plistMonitors array
    ///   - onUpdate: Callback triggered when plist value changes (receives: itemId, guidanceBlockIndex, targetProperty, newValue)
    func startMultiplePlistMonitors(
        for item: InspectConfig.ItemConfig,
        onUpdate: @escaping (String, Int, String, String) -> Void,
        onComplete: @escaping (String, InspectCompletionResult, String?) -> Void
    ) {
        guard let monitors = item.plistMonitors, !monitors.isEmpty else {
            return
        }

        let itemId = item.id
        writeLog("InspectState: Starting \(monitors.count) plist monitor(s) for '\(itemId)'", logLevel: .info)

        for (monitorIndex, monitor) in monitors.enumerated() {
            // Validate interval
            guard monitor.recheckInterval >= 1 && monitor.recheckInterval <= 3600 else {
                writeLog("InspectState: Invalid recheckInterval \(monitor.recheckInterval) for monitor \(monitorIndex) in '\(itemId)'", logLevel: .error)
                continue
            }

            // Create unique monitor key
            let monitorKey = "\(itemId)_monitor_\(monitorIndex)"

            // Determine reading method
            let useUserDefaults = monitor.useUserDefaults == true

            // Start monitoring on main actor
            Task { @MainActor in
                // Stop existing monitor if any
                if let existingMonitor = self.plistMonitors[monitorKey] {
                    existingMonitor.timer.invalidate()
                    self.plistMonitors.removeValue(forKey: monitorKey)
                }

                // Read initial value
                let initialValue = self.readPlistMonitorValue(monitor: monitor, useUserDefaults: useUserDefaults)

                writeLog("InspectState: Monitor \(monitorIndex) for '\(itemId)' - path: \(monitor.path), key: \(monitor.key), initial: \(initialValue), interval: \(monitor.recheckInterval)s", logLevel: .info)

                // Trigger initial UI update with the current value
                let mappedInitialValue = monitor.valueMap?[initialValue] ?? initialValue
                onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedInitialValue)
                writeLog("InspectState: Monitor \(monitorIndex) set initial value for '\(itemId)': \(mappedInitialValue)", logLevel: .info)

                // If there's a completion trigger, also update the 'state' property based on initial evaluation
                if let trigger = monitor.completionTrigger {
                    let conditionMet = self.evaluateTriggerCondition(
                        condition: trigger.condition,
                        currentValue: initialValue,
                        expectedValue: trigger.value
                    )
                    let stateValue = conditionMet ? "pass" : "fail"
                    onUpdate(itemId, monitor.guidanceBlockIndex, "state", stateValue)
                    writeLog("InspectState: Monitor \(monitorIndex) set initial state for '\(itemId)': \(stateValue) (condition: \(trigger.condition))", logLevel: .info)
                }

                // Start periodic timer
                let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(monitor.recheckInterval), repeats: true) { [weak self] _ in
                    guard let self = self else { return }

                    Task { @MainActor in
                        // Read current value
                        let currentValue = self.readPlistMonitorValue(monitor: monitor, useUserDefaults: useUserDefaults)

                        // Get the last known value from stored monitor (not initialValue!)
                        let lastValue = self.plistMonitors[monitorKey]?.currentValue ?? initialValue

                        // Check if value changed from last known value
                        if currentValue != lastValue {
                            writeLog("InspectState: Monitor \(monitorIndex) detected change for '\(itemId)': \(lastValue) → \(currentValue)", logLevel: .info)

                            // Apply value mapping if defined
                            let mappedValue = monitor.valueMap?[currentValue] ?? currentValue

                            // Trigger callback with update info
                            onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedValue)

                            // Check for completion trigger and update state
                            if let trigger = monitor.completionTrigger {
                                let conditionMet = self.evaluateTriggerCondition(
                                    condition: trigger.condition,
                                    currentValue: currentValue,
                                    expectedValue: trigger.value
                                )

                                // Always update state based on condition result
                                let stateValue = conditionMet ? "pass" : "fail"
                                onUpdate(itemId, monitor.guidanceBlockIndex, "state", stateValue)
                                writeLog("InspectState: Monitor updated state for '\(itemId)': \(stateValue)", logLevel: .debug)

                                if conditionMet {
                                    writeLog("InspectState: Completion trigger met for '\(itemId)' - condition: \(trigger.condition), result: \(trigger.result)", logLevel: .info)

                                    let result: InspectCompletionResult = trigger.result.lowercased() == "success"
                                        ? .success(message: trigger.message)
                                        : .failure(message: trigger.message)

                                    let delay = trigger.delay ?? 0.0

                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        onComplete(itemId, result, trigger.message)
                                    }
                                }
                            }

                            // Update stored current value
                            if let storedMonitor = self.plistMonitors[monitorKey] {
                                self.plistMonitors[monitorKey] = PlistMonitorTask(
                                    timer: storedMonitor.timer,
                                    initialValue: storedMonitor.initialValue,
                                    currentValue: currentValue,
                                    recheckInterval: storedMonitor.recheckInterval
                                )
                            }
                        }
                    }
                }

                // Store monitor task
                self.plistMonitors[monitorKey] = PlistMonitorTask(
                    timer: timer,
                    initialValue: initialValue,
                    currentValue: initialValue,
                    recheckInterval: monitor.recheckInterval
                )
            }
        }
    }

    /// Read plist value for a monitor configuration
    /// - Parameters:
    ///   - monitor: The plist monitor configuration
    ///   - useUserDefaults: Whether to use UserDefaults reading
    /// - Returns: String representation of the plist value
    @MainActor
    private func readPlistMonitorValue(monitor: InspectConfig.PlistMonitor, useUserDefaults: Bool) -> String {
        // Handle "exists" evaluation - check file presence instead of reading value
        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            // If file exists, read the actual value to display (e.g., timestamp)
            if fileExists {
                if useUserDefaults {
                    // Use full path support - pathOrDomain detects if it's a full path
                    return Validation.shared.getUserDefaultsValue(pathOrDomain: monitor.path, key: monitor.key) ?? "Present"
                } else {
                    return Validation.shared.getPlistValue(path: monitor.path, key: monitor.key) ?? "Present"
                }
            } else {
                return "Not detected"
            }
        }

        // Handle "notExists" evaluation - pass when file/path does NOT exist
        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "notexists" || evaluation == "not_exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            if fileExists {
                return "Present"  // File exists = fail condition for notExists
            } else {
                return "Not detected"  // File doesn't exist = pass condition for notExists
            }
        }

        // Standard value reading for other evaluation types
        if useUserDefaults {
            // Use full path support - pathOrDomain detects if it's a full path or domain
            return Validation.shared.getUserDefaultsValue(pathOrDomain: monitor.path, key: monitor.key) ?? "(not set)"
        } else {
            // Use file-based plist reading with validation service
            return Validation.shared.getPlistValue(path: monitor.path, key: monitor.key) ?? "(not set)"
        }
    }

    /// Evaluate completion trigger condition
    /// - Parameters:
    ///   - condition: The condition type ("equals", "notEquals", "exists", "match", "greaterThan", "lessThan")
    ///   - currentValue: The current plist value
    ///   - expectedValue: The expected value (optional for "exists")
    /// - Returns: true if condition is met, false otherwise
    private func evaluateTriggerCondition(condition: String, currentValue: String, expectedValue: String?) -> Bool {
        let normalizedCondition = condition.lowercased()

        switch normalizedCondition {
        case "equals":
            guard let expected = expectedValue else { return false }
            return currentValue == expected

        case "notequals", "not_equals":
            guard let expected = expectedValue else { return false }
            return currentValue != expected

        case "exists":
            // Value exists if it's not empty and not the "(not set)" placeholder
            return !currentValue.isEmpty && currentValue != "(not set)" && currentValue != "Not detected"

        case "notexists", "not_exists":
            // Pass when file/path does NOT exist (value is "Not detected")
            return currentValue == "Not detected"

        case "withinseconds", "within_seconds", "recentseconds", "recent":
            // Check if timestamp is within X seconds of now
            // expectedValue = number of seconds (e.g., "300" for 5 minutes)
            guard let expected = expectedValue, let maxSeconds = Double(expected) else {
                writeLog("InspectState: withinSeconds requires numeric expectedValue (seconds)", logLevel: .error)
                return false
            }

            // Try to parse the current value as a date
            // Supports: ISO8601, plist date format, or Unix timestamp
            let now = Date()
            var parsedDate: Date?

            // Try Unix timestamp first (seconds since 1970)
            if let timestamp = Double(currentValue) {
                parsedDate = Date(timeIntervalSince1970: timestamp)
            }

            // Try ISO8601 format
            if parsedDate == nil {
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsedDate = iso8601Formatter.date(from: currentValue)

                // Try without fractional seconds
                if parsedDate == nil {
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    parsedDate = iso8601Formatter.date(from: currentValue)
                }
            }

            // Try common plist date formats
            if parsedDate == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                // Try various formats
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
            // Try numeric comparison first
            if let currentNum = Double(currentValue), let expectedNum = Double(expected) {
                return currentNum > expectedNum
            }
            // Fall back to string comparison
            return currentValue > expected

        case "lessthan", "less_than", "<":
            guard let expected = expectedValue else { return false }
            // Try numeric comparison first
            if let currentNum = Double(currentValue), let expectedNum = Double(expected) {
                return currentNum < expectedNum
            }
            // Fall back to string comparison
            return currentValue < expected

        default:
            writeLog("InspectState: Unknown completion trigger condition '\(condition)' - returning false", logLevel: .error)
            return false
        }
    }

    // MARK: - Multiple JSON Monitors

    /// Start multiple JSON monitors for an item that auto-update guidance components
    /// - Parameters:
    ///   - item: The item configuration containing jsonMonitors array
    ///   - onUpdate: Callback triggered when JSON value changes (receives: itemId, guidanceBlockIndex, targetProperty, newValue)
    func startMultipleJsonMonitors(
        for item: InspectConfig.ItemConfig,
        onUpdate: @escaping (String, Int, String, String) -> Void,
        onComplete: @escaping (String, InspectCompletionResult, String?) -> Void
    ) {
        guard let monitors = item.jsonMonitors, !monitors.isEmpty else {
            return
        }

        let itemId = item.id
        writeLog("InspectState: Starting \(monitors.count) JSON monitor(s) for '\(itemId)'", logLevel: .info)

        for (monitorIndex, monitor) in monitors.enumerated() {
            // Validate interval
            guard monitor.recheckInterval >= 1 && monitor.recheckInterval <= 3600 else {
                writeLog("InspectState: Invalid recheckInterval \(monitor.recheckInterval) for JSON monitor \(monitorIndex) in '\(itemId)'", logLevel: .error)
                continue
            }

            // Create unique monitor key
            let monitorKey = "\(itemId)_json_monitor_\(monitorIndex)"

            // Start monitoring on main actor
            Task { @MainActor in
                // Stop existing monitor if any
                if let existingMonitor = self.jsonMonitors[monitorKey] {
                    existingMonitor.timer.invalidate()
                    self.jsonMonitors.removeValue(forKey: monitorKey)
                }

                // Read initial value
                let initialValue = self.readJsonMonitorValue(monitor: monitor)

                writeLog("InspectState: JSON monitor \(monitorIndex) for '\(itemId)' - path: \(monitor.path), key: \(monitor.key), initial: \(initialValue), interval: \(monitor.recheckInterval)s", logLevel: .info)

                // Trigger initial UI update with the current value
                let mappedInitialValue = monitor.valueMap?[initialValue] ?? initialValue
                onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedInitialValue)
                writeLog("InspectState: JSON monitor \(monitorIndex) set initial value for '\(itemId)': \(mappedInitialValue)", logLevel: .info)

                // If there's a completion trigger, also update the 'state' property based on initial evaluation
                if let trigger = monitor.completionTrigger {
                    let conditionMet = self.evaluateTriggerCondition(
                        condition: trigger.condition,
                        currentValue: initialValue,
                        expectedValue: trigger.value
                    )
                    let stateValue = conditionMet ? "pass" : "fail"
                    onUpdate(itemId, monitor.guidanceBlockIndex, "state", stateValue)
                    writeLog("InspectState: JSON monitor \(monitorIndex) set initial state for '\(itemId)': \(stateValue) (condition: \(trigger.condition))", logLevel: .info)
                }

                // Start periodic timer
                let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(monitor.recheckInterval), repeats: true) { [weak self] _ in
                    guard let self = self else { return }

                    Task { @MainActor in
                        // Read current value
                        let currentValue = self.readJsonMonitorValue(monitor: monitor)

                        // Get the last known value from stored monitor (not initialValue!)
                        let lastValue = self.jsonMonitors[monitorKey]?.currentValue ?? initialValue

                        // Check if value changed from last known value
                        if currentValue != lastValue {
                            writeLog("InspectState: JSON monitor \(monitorIndex) detected change for '\(itemId)': \(lastValue) → \(currentValue)", logLevel: .info)

                            // Apply value mapping if defined
                            let mappedValue = monitor.valueMap?[currentValue] ?? currentValue

                            // Trigger callback with update info
                            onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedValue)

                            // Check for completion trigger and update state
                            if let trigger = monitor.completionTrigger {
                                let conditionMet = self.evaluateTriggerCondition(
                                    condition: trigger.condition,
                                    currentValue: currentValue,
                                    expectedValue: trigger.value
                                )

                                // Always update state based on condition result
                                let stateValue = conditionMet ? "pass" : "fail"
                                onUpdate(itemId, monitor.guidanceBlockIndex, "state", stateValue)
                                writeLog("InspectState: JSON Monitor updated state for '\(itemId)': \(stateValue)", logLevel: .debug)

                                if conditionMet {
                                    writeLog("InspectState: JSON completion trigger met for '\(itemId)' - condition: \(trigger.condition), result: \(trigger.result)", logLevel: .info)

                                    let result: InspectCompletionResult = trigger.result.lowercased() == "success"
                                        ? .success(message: trigger.message)
                                        : .failure(message: trigger.message)

                                    let delay = trigger.delay ?? 0.0

                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        onComplete(itemId, result, trigger.message)
                                    }
                                }
                            }

                            // Update stored current value
                            if let storedMonitor = self.jsonMonitors[monitorKey] {
                                self.jsonMonitors[monitorKey] = JsonMonitorTask(
                                    timer: storedMonitor.timer,
                                    initialValue: storedMonitor.initialValue,
                                    currentValue: currentValue,
                                    recheckInterval: storedMonitor.recheckInterval
                                )
                            }
                        }
                    }
                }

                // Store monitor task
                self.jsonMonitors[monitorKey] = JsonMonitorTask(
                    timer: timer,
                    initialValue: initialValue,
                    currentValue: initialValue,
                    recheckInterval: monitor.recheckInterval
                )
            }
        }
    }

    /// Read JSON value for a monitor configuration
    /// - Parameter monitor: The JSON monitor configuration
    /// - Returns: String representation of the JSON value
    @MainActor
    private func readJsonMonitorValue(monitor: InspectConfig.JsonMonitor) -> String {
        // Handle "exists" evaluation - check file presence instead of reading value
        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            // If file exists, read the actual value to display (e.g., timestamp)
            if fileExists {
                return Validation.shared.getJsonValue(path: monitor.path, key: monitor.key) ?? "Present"
            } else {
                return "Not detected"
            }
        }

        // Handle "notExists" evaluation - pass when file/path does NOT exist
        if let evaluation = monitor.evaluation?.lowercased(), evaluation == "notexists" || evaluation == "not_exists" {
            let expandedPath = (monitor.path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)

            if fileExists {
                return "Present"  // File exists = fail condition for notExists
            } else {
                return "Not detected"  // File doesn't exist = pass condition for notExists
            }
        }

        // Standard value reading for other evaluation types
        return Validation.shared.getJsonValue(path: monitor.path, key: monitor.key) ?? "(not set)"
    }

    /// Force immediate recheck of plist monitors for a specific item
    /// - Parameters:
    ///   - itemId: The item ID to recheck monitors for
    ///   - onUpdate: Callback triggered when values changed (receives: itemId, guidanceBlockIndex, targetProperty, newValue)
    @MainActor
    func recheckPlistMonitorsForItem(_ itemId: String, onUpdate: @escaping (String, Int, String, String) -> Void) {
        // Find all monitors for this item (format: "itemId_monitor_N")
        let monitorKeys = plistMonitors.keys.filter { $0.hasPrefix("\(itemId)_monitor_") }

        guard !monitorKeys.isEmpty else {
            writeLog("InspectState: No monitors found for item '\(itemId)' to recheck", logLevel: .debug)
            return
        }

        writeLog("InspectState: Manual recheck triggered for '\(itemId)' (\(monitorKeys.count) monitor(s))", logLevel: .info)

        // Find the item configuration to get monitor details
        guard let item = items.first(where: { $0.id == itemId }),
              let monitors = item.plistMonitors else {
            writeLog("InspectState: Item '\(itemId)' not found or has no plistMonitors", logLevel: .error)
            return
        }

        // Recheck each monitor
        for (monitorIndex, monitor) in monitors.enumerated() {
            let monitorKey = "\(itemId)_monitor_\(monitorIndex)"

            guard let storedMonitor = plistMonitors[monitorKey] else {
                continue
            }

            // Determine reading method
            let useUserDefaults = monitor.useUserDefaults == true

            // Read current value
            let currentValue = readPlistMonitorValue(monitor: monitor, useUserDefaults: useUserDefaults)
            let lastValue = storedMonitor.currentValue

            // Check if value changed
            if currentValue != lastValue {
                writeLog("InspectState: Manual recheck detected change for '\(itemId)' monitor \(monitorIndex): \(lastValue) → \(currentValue)", logLevel: .info)

                // Apply value mapping if defined
                let mappedValue = monitor.valueMap?[currentValue] ?? currentValue

                // Trigger callback with update info
                onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedValue)

                // Update stored current value
                plistMonitors[monitorKey] = PlistMonitorTask(
                    timer: storedMonitor.timer,
                    initialValue: storedMonitor.initialValue,
                    currentValue: currentValue,
                    recheckInterval: storedMonitor.recheckInterval
                )
            } else {
                writeLog("InspectState: Manual recheck for '\(itemId)' monitor \(monitorIndex): no change (value: \(currentValue))", logLevel: .debug)
            }
        }
    }

    /// Force immediate recheck of ALL active plist monitors
    /// - Parameter onUpdate: Callback triggered when values changed (receives: itemId, guidanceBlockIndex, targetProperty, newValue)
    @MainActor
    func recheckAllPlistMonitors(onUpdate: @escaping (String, Int, String, String) -> Void) {
        // Group monitor keys by itemId
        var itemIds = Set<String>()
        for monitorKey in plistMonitors.keys {
            // Extract itemId from key format: "itemId_monitor_N"
            let components = monitorKey.split(separator: "_")
            if components.count >= 3 {
                let itemId = components[0..<components.count-2].joined(separator: "_")
                itemIds.insert(itemId)
            }
        }

        guard !itemIds.isEmpty else {
            writeLog("InspectState: No active monitors to recheck", logLevel: .debug)
            return
        }

        writeLog("InspectState: Manual recheck triggered for ALL items (\(itemIds.count) item(s), \(plistMonitors.count) monitor(s))", logLevel: .info)

        // Recheck monitors for each item
        for itemId in itemIds {
            recheckPlistMonitorsForItem(itemId, onUpdate: onUpdate)
        }
    }

    // MARK: - Guidance Form Input Management

    /// Resolve inherited value from various sources for textfield pre-population
    /// Supports: plist:path:key, defaults:domain:key, env:NAME, field:itemId.fieldId
    @MainActor
    func resolveInheritValue(_ inheritSpec: String, basePath: String?) -> String? {
        let parts = inheritSpec.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        switch parts[0] {
        case "plist":
            // plist:/path/to/file.plist:key.path
            guard parts.count >= 3 else { return nil }
            let path = parts[1]
            let key = parts.dropFirst(2).joined(separator: ":")
            return Validation.shared.getPlistValue(at: path, key: key, basePath: basePath)

        case "defaults":
            // defaults:com.apple.domain:key.path
            guard parts.count >= 3 else { return nil }
            let domain = parts[1]
            let key = parts.dropFirst(2).joined(separator: ":")
            return Validation.shared.getUserDefaultsValue(domain: domain, key: key)

        case "env":
            // env:USER
            return ProcessInfo.processInfo.environment[parts[1]]

        case "field":
            // field:itemId.fieldId
            let fieldParts = parts[1].components(separatedBy: ".")
            guard fieldParts.count == 2 else { return nil }
            let itemId = fieldParts[0]
            let fieldId = fieldParts[1]
            return guidanceFormInputs[itemId]?.textfields[fieldId]

        default:
            return nil
        }
    }

    /// Initialize form input state for an item if not already present
    /// Populates default values from guidance content configuration
    func initializeGuidanceFormState(for itemId: String) {
        // Don't reinitialize if state already exists (preserve user selections)
        if guidanceFormInputs[itemId] != nil {
            return
        }

        // Find the item configuration to extract default values
        guard let item = items.first(where: { $0.id == itemId }),
              let guidanceContent = item.guidanceContent else {
            // No guidance content, create empty state
            guidanceFormInputs[itemId] = GuidanceFormInputState()
            writeLog("InspectState: Initialized empty form state for item '\(itemId)' (no guidance content)", logLevel: .debug)
            return
        }

        // Create new state and populate with defaults from configuration
        var newState = GuidanceFormInputState()

        for block in guidanceContent {
            guard let fieldId = block.id else { continue }

            // Populate defaults based on field type
            switch block.type {
            case "checkbox":
                // Parse boolean from value string ("true", "yes", "1" → true)
                if let value = block.value?.lowercased() {
                    let isChecked = value == "true" || value == "yes" || value == "1"
                    newState.checkboxes[fieldId] = isChecked
                    writeLog("InspectState: Set default checkbox '\(fieldId)' = \(isChecked)", logLevel: .debug)
                }

            case "dropdown":
                // Use value as selected option if it's in the options list
                if let value = block.value, !value.isEmpty,
                   let options = block.options, options.contains(value) {
                    newState.dropdowns[fieldId] = value
                    writeLog("InspectState: Set default dropdown '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            case "radio":
                // Use value as selected option if it's in the options list
                if let value = block.value, !value.isEmpty,
                   let options = block.options, options.contains(value) {
                    newState.radios[fieldId] = value
                    writeLog("InspectState: Set default radio '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            case "textfield":
                // Use value as default if present (inherit is resolved lazily in getter)
                if let value = block.value, !value.isEmpty {
                    newState.textfields[fieldId] = value
                    writeLog("InspectState: Set default textfield '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            default:
                continue
            }
        }

        guidanceFormInputs[itemId] = newState
        writeLog("InspectState: Initialized form state for item '\(itemId)' with \(newState.checkboxes.count) checkboxes, \(newState.dropdowns.count) dropdowns, \(newState.radios.count) radios, \(newState.textfields.count) textfields", logLevel: .info)
    }

    /// Validate that all required form inputs are filled for a given item
    func validateGuidanceInputs(for item: InspectConfig.ItemConfig) -> Bool {
        guard let guidanceContent = item.guidanceContent else { return true }

        // Don't initialize during validation (avoid publishing during view updates)
        // If state doesn't exist yet, return true (valid by default)
        // GuidanceContentView.init will handle async initialization
        guard let formState = guidanceFormInputs[item.id] else { return true }

        // Check each guidance content block for required fields
        for block in guidanceContent {
            guard block.required == true, let fieldId = block.id else { continue }

            switch block.type {
            case "checkbox":
                // Required checkbox must be checked OR have a default value
                let hasUserValue = formState.checkboxes[fieldId] == true
                let hasDefault = block.value != nil && !block.value!.isEmpty

                if !hasUserValue && !hasDefault {
                    writeLog("InspectState: Required checkbox '\(fieldId)' not checked and no default", logLevel: .info)
                    return false
                }

            case "dropdown":
                // Required dropdown must have a value selected OR have a default value
                let hasUserValue = formState.dropdowns[fieldId] != nil && !formState.dropdowns[fieldId]!.isEmpty
                let hasDefault = block.value != nil && !block.value!.isEmpty

                if !hasUserValue && !hasDefault {
                    writeLog("InspectState: Required dropdown '\(fieldId)' not selected and no default", logLevel: .info)
                    return false
                }

            case "radio":
                // Required radio must have an option selected OR have a default value
                let hasUserValue = formState.radios[fieldId] != nil && !formState.radios[fieldId]!.isEmpty
                let hasDefault = block.value != nil && !block.value!.isEmpty

                if !hasUserValue && !hasDefault {
                    writeLog("InspectState: Required radio '\(fieldId)' not selected and no default", logLevel: .info)
                    return false
                }

            case "textfield":
                // Required textfield must have a value OR have a default/inherit value
                let userValue = formState.textfields[fieldId] ?? ""
                let hasValue = !userValue.isEmpty
                let hasDefault = block.value != nil && !block.value!.isEmpty
                let hasInherit = block.inherit != nil

                if !hasValue && !hasDefault && !hasInherit {
                    writeLog("InspectState: Required textfield '\(fieldId)' is empty and no default/inherit", logLevel: .info)
                    return false
                }

                // Regex validation (optional)
                if let regex = block.regex, !userValue.isEmpty {
                    let pattern = try? NSRegularExpression(pattern: regex)
                    let range = NSRange(userValue.startIndex..<userValue.endIndex, in: userValue)
                    if pattern?.firstMatch(in: userValue, range: range) == nil {
                        writeLog("InspectState: Textfield '\(fieldId)' failed regex validation", logLevel: .info)
                        return false
                    }
                }

            default:
                continue
            }
        }

        writeLog("InspectState: All required fields validated for '\(item.id)'", logLevel: .debug)
        return true
    }

    /// Export guidance selections for external script consumption
    func exportGuidanceSelections(for itemId: String) -> [String: Any] {
        guard let formState = guidanceFormInputs[itemId] else {
            return [:]
        }

        var result: [String: Any] = [:]
        result["itemId"] = itemId
        result["timestamp"] = ISO8601DateFormatter().string(from: Date())
        result["checkboxes"] = formState.checkboxes
        result["dropdowns"] = formState.dropdowns
        result["radios"] = formState.radios
        result["toggles"] = formState.toggles
        result["sliders"] = formState.sliders
        result["textfields"] = formState.textfields

        return result
    }

    /// Write all guidance selections to log file for calling scripts
    func writeGuidanceSelectionsToLog() {
        let logPath = "/tmp/preset6_form_inputs.json"

        var allSelections: [[String: Any]] = []
        for (itemId, _) in guidanceFormInputs {
            let selections = exportGuidanceSelections(for: itemId)
            if !selections.isEmpty {
                allSelections.append(selections)
            }
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: allSelections, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: logPath), options: .atomic)
            writeLog("InspectState: Form selections written to \(logPath)", logLevel: .info)

            // Also log to console in parseable format
            for selection in allSelections {
                if let itemId = selection["itemId"] as? String {
                    let checkboxes = selection["checkboxes"] as? [String: Bool] ?? [:]
                    let dropdowns = selection["dropdowns"] as? [String: String] ?? [:]
                    let radios = selection["radios"] as? [String: String] ?? [:]
                    let toggles = selection["toggles"] as? [String: Bool] ?? [:]
                    let sliders = selection["sliders"] as? [String: Double] ?? [:]
                    let textfields = selection["textfields"] as? [String: String] ?? [:]

                    for (fieldId, checked) in checkboxes {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=checkbox value=\(checked)")
                    }
                    for (fieldId, value) in dropdowns {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=dropdown value=\(value)")
                    }
                    for (fieldId, value) in radios {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=radio value=\(value)")
                    }
                    for (fieldId, enabled) in toggles {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=toggle value=\(enabled)")
                    }
                    for (fieldId, value) in sliders {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=slider value=\(value)")
                    }
                    for (fieldId, value) in textfields {
                        print("[PRESET9_FORM] stepId=\(itemId) field=\(fieldId) type=textfield value=\(value)")
                    }
                }
            }
        } catch {
            writeLog("InspectState: Failed to write form selections: \(error)", logLevel: .error)
        }
    }

    /// Write a simple interaction log entry to /tmp/preset6_interaction.log
    /// Used for real-time form element callbacks (sliders, toggles, extra button)
    func writeToInteractionLog(_ message: String) {
        let logPath = "/tmp/preset6_interaction.log"
        let logEntry = "\(message)\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }


    deinit {
        writeLog("InspectState.deinit() - Starting resource cleanup", logLevel: .info)

        // Stop progress tracking
        // Progress tracking removed - no longer needed

        // Stop all timers
        updateTimer?.invalidate()
        updateTimer = nil
        fileSystemCheckTimer?.invalidate()
        fileSystemCheckTimer = nil
        sideMessageTimer?.invalidate()
        sideMessageTimer = nil

        // Stop all plist monitoring
        stopAllPlistMonitors()
        
        // Stop DispatchSource monitoring
        commandFileMonitor?.cancel()
        commandFileMonitor = nil
        
        // Stop FSEvents monitoring and clear delegate to prevent any potential retain cycles
        fsEventsMonitor.stopMonitoring()
        fsEventsMonitor.delegate = nil
        
        // Cancel all debounced operations
        debouncedUpdater.cancelAll()
        
        // Clear AppInspector reference
        appInspector = nil
        
        // Note: Services (configurationService) are value types with no explicit cleanup needed
        // They will be automatically deallocated when InspectState is deallocated
        // Validation.shared is a singleton and doesn't need explicit cleanup
        
        writeLog("InspectState.deinit() - Resource cleanup completed", logLevel: .info)
    }
    
    // MARK: - Progress Tracking

    private func initializeProgressTracker() {
        let preset = uiConfiguration.preset.lowercased()
        let totalItems = items.count

        // Progress tracking removed - no longer needed

        // Set initial state for all items
        for item in items {
            _ = getItemStatus(item)
            // Progress tracking removed - no longer needed
        }

        // Update preset-specific data
        updatePresetSpecificProgress()

        writeLog("InspectState: Progress tracker initialized for \(preset) with \(totalItems) items", logLevel: .info)
    }

    private func updateProgressForItem(_ itemId: String, status: String) {
        // Progress tracking removed - no longer needed
        updatePresetSpecificProgress()
    }

    private func updatePresetSpecificProgress() {
        // Progress tracking removed - no longer needed

        switch uiConfiguration.preset.lowercased() {
        case "preset1":
            // Progress tracking removed - no longer needed
            break

        case "preset6":
            // Progress tracking removed - no longer needed
            break

        default:
            break
        }
    }

    private func getItemStatus(_ item: InspectConfig.ItemConfig) -> String {
        if completedItems.contains(item.id) {
            return "complete"
        } else if downloadingItems.contains(item.id) {
            return "downloading"
        } else {
            return "pending"
        }
    }

    private func getCurrentImageIndex() -> Int {
        // This would need to be tracked if implementing image rotation
        return 0
    }

    // MARK: - Helper Functions

    // MARK: - Bundle Info Reading (Cross-Preset)

    /// Reads bundle info from an installed app's Info.plist
    /// - Parameters:
    ///   - appPath: Path to the .app bundle (e.g., "/Applications/Cloudflare WARP.app")
    ///   - infoType: Type of info to retrieve: "version", "build", "identifier", "all"
    /// - Returns: The requested bundle info string, or nil if not found
    func getBundleInfo(appPath: String, infoType: String) -> String? {
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

        guard FileManager.default.fileExists(atPath: infoPlistPath),
              let plist = NSDictionary(contentsOfFile: infoPlistPath) else {
            writeLog("InspectState: Could not read Info.plist at \(infoPlistPath)", logLevel: .debug)
            return nil
        }

        let version = plist["CFBundleShortVersionString"] as? String
        let build = plist["CFBundleVersion"] as? String
        let identifier = plist["CFBundleIdentifier"] as? String

        switch infoType.lowercased() {
        case "version":
            return version
        case "build":
            return build
        case "identifier":
            return identifier
        case "all":
            // Format: "16.105.3 (16.105.26020123) - com.microsoft.Word"
            var parts: [String] = []
            if let v = version {
                if let b = build {
                    parts.append("\(v) (\(b))")
                } else {
                    parts.append(v)
                }
            } else if let b = build {
                parts.append(b)
            }
            if let id = identifier {
                parts.append(id)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")
        default:
            writeLog("InspectState: Unknown bundle info type '\(infoType)', use 'version', 'build', 'identifier', or 'all'", logLevel: .info)
            return version // Default to version
        }
    }

    /// Returns bundle info for an item if it has a valid path and showBundleInfo is configured
    /// - Parameter item: The ItemConfig to get bundle info for
    /// - Returns: Bundle info string or nil
    func getBundleInfoForItem(_ item: InspectConfig.ItemConfig) -> String? {
        guard let infoType = item.showBundleInfo,
              let firstPath = item.paths.first,
              firstPath.hasSuffix(".app"),
              FileManager.default.fileExists(atPath: firstPath) else {
            return nil
        }
        return getBundleInfo(appPath: firstPath, infoType: infoType)
    }

    // MARK: - FileMonitorDelegate

    func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String) {
        // Handle installation detection if needed
        writeLog("InspectState: Installation detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String) {
        // Handle removal detection if needed
        writeLog("InspectState: Removal detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String) {
        // Handle download detection if needed
        writeLog("InspectState: Download detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitorDidDetectChanges(_ monitor: FileMonitor) {
        // Handle general changes if needed
        writeLog("InspectState: File monitor detected changes", logLevel: .debug)
    }
}
