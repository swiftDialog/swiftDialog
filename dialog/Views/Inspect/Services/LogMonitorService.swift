//
//  LogMonitorService.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 2026-01-21
//
//  Service for monitoring log files and extracting status text via regex patterns.
//  Works across Presets 1-3 and 6+ for real-time status updates from Installomator, Jamf, Munki, etc.
//

import Foundation
import Combine

// MARK: - Log Pattern Presets

/// Named regex presets for common log formats
/// Simplified: patterns only, status cleanup is a simple shared function
struct LogPatternPreset {
    let pattern: String
    let captureGroup: Int

    static let presets: [String: LogPatternPreset] = [
        // Installomator: "2026-02-22 15:23:13 : INFO  : microsoftword : Downloading https://..."
        // Format: timestamp : LEVEL : label : message
        // Captures: Downloading/Mounting/Copying/Installing/Verifying/Removing/Running + path, version info
        // Auto-match works because paths contain app names (e.g., "googlechrome.dmg", "Google Chrome.app")
        "installomator": LogPatternPreset(
            pattern: #": (?:INFO|DEBUG|REQ|WARN)\s+: \w+ : ((?:Downloading|Mounted|Mounting|Verifying|Copy|Copying|Installing|Unpacking|Removing|Running|Extracting)\s+.+?(?:\.dmg|\.pkg|\.zip|\.app|$)|(?:Installed|Downloaded) version: [\d.]+|\d+%)"#,
            captureGroup: 1
        ),
        // Jamf Pro: [timestamp] LEVEL - message
        "jamf": LogPatternPreset(
            pattern: #"\[.*?\]\s*(?:INFO|DEBUG)\s*-\s*(.+)"#,
            captureGroup: 1
        ),
        // Munki: INFO: message
        "munki": LogPatternPreset(
            pattern: #"INFO:\s*(.+)"#,
            captureGroup: 1
        ),
        // Generic shell scripts: [STATUS] message
        "shell": LogPatternPreset(
            pattern: #"^\[STATUS\]\s*(.+)$"#,
            captureGroup: 1
        ),
        // Generic MDM installer pattern: process.name: message
        // Works with Jamf, Kandji, Mosyle, Munki, etc.
        "mdm-installer": LogPatternPreset(
            pattern: #"[\w.-]+\.installer:\s*(.+?)(?:\s*$)"#,
            captureGroup: 1
        ),
        // Generic agent/daemon pattern: process: INFO/DEBUG message
        "agent": LogPatternPreset(
            pattern: #"[\w.-]+:\s*(?:INFO|DEBUG)?\s*(.+?)(?:\s*$)"#,
            captureGroup: 1
        ),
        // macOS system installer log (/private/var/log/install.log)
        "macos-installer": LogPatternPreset(
            pattern: #"]: (?:Installed \"([^\"]+)\"|PackageKit: Extracting .*/([^/]+\.pkg)|PackageKit: Touched bundle .*/([^/]+\.app)|Install failed[:\s]*([^\n]*)|PackageKit: Install Failed: ([^\n]*)|installer: Error[:\s]*([^\n]*))"#,
            captureGroup: 1
        )
    ]

    /// Simple status cleanup - converts raw log text to user-friendly display
    static func cleanupStatus(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        // Skip bundle ID lines
        if trimmed.hasPrefix("com.") { return "" }

        // Version info: "Installed version: 1.85.0" -> "Installed (v1.85.0)"
        if trimmed.hasPrefix("Installed version:") || trimmed.hasPrefix("Downloaded version:") {
            let version = trimmed
                .replacingOccurrences(of: "Installed version: ", with: "")
                .replacingOccurrences(of: "Downloaded version: ", with: "")
            return "Installed (v\(version))"
        }

        // Progress percentage (e.g., "75%")
        if trimmed.range(of: #"^\d+%$"#, options: .regularExpression) != nil {
            return "Downloading \(trimmed)"
        }

        // Simplify verbose log messages
        if trimmed.hasPrefix("Downloading ") { return "Downloading..." }
        if trimmed.hasPrefix("Mounting ") || trimmed.hasPrefix("Mounted ") { return "Mounting..." }
        if trimmed.hasPrefix("Unpacking ") { return "Unpacking..." }
        if trimmed.hasPrefix("Extracting ") { return "Extracting..." }
        if trimmed.hasPrefix("Removing ") { return "Cleaning up..." }
        if trimmed.hasPrefix("Running ") { return "Running script..." }
        if trimmed.contains("installed successfully") { return "Completed" }
        if trimmed == "Installation completed" { return "Completed" }

        // Copy/Copying: extract app name
        // Installomator uses "Copy Microsoft Word.app to /Applications"
        if trimmed.hasPrefix("Copy ") || trimmed.hasPrefix("Copying ") {
            let stripped = trimmed.hasPrefix("Copy ") ?
                trimmed.replacingOccurrences(of: "Copy ", with: "") :
                trimmed.replacingOccurrences(of: "Copying ", with: "")
            let parts = stripped.components(separatedBy: " to ")
            if let appName = parts.first { return "Copying \(appName)..." }
            return "Copying..."
        }

        // .app bundle touched = complete
        if trimmed.hasSuffix(".app") { return "Completed" }

        // .pkg extraction: parse package name and preserve phase keyword
        if trimmed.contains(".pkg") {
            // Detect leading phase keyword (e.g., "Installing foo.pkg" or "Verifying: foo.pkg")
            var phase = "Installing"
            var remainder = trimmed
            for keyword in ["Installing", "Verifying", "Downloading"] {
                if trimmed.hasPrefix(keyword) {
                    phase = keyword
                    remainder = String(trimmed.dropFirst(keyword.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                    break
                }
            }

            var pkgName = remainder
            if let hashIndex = remainder.lastIndex(of: "#") {
                pkgName = String(remainder[remainder.index(after: hashIndex)...])
            }
            pkgName = pkgName
                .replacingOccurrences(of: ".pkg", with: "")
                .replacingOccurrences(of: "_Internal", with: "")
                .replacingOccurrences(of: "_Installer", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .components(separatedBy: " to ").first ?? pkgName  // Strip " to /" suffix
                .trimmingCharacters(in: .whitespaces)
            return "\(phase) \(pkgName)..."
        }

        // Failure detection
        let lowercased = trimmed.lowercased()
        if lowercased.contains("fail") || lowercased.contains("error") {
            let maxLength = 50
            if trimmed.count > maxLength {
                return "Failed: \(String(trimmed.prefix(maxLength)))..."
            }
            return trimmed.isEmpty ? "Failed" : "Failed: \(trimmed)"
        }

        // Add trailing ellipsis to action verbs
        if trimmed.hasPrefix("Installing ") || trimmed.hasPrefix("Verifying ") {
            return "\(trimmed)..."
        }

        return trimmed
    }
}

// MARK: - Log Monitor Service

/// Service for monitoring log files and extracting status text
class LogMonitorService: ObservableObject {

    // MARK: - Singleton

    static let shared = LogMonitorService()

    // MARK: - Published Properties

    @Published private(set) var latestStatuses: [String: String] = [:]  // itemId -> status
    @Published private(set) var globalStatus: String?

    // MARK: - Private Properties

    private var pendingConfigs: [InspectConfig.LogMonitorConfig] = []
    private var activeMonitors: [String: LogFileMonitor] = [:]  // path -> monitor
    private var currentItems: [InspectConfig.ItemConfig] = []
    private var fileCreationObservers: [String: DirectoryWatcher] = [:]  // parent dir -> watcher

    // MARK: - Initialization

    private init() {
        writeLog("LogMonitorService: Initialized", logLevel: .debug)
    }

    // MARK: - Public API

    /// Configure the service with an InspectConfig
    /// - Parameter config: The configuration containing log monitor settings
    func configure(with config: InspectConfig) {
        // Collect file-based log monitor configs
        var configs: [InspectConfig.LogMonitorConfig] = []
        if let single = config.logMonitor {
            configs.append(single)
        }
        if let multiple = config.logMonitors {
            configs.append(contentsOf: multiple)
        }

        guard !configs.isEmpty else {
            writeLog("LogMonitorService: No log monitor configurations found", logLevel: .debug)
            return
        }

        pendingConfigs = configs
        writeLog("LogMonitorService: Configuring with \(configs.count) log monitor(s)", logLevel: .info)

        for monitorConfig in configs {
            let path = (monitorConfig.path as NSString).expandingTildeInPath

            if FileManager.default.fileExists(atPath: path) {
                // File exists - start immediately
                startMonitor(for: monitorConfig, at: path)
            } else {
                // Register for file creation event
                registerForFileCreation(path: path, config: monitorConfig)
            }
        }
    }

    // Note: Unified log monitoring (OSLogStore) is not supported because Apple
    // doesn't grant the com.apple.logging.local-store entitlement to third-party apps.
    // For custom installs, use a log file approach:
    // - The installer script writes progress to a log file (e.g. /tmp/install.log)
    // - swiftDialog monitors that file with logMonitor config using a matching preset

    /// Set items for auto-matching
    /// - Parameter items: The item configurations to use for auto-match routing
    func setItems(_ items: [InspectConfig.ItemConfig]) {
        currentItems = items
        writeLog("LogMonitorService: Set \(items.count) items for auto-matching", logLevel: .debug)
    }

    /// Stop all monitoring
    func stop() {
        writeLog("LogMonitorService: Stopping all monitors", logLevel: .info)

        // Stop all active file monitors
        activeMonitors.values.forEach { $0.stop() }
        activeMonitors.removeAll()

        // Stop all directory watchers
        fileCreationObservers.values.forEach { $0.stop() }
        fileCreationObservers.removeAll()

        // Clear state
        pendingConfigs.removeAll()
        DispatchQueue.main.async { [weak self] in
            self?.latestStatuses.removeAll()
            self?.globalStatus = nil
        }
    }

    /// Clear all statuses (useful when resetting state)
    func clearStatuses() {
        DispatchQueue.main.async { [weak self] in
            self?.latestStatuses.removeAll()
            self?.globalStatus = nil
        }
    }

    // MARK: - Private Methods

    private func registerForFileCreation(path: String, config: InspectConfig.LogMonitorConfig) {
        let parentDir = (path as NSString).deletingLastPathComponent

        // Check if we already have a watcher for this directory
        if fileCreationObservers[parentDir] != nil {
            writeLog("LogMonitorService: Already watching \(parentDir) for file creation", logLevel: .debug)
            return
        }

        // Create directory if it doesn't exist
        guard FileManager.default.fileExists(atPath: parentDir) else {
            writeLog("LogMonitorService: Parent directory doesn't exist: \(parentDir)", logLevel: .info)
            return
        }

        let watcher = DirectoryWatcher(path: parentDir) { [weak self] createdPath in
            guard createdPath == path else { return }
            writeLog("LogMonitorService: Detected file creation: \(path)", logLevel: .info)
            self?.startMonitor(for: config, at: path)
            // Remove the watcher since file now exists
            self?.fileCreationObservers.removeValue(forKey: parentDir)?.stop()
        }

        watcher.start()
        fileCreationObservers[parentDir] = watcher
        writeLog("LogMonitorService: Watching \(parentDir) for creation of \(path)", logLevel: .info)
    }

    private func startMonitor(for config: InspectConfig.LogMonitorConfig, at path: String) {
        guard activeMonitors[path] == nil else {
            writeLog("LogMonitorService: Monitor already active for \(path)", logLevel: .debug)
            return
        }

        let monitor = LogFileMonitor(config: config, path: path)
        monitor.onStatusExtracted = { [weak self] status in
            self?.handleStatus(status, itemId: nil, config: config)
        }
        monitor.onFileDeleted = { [weak self] in
            self?.handleFileDeletion(path: path, config: config)
        }
        monitor.start()
        activeMonitors[path] = monitor
        writeLog("LogMonitorService: Started monitoring \(path)", logLevel: .info)
    }

    private func handleFileDeletion(path: String, config: InspectConfig.LogMonitorConfig) {
        writeLog("LogMonitorService: Log file deleted: \(path)", logLevel: .info)
        // Remove the active monitor
        activeMonitors.removeValue(forKey: path)?.stop()
        // Re-register for file creation (handles log rotation)
        registerForFileCreation(path: path, config: config)
    }

    private func handleStatus(_ status: String, itemId: String?, config: InspectConfig.LogMonitorConfig) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Apply status cleanup for display
            let cleanedStatus = LogPatternPreset.cleanupStatus(status)
            guard !cleanedStatus.isEmpty else { return }

            self.globalStatus = cleanedStatus

            // If explicit itemIds configured, route to all listed items
            if let itemIds = config.itemIds, !itemIds.isEmpty {
                for id in itemIds {
                    self.latestStatuses[id] = cleanedStatus
                }
                writeLog("LogMonitorService: Status '\(cleanedStatus)' routed to itemIds: \(itemIds.joined(separator: ", "))", logLevel: .debug)
                return
            }

            // If explicit itemId configured, use it directly
            if let itemId = itemId ?? config.itemId {
                self.latestStatuses[itemId] = cleanedStatus
                writeLog("LogMonitorService: Status '\(cleanedStatus)' routed to itemId: \(itemId)", logLevel: .debug)
                return
            }

            // Auto-match against item displayNames and IDs
            // Use RAW status for matching (cleanupStatus strips displayNames like
            // "Downloading Microsoft Word …" → "Downloading..." which breaks auto-match)
            if config.autoMatch ?? true {
                let targetItems = self.findMatchingItems(for: status)
                for targetId in targetItems {
                    self.latestStatuses[targetId] = cleanedStatus
                }

                if targetItems.isEmpty {
                    writeLog("LogMonitorService: Status '\(cleanedStatus)' not matched to any item (raw: '\(status)')", logLevel: .debug)
                } else {
                    writeLog("LogMonitorService: Status '\(cleanedStatus)' routed to: \(targetItems.joined(separator: ", "))", logLevel: .debug)
                }
            }
        }
    }

    /// Find items whose displayName or ID appears in the status text
    private func findMatchingItems(for status: String) -> [String] {
        var matches: [String] = []
        for item in currentItems {
            if status.localizedCaseInsensitiveContains(item.displayName) ||
               status.localizedCaseInsensitiveContains(item.id) {
                matches.append(item.id)
            }
        }
        return matches
    }

    // MARK: - Testing Support

    #if DEBUG
    /// For testing: get current items
    func testGetCurrentItems() -> [InspectConfig.ItemConfig] {
        return currentItems
    }
    #endif
}

// MARK: - Log File Monitor

/// Monitors a single log file using DispatchSource
class LogFileMonitor {
    let config: InspectConfig.LogMonitorConfig
    let path: String
    var onStatusExtracted: ((String) -> Void)?  // status text
    var onFileDeleted: (() -> Void)?

    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastPosition: UInt64 = 0
    private var regex: NSRegularExpression?
    private let queue: DispatchQueue

    init(config: InspectConfig.LogMonitorConfig, path: String) {
        self.config = config
        self.path = path
        self.queue = DispatchQueue(label: "com.swiftdialog.logmonitor.\(path.hashValue)")
        self.regex = compileRegex()
    }

    private func compileRegex() -> NSRegularExpression? {
        let pattern: String

        if let custom = config.pattern {
            pattern = custom
        } else if let presetName = config.preset,
                  let preset = LogPatternPreset.presets[presetName.lowercased()] {
            pattern = preset.pattern
        } else {
            writeLog("LogFileMonitor: No pattern or preset specified for \(path)", logLevel: .error)
            return nil
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            writeLog("LogFileMonitor: Compiled regex for \(path)", logLevel: .debug)
            return regex
        } catch {
            writeLog("LogFileMonitor: Failed to compile regex '\(pattern)': \(error)", logLevel: .error)
            return nil
        }
    }

    func start() {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            writeLog("LogFileMonitor: Unable to open file: \(path)", logLevel: .error)
            return
        }
        fileHandle = handle

        // Start from end (only new content) if configured (default: true)
        if config.startFromEnd ?? true {
            handle.seekToEndOfFile()
            lastPosition = handle.offsetInFile
            writeLog("LogFileMonitor: Starting from end of file (offset: \(lastPosition))", logLevel: .debug)
        } else {
            lastPosition = 0
            writeLog("LogFileMonitor: Starting from beginning of file", logLevel: .debug)
        }

        let fd = handle.fileDescriptor
        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.extend, .write, .delete, .rename],
            queue: queue
        )

        dispatchSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = self.dispatchSource?.data ?? []

            if flags.contains(.delete) || flags.contains(.rename) {
                // File was deleted or renamed (log rotation)
                self.handleFileRemoval()
            } else if flags.contains(.extend) || flags.contains(.write) {
                self.processNewContent()
            }
        }

        dispatchSource?.setCancelHandler { [weak self] in
            try? self?.fileHandle?.close()
            self?.fileHandle = nil
        }

        dispatchSource?.resume()
        writeLog("LogFileMonitor: Started monitoring \(path)", logLevel: .info)
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        writeLog("LogFileMonitor: Stopped monitoring \(path)", logLevel: .debug)
    }

    private func handleFileRemoval() {
        writeLog("LogFileMonitor: File removed or renamed: \(path)", logLevel: .info)
        stop()
        onFileDeleted?()
    }

    private func processNewContent() {
        guard let handle = fileHandle, let regex = regex else { return }

        handle.seek(toFileOffset: lastPosition)
        let data = handle.readDataToEndOfFile()
        lastPosition = handle.offsetInFile

        guard let content = String(data: data, encoding: .utf8), !content.isEmpty else {
            return
        }

        // Determine preferred capture group
        let preferredCaptureGroup: Int
        if let group = config.captureGroup {
            preferredCaptureGroup = group
        } else if let presetName = config.preset,
                  let preset = LogPatternPreset.presets[presetName.lowercased()] {
            preferredCaptureGroup = preset.captureGroup
        } else {
            preferredCaptureGroup = 1
        }

        // Process each line
        for line in content.split(separator: "\n") {
            let lineStr = String(line)

            // Apply predicate filter if configured
            if let predicate = config.predicate, !predicate.isEmpty {
                guard lineStr.contains(predicate) else { continue }
            }

            let range = NSRange(lineStr.startIndex..., in: lineStr)

            if let match = regex.firstMatch(in: lineStr, range: range) {
                // Try preferred capture group first, then find first non-empty
                var extracted: String?

                if preferredCaptureGroup < match.numberOfRanges,
                   let captureRange = Range(match.range(at: preferredCaptureGroup), in: lineStr) {
                    let text = String(lineStr[captureRange])
                    if !text.isEmpty {
                        extracted = text
                    }
                }

                // Fallback: try all groups to find first non-empty
                if extracted == nil || extracted?.isEmpty == true {
                    for i in 1..<match.numberOfRanges {
                        if let captureRange = Range(match.range(at: i), in: lineStr) {
                            let text = String(lineStr[captureRange])
                            if !text.isEmpty {
                                extracted = text
                                break
                            }
                        }
                    }
                }

                if let status = extracted, !status.isEmpty {
                    writeLog("LogFileMonitor: Extracted status: '\(status)'", logLevel: .debug)
                    onStatusExtracted?(status)
                }
            }
        }
    }
}

// MARK: - Directory Watcher

/// Watches a directory for file creation events
private class DirectoryWatcher {
    private let path: String
    private let callback: (String) -> Void
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastContents: Set<String> = []
    private let queue = DispatchQueue(label: "com.swiftdialog.directorywatcher")

    init(path: String, callback: @escaping (String) -> Void) {
        self.path = path
        self.callback = callback

        // Cache initial contents
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
            lastContents = Set(contents)
        }
    }

    func start() {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            writeLog("DirectoryWatcher: Unable to open directory: \(path)", logLevel: .error)
            return
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        dispatchSource?.setEventHandler { [weak self] in
            self?.checkForNewFiles()
        }

        dispatchSource?.setCancelHandler {
            close(fd)
        }

        dispatchSource?.resume()
        writeLog("DirectoryWatcher: Started watching \(path)", logLevel: .debug)
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        writeLog("DirectoryWatcher: Stopped watching \(path)", logLevel: .debug)
    }

    private func checkForNewFiles() {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return
        }

        let currentContents = Set(contents)
        let newFiles = currentContents.subtracting(lastContents)
        lastContents = currentContents

        for filename in newFiles {
            let fullPath = (path as NSString).appendingPathComponent(filename)
            callback(fullPath)
        }
    }
}
