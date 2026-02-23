//
//  Monitoring.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 20/09/2025
//
//  Centralized monitoring service for Inspect mode
//  Handles filesystem monitoring, command file watching, and app status detection
//

import Foundation

// MARK: - Monitoring Protocol

protocol InspectMonitoringDelegate: AnyObject {
    func monitoringService(_ service: Monitoring, didDetectInstallation itemId: String)
    func monitoringService(_ service: Monitoring, didDetectDownload itemId: String)
    func monitoringService(_ service: Monitoring, didDetectRemoval itemId: String)
    func monitoringServiceDidDetectChanges(_ service: Monitoring)
}

// MARK: - Monitoring Service

class Monitoring {

    // MARK: Properties

    weak var delegate: InspectMonitoringDelegate?

    private var items: [InspectConfig.ItemConfig] = []
    private var cachePaths: [String] = []

    // Monitoring components
    private var updateTimer: Timer?
    private var commandFileMonitor: DispatchSourceFileSystemObject?
    private let fileMonitor = FileMonitor.shared
    private var appInspector: AppInspector?

    // State tracking
    private var lastCommandFileSize: Int = 0
    private var lastProcessedLineCount: Int = 0

    // Performance optimization
    private let debouncedUpdater = DebouncedUpdater()

    // MARK: - Initialization

    init() {
        writeLog("MonitoringService: Initialized", logLevel: .debug)
    }

    // MARK: - Public API

    func startMonitoring(items: [InspectConfig.ItemConfig], cachePaths: [String]) {
        self.items = items
        self.cachePaths = cachePaths

        writeLog("MonitoringService: Starting monitoring for \(items.count) items", logLevel: .info)

        // Start timer-based monitoring (primary method)
        startTimerMonitoring()

        // Setup command file monitoring (for external updates)
        setupCommandFileMonitoring()

        // Setup centralized file monitoring
        setupFileMonitoring()

        // Initial status check
        performStatusCheck()
    }

    func stopMonitoring() {
        writeLog("MonitoringService: Stopping all monitoring", logLevel: .info)

        // Stop all monitoring components
        updateTimer?.invalidate()
        updateTimer = nil

        commandFileMonitor?.cancel()
        commandFileMonitor = nil

        fileMonitor.stopMonitoring()
        appInspector = nil

        // Clear caches
        debouncedUpdater.cancelAll()
    }

    func forceStatusCheck() {
        fileMonitor.performStatusCheck()
    }

    // MARK: - Timer Monitoring (Primary)

    private func startTimerMonitoring() {
        updateTimer?.invalidate()

        // Check every 2 seconds for robustness
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.performStatusCheck()
        }

        writeLog("MonitoringService: Timer monitoring active", logLevel: .info)
    }

    // MARK: - File Monitoring Setup

    private func setupFileMonitoring() {
        guard !items.isEmpty else { return }

        // Setup FileMonitor delegate and start monitoring
        fileMonitor.delegate = self
        fileMonitor.startMonitoring(items: items, cachePaths: cachePaths)

        writeLog("MonitoringService: File monitoring delegated to FileMonitor", logLevel: .info)
    }

    private func performStatusCheck() {
        // Delegate to centralized FileMonitor
        fileMonitor.performStatusCheck()
    }


    // MARK: - Installation Detection

    private func checkIfInstalled(_ item: InspectConfig.ItemConfig) -> Bool {
        // Check each possible path for the app
        for path in item.paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }

    private func checkIfDownloading(_ item: InspectConfig.ItemConfig) -> Bool {
        // Check cache directories for download files
        for cachePath in cachePaths {
            // Delegate to FileMonitor for download checking
            // This check is now handled by FileMonitor.isDownloading()
            let cacheContents: [String] = []

            if cacheContents.isEmpty {
                writeLog("MonitoringService: Cache directory '\(cachePath)' is empty", logLevel: .debug)
            } else {
                writeLog("MonitoringService: Checking \(cacheContents.count) files in \(cachePath) for item '\(item.id)' (display: '\(item.displayName)')", logLevel: .debug)
                // Log first few files for debugging
                let preview = cacheContents.prefix(3).joined(separator: ", ")
                writeLog("MonitoringService:   Files: \(preview)\(cacheContents.count > 3 ? "..." : "")", logLevel: .debug)
            }

            for file in cacheContents {
                // Skip hidden files like .DS_Store
                guard !file.hasPrefix(".") else { continue }

                // First check if this is a download-related file
                let isDownload = isDownloadFile(file)
                if !isDownload {
                    continue
                }

                // Now check if it matches this specific item
                let matches = fileMatchesItem(file, item: item)

                if matches {
                    writeLog("MonitoringService: ✓ SPINNER ACTIVE for '\(item.displayName)' - Found '\(file)' in \(cachePath)", logLevel: .info)
                    return true
                } else {
                    writeLog("MonitoringService:   No match: '\(file)' vs item '\(item.id)' (\(item.displayName))", logLevel: .debug)
                }
            }
        }
        writeLog("MonitoringService: No cache match for '\(item.id)'", logLevel: .debug)
        return false
    }

    private func isDownloadFile(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
        // Check for common download/package extensions and patterns
        return lowercased.hasSuffix(".download") ||
               lowercased.hasSuffix(".pkg") ||
               lowercased.hasSuffix(".dmg") ||
               lowercased.hasSuffix(".zip") ||
               lowercased.hasSuffix(".app") ||
               lowercased.contains("installer") ||
               lowercased.contains("setup") ||
               lowercased.contains(".partial") ||
               lowercased.contains(".tmp")
    }

    private func fileMatchesItem(_ filename: String, item: InspectConfig.ItemConfig) -> Bool {
        return smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: filename)
    }

    /// Smart filename matching algorithm (ported from original InspectState)
    /// Handles cases like: microsoft_outlook → Microsoft_Outlook_16.101.25091314_Installer.pkg
    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        let cleanFilename = filename.lowercased()
        let cleanItemId = itemId.lowercased()
        let cleanDisplayName = displayName.lowercased().replacingOccurrences(of: " ", with: "")

        // Additional normalization: also remove underscores from display name for better matching
        let cleanDisplayNameNoUnderscore = displayName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Strategy 1: Direct substring match (fast path)
        if cleanFilename.contains(cleanItemId) ||
           cleanFilename.contains(cleanDisplayName) ||
           cleanFilename.contains(cleanDisplayNameNoUnderscore) {
            writeLog("MonitoringService: Strategy 1 match: '\(filename)' matched", logLevel: .debug)
            return true
        }

        // Strategy 2: Split and match components (handle underscores/spaces)
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

        if allItemComponentsMatch || allDisplayComponentsMatch {
            writeLog("MonitoringService: Strategy 2 match: '\(filename)' component match", logLevel: .debug)
            return true
        }

        // Strategy 3: Handle common patterns
        let condensedItemId = cleanItemId.replacingOccurrences(of: "_", with: "")
        let condensedDisplayName = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        if cleanFilename.contains(condensedItemId) || cleanFilename.contains(condensedDisplayName) {
            writeLog("MonitoringService: Strategy 3 match: '\(filename)' contains condensed form", logLevel: .debug)
            return true
        }

        // Strategy 4: Fuzzy matching for brand names
        // Handle cases where "microsoft_office" should match "Office_365" packages
        if let primaryComponent = itemComponents.first, primaryComponent.count >= 4 {
            // For microsoft_*, look for the main app name (second component)
            if primaryComponent == "microsoft" && itemComponents.count > 1 {
                let appName = itemComponents[1]
                if cleanFilename.contains(appName) {
                    writeLog("MonitoringService: Strategy 4 match: '\(filename)' contains app name '\(appName)'", logLevel: .debug)
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Command File Monitoring

    private func setupCommandFileMonitoring() {
        let commandFilePath = InspectConstants.commandFilePath

        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            writeLog("MonitoringService: Command file not found", logLevel: .debug)
            return
        }

        let fileHandle = open(commandFilePath, O_EVTONLY)
        guard fileHandle >= 0 else {
            writeLog("MonitoringService: Cannot open command file", logLevel: .error)
            return
        }

        commandFileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        commandFileMonitor?.setEventHandler { [weak self] in
            self?.checkCommandFile()
        }

        commandFileMonitor?.setCancelHandler {
            close(fileHandle)
        }

        commandFileMonitor?.resume()
        writeLog("MonitoringService: Command file monitoring active", logLevel: .info)
    }

    private func checkCommandFile() {
        // Read and process command file for external status updates
        let commandFilePath = InspectConstants.commandFilePath

        guard let content = try? String(contentsOfFile: commandFilePath, encoding: .utf8) else {
            return
        }

        let currentSize = content.count
        let lines = content.components(separatedBy: .newlines)
        let currentLineCount = lines.count

        // Process only new lines
        if currentLineCount > lastProcessedLineCount {
            let newLines = Array(lines.dropFirst(lastProcessedLineCount))

            for line in newLines where !line.isEmpty {
                processCommandLine(line)
            }

            lastCommandFileSize = currentSize
            lastProcessedLineCount = currentLineCount
        }
    }

    private func processCommandLine(_ line: String) {
        // Enhanced parsing to handle multiple command formats from AppInspector
        writeLog("MonitoringService: Parsing command line: \(line)", logLevel: .debug)

        // Try to extract index from various command formats
        var appIndex: Int?
        var status: String?

        // Format 1: "listitem: index: X, status: Y, statustext: Z"
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

        // Apply updates based on parsed information
        if let index = appIndex, index < items.count {
            let item = items[index]

            if let status = status {
                switch status.lowercased() {
                case "success", "installed":
                    delegate?.monitoringService(self, didDetectInstallation: item.id)
                    writeLog("MonitoringService: \(item.displayName) installation completed (from command)", logLevel: .info)

                case "downloading":
                    delegate?.monitoringService(self, didDetectDownload: item.id)
                    writeLog("MonitoringService: \(item.displayName) downloading (from command)", logLevel: .info)

                default:
                    writeLog("MonitoringService: Unknown status '\(status)' for \(item.displayName)", logLevel: .debug)
                }
            }
        } else {
            // Fallback to simple parsing if index-based parsing fails
            if line.contains("success") || line.contains("installed") {
                for item in items where line.lowercased().contains(item.id.lowercased()) {
                    delegate?.monitoringService(self, didDetectInstallation: item.id)
                    break
                }
            }
        }
    }


    deinit {
        stopMonitoring()
        writeLog("MonitoringService: Deinitialized", logLevel: .debug)
    }
}

// MARK: - FileMonitor Delegate

extension Monitoring: FileMonitorDelegate {
    func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String) {
        delegate?.monitoringService(self, didDetectInstallation: itemId)
        writeLog("MonitoringService: Installation detected for \(itemId)", logLevel: .info)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String) {
        delegate?.monitoringService(self, didDetectRemoval: itemId)
        writeLog("MonitoringService: Removal detected for \(itemId)", logLevel: .info)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String) {
        delegate?.monitoringService(self, didDetectDownload: itemId)
        writeLog("MonitoringService: Download detected for \(itemId)", logLevel: .info)
    }

    func fileMonitorDidDetectChanges(_ monitor: FileMonitor) {
        delegate?.monitoringServiceDidDetectChanges(self)
    }
}
