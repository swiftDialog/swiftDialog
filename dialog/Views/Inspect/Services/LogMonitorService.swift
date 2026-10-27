//
//  LogMonitorService.swift
//  dialog
//
//  Tails log files and extracts per-item status with regex presets (Installomator, Jamf, Munki, orbit,
//  macOS installer, …). Started by InspectState for configs with logMonitor(s), and by Preset 5 software steps.
//

import Foundation
import Combine

// MARK: - Log Pattern Presets

/// One extracted status, with the open scope and whether it matched a failure pattern.
struct LogStatusEvent {
    let text: String
    /// The item named by the last scope-opening line, for platforms whose terminal lines name nothing.
    let scope: String?
    /// True when the line matched the preset's `failurePattern`.
    let isFailure: Bool

    init(text: String, scope: String? = nil, isFailure: Bool = false) {
        self.text = text
        self.scope = scope
        self.isFailure = isFailure
    }
}

/// One row, reduced to the names a log line might use for it (id, display name, aliases).
struct LogRouteCandidate {
    let id: String
    let displayName: String
    /// Extra names from the item's `logAliases`, for logs that name the file rather than the item
    /// (e.g. "Example Utility-1.5.0.dmg").
    let aliases: [String]

    init(id: String, displayName: String, aliases: [String] = []) {
        self.id = id
        self.displayName = displayName
        self.aliases = aliases
    }
}

/// Named regex presets for common log formats.
/// Compiled log patterns, so a busy log does not compile the same patterns for every line.
/// The patterns come from the presets and the config, so the cap is never reached in practice.
final class LogPatternRegexCache: @unchecked Sendable {
    static let shared = LogPatternRegexCache()
    private let cache = NSCache<NSString, NSRegularExpression>()

    private init() { cache.countLimit = 64 }

    func regex(for pattern: String) -> NSRegularExpression? {
        if let cached = cache.object(forKey: pattern as NSString) { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        cache.setObject(regex, forKey: pattern as NSString)
        return regex
    }
}

struct LogPatternPreset {
    let pattern: String
    let captureGroup: Int

    /// A line meaning the item failed. Without it a row that entered "Downloading…" could never leave it.
    /// The capture must contain a routable name and wording `cleanupStatus` treats as failure.
    var failurePattern: String?

    /// A line meaning the item succeeded; matching emits exactly "Completed", which `InspectState` checks.
    var successPattern: String?

    /// A line that opens a named scope ("Installing Example (1 of 1)"); needed only when terminal lines
    /// name nothing.
    var scopePattern: String?

    init(pattern: String, captureGroup: Int,
         failurePattern: String? = nil, successPattern: String? = nil,
         scopePattern: String? = nil) {
        self.pattern = pattern
        self.captureGroup = captureGroup
        self.failurePattern = failurePattern
        self.successPattern = successPattern
        self.scopePattern = scopePattern
    }

    /// Classifies one log line into `InspectState`'s vocabulary, or nil if it says nothing about an item.
    /// Failure and success are tested before progress, so "Download of X failed" never reads as running.
    static func status(for line: String, using preset: LogPatternPreset) -> String? {
        if let failure = preset.failurePattern,
           let captured = firstCapture(in: line, pattern: failure, group: 1) {
            // No "Failed: " prefix here; `cleanupStatus` adds it.
            return captured
        }
        if let success = preset.successPattern,
           firstCapture(in: line, pattern: success, group: 0) != nil {
            return "Completed"
        }
        return firstCapture(in: line, pattern: preset.pattern, group: preset.captureGroup)
    }

    /// The item a line opens a scope for, or nil. Munki's terminal lines name nothing:
    ///
    ///     Installing Example (1 of 1)                  <- opens a scope
    ///     The software was successfully installed.     <- names nothing
    ///
    /// Download lines name the file, not the item, so they never open a scope.
    static func scopeName(for line: String, using preset: LogPatternPreset) -> String? {
        guard let scope = preset.scopePattern else { return nil }
        return firstCapture(in: line, pattern: scope, group: 1)
    }

    /// Which items a status line belongs to: first by the line's own text (id, displayName, `logAliases`),
    /// else by the open scope, else none. Never every row: one install must not complete a whole list.
    static func routeTargets(status: String, scope: String?,
                             items: [LogRouteCandidate]) -> [String] {
        func matches(_ text: String) -> [String] {
            items.filter { candidate in
                ([candidate.displayName, candidate.id] + candidate.aliases)
                    .contains { !$0.isEmpty && text.localizedCaseInsensitiveContains($0) }
            }.map(\.id)
        }
        let direct = matches(status)
        if !direct.isEmpty { return direct }
        guard let scope else { return [] }
        return matches(scope)
    }

    /// Whether the line matched a terminal pattern; asked separately because the failure capture has no prefix.
    static func isTerminal(line: String, preset: LogPatternPreset) -> Bool {
        if let failure = preset.failurePattern,
           firstCapture(in: line, pattern: failure, group: 1) != nil { return true }
        if let success = preset.successPattern,
           firstCapture(in: line, pattern: success, group: 0) != nil { return true }
        return false
    }

    static func firstCapture(in line: String, pattern: String, group: Int) -> String? {
        guard let regex = LogPatternRegexCache.shared.regex(for: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              group < match.numberOfRanges,
              let captured = Range(match.range(at: group), in: line) else { return nil }
        return String(line[captured])
    }

    static let presets: [String: LogPatternPreset] = [
        // Installomator: "2026-02-22 15:23:13 : INFO  : exampleapp : Downloading https://..."
        // Format: timestamp : LEVEL : label : message. Auto-match works because paths contain app names.
        "installomator": LogPatternPreset(
            pattern: #": (?:INFO|DEBUG|REQ|WARN)\s+: \w+ : ((?:Downloading|Mounted|Mounting|Verifying|Copy|Copying|Installing|Unpacking|Unzipping|Removing|Running|Extracting):?\s+.+?(?:\.dmg|\.pkg|\.zip|\.app|$)|(?:Installed|Downloaded) version: [\d.]+|\d+%)"#,
            captureGroup: 1,
            // Failure shape: "2026-08-20 06:32:51 : ERROR : desktoppr : ERROR: not running as root, exiting".
            // The inner "ERROR: " is dropped because `cleanupStatus` adds its own "Failed" prefix.
            failurePattern: #": ERROR\s+: \w+ : (?:ERROR: )?(.+)$"#,
            // Success shape: "2026-08-19 22:42:57 : REQ   : desktoppr : Installed desktoppr, version 0.5-218".
            successPattern: #": REQ\s+: \w+ : Installed .+?, version"#,
            // Every line names the label in its third field; the failure capture drops it, so the scope supplies it.
            scopePattern: #": (?:INFO|DEBUG|REQ|WARN|ERROR)\s+: (\w+) :"#
        ),
        // orbit: /var/log/orbit/orbit.stderr.log
        //   INF about to download software installer from Fleet installerID=edcf… runner=installer
        //   INF software installer downloaded installerID=edcf… installerPath=/tmp/…/ExampleApp.pkg
        //   INF about to run install script installerID=edcf… runner=installer
        //   INF install script exitCode=0 installerID=edcf… runner=installer
        // Lines are keyed by an opaque installer id; only `installerPath` names the software, so the filename
        // opens the scope. Installs run one at a time. The `agent` preset does not fit this log.
        "orbit": LogPatternPreset(
            pattern: #"INF (about to download software installer|software installer downloaded|about to run install script)"#,
            captureGroup: 1,
            // The exit code is the terminal signal; non-zero means failure.
            failurePattern: #"install script exitCode=([1-9]\d*)"#,
            successPattern: #"install script exitCode=0\b"#,
            // The filename from the one line that carries it.
            scopePattern: #"installerPath=\S*/([^/\s]+)"#
        ),

        // Jamf: system log lines such as
        //   Thu Aug 20 06:59:07 HOSTNAME jamf[33329]: Successfully installed Example-1.12.7.pkg.
        // The hostname may contain spaces, so `jamf[<pid>]: ` is the anchor.
        "jamf": LogPatternPreset(
            // Only verbs seen in real logs; add more when a log shows them.
            pattern: #"jamf\[\d+\]: (Executing Policy .*)$"#,
            captureGroup: 1,
            // Not set: the failures jamf logs are device-level (inventory, enrollment), not per item.
            failurePattern: nil,
            // "Successfully installed Example-1.12.7.pkg."
            successPattern: #"jamf\[\d+\]: Successfully installed .+\.pkg"#,
            // The package name becomes the scope so "Completed" can be routed; other names need `logAliases`.
            scopePattern: #"Successfully installed (.+?)\.pkg"#
        ),
        // Munki (ManagedSoftwareUpdate.log): "TIMESTAMP message", e.g. "2026-07-06 09:53:12.758+02:00 Installing
        // Example".
        // Only install-phase lines are captured, not manifest or catalog noise.
        "munki": LogPatternPreset(
            pattern: #"^\d{4}-\d{2}-\d{2} [\d:.]+[+-]\d{2}:\d{2}\s+((?:Installing|Downloading|Removing|Staging)\b.*)$"#,
            captureGroup: 1,
            // "WARNING: Download of exampleutility failed: error -1001: The request timed out."
            // Keeps the munki item id, the only routable name on a failure.
            failurePattern: #"WARNING: Download of (\S+ failed:.*)$"#,
            // Anonymous success lines ("The software was successfully installed/removed."); see scopePattern.
            successPattern: #"The software was successfully (?:installed|removed)\."#,
            // The only munki line naming the item at install time; download lines name the file.
            scopePattern: #"(?:Installing|Removing) (\S+) \(\d+ of \d+\)"#
        ),
        // Generic shell scripts: [STATUS] message
        "shell": LogPatternPreset(
            pattern: #"^\[STATUS\]\s+(.+)$"#,
            captureGroup: 1
        ),
        // Generic MDM installer pattern: process.name: message
        "mdm-installer": LogPatternPreset(
            pattern: #"[\w.-]+\.installer:\s*(.+?)(?:\s*$)"#,
            captureGroup: 1
        ),
        // Generic agent/daemon pattern: process: INFO/DEBUG message
        "agent": LogPatternPreset(
            pattern: #"[\w.-]+:\s*(?:INFO|DEBUG)?\s*(.+?)(?:\s*$)"#,
            captureGroup: 1
        ),
        // macOS installer log (/private/var/log/install.log), present regardless of MDM; fixtures are in
        // LogMonitorServiceTests. Terminal wording lives in the terminal patterns so a row can finish.
        "macos-installer": LogPatternPreset(
            // Progress: "installd[3283]: PackageKit: Extracting file:///…/example.pkg#app.pkg (destination=…)"
            // and "installd[3283]: PackageKit: Touched bundle /Applications/Example.app". The path is what routing
            // matches.
            pattern: #"PackageKit: ((?:Extracting|Touched bundle) .+)$"#,
            captureGroup: 1,
            // Failures (Installer.app text is localized, so only the English anchors are matched):
            //   "installer[84834]: Install failed: The Installer encountered an error …"
            //   "installd[1438]: PackageKit: Install Failed: Error Domain=PKInstallErrorDomain …"
            // The colon excludes UI chatter such as "Displaying 'Install Failed' UI."
            failurePattern: #"(?:Install failed|PackageKit: Install Failed): (.+)$"#,
            // "installd[3283]: Installed \"Example\" (1.2.3)"; also written by system_installd. The version may be
            // empty.
            successPattern: #"installd\[\d+\]: Installed \""#,
            // The app name becomes the scope. An empty title (Installed "") opens no scope, so it cannot attach to
            // another row.
            scopePattern: #"Installed \"([^\"]+)\" \("#
        )
    ]

    /// Turns raw log text into a display status.
    /// - Parameter isFailure: the line matched a failure pattern. When false, failure is inferred from the
    ///   wording, for statuses without that knowledge (JSON monitors, presets without failurePattern).
    static func cleanupStatus(_ raw: String, isFailure: Bool = false) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        if isFailure {
            // Never add a second "Failed" prefix.
            if trimmed.lowercased().hasPrefix("failed") { return trimmed }
            let maxLength = 60
            return trimmed.count > maxLength
                ? "Failed: \(String(trimmed.prefix(maxLength)))..."
                : "Failed: \(trimmed)"
        }

        // Skip bundle ID lines.
        if trimmed.hasPrefix("com.") { return "" }

        // "Installed version: 1.85.0" → "Installed (v1.85.0)"
        if trimmed.hasPrefix("Installed version:") || trimmed.hasPrefix("Downloaded version:") {
            let version = trimmed
                .replacingOccurrences(of: "Installed version: ", with: "")
                .replacingOccurrences(of: "Downloaded version: ", with: "")
            return "Installed (v\(version))"
        }

        // Progress percentage, e.g. "75%".
        if trimmed.range(of: #"^\d+%$"#, options: .regularExpression) != nil {
            return "Downloading \(trimmed)"
        }

        if trimmed.hasPrefix("Downloading ") { return "Downloading..." }
        if trimmed.hasPrefix("Mounting ") || trimmed.hasPrefix("Mounted ") { return "Mounting..." }
        if trimmed.hasPrefix("Unpacking ") { return "Unpacking..." }
        if trimmed.hasPrefix("Unzipping ") { return "Unpacking..." }   // Installomator uses "Unzipping <archive>"
        if trimmed.hasPrefix("Extracting ") { return "Extracting..." }
        if trimmed.hasPrefix("Removing ") { return "Cleaning up..." }
        if trimmed.hasPrefix("Running ") { return "Running script..." }
        if trimmed.contains("installed successfully") { return "Completed" }
        if trimmed == "Installation completed" { return "Completed" }

        // Copy/Copying: extract the app name ("Copy Example.app to /Applications").
        if trimmed.hasPrefix("Copy ") || trimmed.hasPrefix("Copying ") {
            let stripped = trimmed.hasPrefix("Copy ") ?
                trimmed.replacingOccurrences(of: "Copy ", with: "") :
                trimmed.replacingOccurrences(of: "Copying ", with: "")
            let parts = stripped.components(separatedBy: " to ")
            if let appName = parts.first { return "Copying \(appName)..." }
            return "Copying..."
        }

        // A touched bundle is mid-install; checked before the ".app" branch so it never completes the row.
        if trimmed.hasPrefix("Touched bundle ") { return "Installing..." }

        // A bare .app path means complete.
        if trimmed.hasSuffix(".app") { return "Completed" }

        // .pkg lines: package name with its phase keyword.
        if trimmed.contains(".pkg") {
            // Leading phase keyword, e.g. "Installing foo.pkg" or "Verifying: foo.pkg".
            var phase = "Installing"
            var remainder = trimmed
            for keyword in ["Installing", "Verifying", "Downloading"] where trimmed.hasPrefix(keyword) {
                phase = keyword
                remainder = String(trimmed.dropFirst(keyword.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                break
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

        let lowercased = trimmed.lowercased()
        if lowercased.contains("fail") || lowercased.contains("error") {
            let maxLength = 50
            if trimmed.count > maxLength {
                return "Failed: \(String(trimmed.prefix(maxLength)))..."
            }
            return trimmed.isEmpty ? "Failed" : "Failed: \(trimmed)"
        }

        // Add a trailing ellipsis to action verbs.
        if trimmed.hasPrefix("Installing ") || trimmed.hasPrefix("Verifying ") {
            return "\(trimmed)..."
        }

        return trimmed
    }
}

// MARK: - Log Monitor Service

/// Tails log files and publishes per-item status. `@MainActor`: its `@Published` state is read by SwiftUI,
/// `InspectState` and `MonitoringModule`. `LogFileMonitor` reads on its own queue; `onStatusExtracted`
/// is the one crossing and hops explicitly. The `DispatchQueue.main.async` hops in `handleStatus` and
/// `stop` stay: tests rely on their FIFO ordering.
@MainActor
class LogMonitorService: ObservableObject {

    // MARK: - Singleton

    static let shared = LogMonitorService()

    // MARK: - Published Properties

    @Published private(set) var latestStatuses: [String: String] = [:]  // itemId -> status
    @Published private(set) var globalStatus: String?

    // MARK: - Private Properties

    private var pendingConfigs: [InspectConfig.LogMonitorConfig] = []
    private var activeMonitors: [String: LogFileMonitor] = [:]  // path -> monitor
    /// `fleet` monitors read orbit's Setup Experience files instead of tailing a log.
    private var fleetSources: [String: FleetSetupSource] = [:]  // snapshot path -> source
    private var currentItems: [any MonitoredItem] = []
    private var fileCreationObservers: [String: DirectoryWatcher] = [:]  // awaited file -> watcher

    // MARK: - Initialization

    private init() {
        writeLog("LogMonitorService: Initialized", logLevel: .debug)
    }

    // MARK: - Public API

    /// Configures the service from an InspectConfig.
    func configure(with config: InspectConfig) {
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

            // `fleet` is not a log: FleetSetupSource sends row states as commands and waits for its own files.
            if monitorConfig.preset?.lowercased() == "fleet" {
                // Every row in the config, so the reader can add rows only for names nothing matches.
                let rows = Self.allRows(config, plus: currentItems)
                if let source = fleetSources[path] {
                    source.setProfilesRow(config.showProfilesRow ?? true)
                    source.setItems(rows)
                } else {
                    let expand = { (p: String) in (p as NSString).expandingTildeInPath }
                    let source = FleetSetupSource(snapshotPath: path,
                                                  eventsPath: monitorConfig.eventsPath.map(expand),
                                                  serverURL: monitorConfig.serverURL,
                                                  profilesRow: config.showProfilesRow ?? true,
                                                  items: rows)
                    fleetSources[path] = source
                    source.start()
                }
                continue
            }

            if FileManager.default.fileExists(atPath: path) {
                startMonitor(for: monitorConfig, at: path)
            } else {
                // Wait for the file to be created.
                registerForFileCreation(path: path, config: monitorConfig)
            }
        }
    }

    // OSLogStore is not used: third-party apps cannot get com.apple.logging.local-store. Have the installer
    // write a log file and monitor it with a matching preset.

    /// The config's items, every step's items and `extra`, once each by id.
    static func allRows(_ config: InspectConfig, plus extra: [any MonitoredItem] = []) -> [any MonitoredItem] {
        var seen = Set<String>()
        let all: [any MonitoredItem] = config.items + (config.introSteps ?? []).flatMap { $0.items ?? [] } + extra
        return all.filter { seen.insert($0.id).inserted }
    }

    /// Sets the items used for auto-matching.
    func setItems(_ items: [any MonitoredItem]) {
        currentItems = items
        writeLog("LogMonitorService: Set \(items.count) items for auto-matching", logLevel: .debug)
    }

    /// Stops all monitoring.
    func stop() {
        writeLog("LogMonitorService: Stopping all monitors", logLevel: .info)

        activeMonitors.values.forEach { $0.stop() }
        activeMonitors.removeAll()
        fleetSources.values.forEach { $0.stop() }
        fleetSources.removeAll()

        fileCreationObservers.values.forEach { $0.stop() }
        fileCreationObservers.removeAll()

        pendingConfigs.removeAll()
        DispatchQueue.main.async { [weak self] in
            self?.latestStatuses.removeAll()
            self?.globalStatus = nil
        }
    }

    // MARK: - Private Methods

    private func registerForFileCreation(path: String, config: InspectConfig.LogMonitorConfig) {
        let parentDir = (path as NSString).deletingLastPathComponent

        // One watcher per awaited file.
        if fileCreationObservers[path] != nil {
            writeLog("LogMonitorService: Already watching \(parentDir) for \(path)", logLevel: .debug)
            return
        }

        // No parent directory to watch: the monitor stays unstarted.
        guard FileManager.default.fileExists(atPath: parentDir) else {
            writeLog("LogMonitorService: Parent directory doesn't exist: \(parentDir)", logLevel: .info)
            return
        }

        // The watcher calls back on its own queue; service state is main-actor.
        let watcher = DirectoryWatcher(path: parentDir) { [weak self] createdPath in
            guard createdPath == path else { return }
            Task { @MainActor in self?.fileAppeared(path: path, config: config) }
        }

        watcher.start()
        fileCreationObservers[path] = watcher
        writeLog("LogMonitorService: Watching \(parentDir) for creation of \(path)", logLevel: .info)
        // Created between the check and the watcher's first listing.
        if FileManager.default.fileExists(atPath: path) { fileAppeared(path: path, config: config) }
    }

    private func fileAppeared(path: String, config: InspectConfig.LogMonitorConfig) {
        guard let watcher = fileCreationObservers.removeValue(forKey: path) else { return }
        watcher.stop()
        writeLog("LogMonitorService: Detected file creation: \(path)", logLevel: .info)
        startMonitor(for: config, at: path)
    }

    private func startMonitor(for config: InspectConfig.LogMonitorConfig, at path: String) {
        guard activeMonitors[path] == nil else {
            writeLog("LogMonitorService: Monitor already active for \(path)", logLevel: .debug)
            return
        }

        let monitor = LogFileMonitor(config: config, path: path)
        // The isolation crossing: `LogFileMonitor` calls back on its own queue, so hop to the main actor here.
        monitor.onStatusExtracted = { [weak self] event in
            Task { @MainActor in self?.handleStatus(event, itemId: nil, config: config) }
        }
        monitor.onFileDeleted = { [weak self] in
            Task { @MainActor in self?.handleFileDeletion(path: path, config: config) }
        }
        monitor.start()
        activeMonitors[path] = monitor
        writeLog("LogMonitorService: Started monitoring \(path)", logLevel: .info)
    }

    private func handleFileDeletion(path: String, config: InspectConfig.LogMonitorConfig) {
        writeLog("LogMonitorService: Log file deleted: \(path)", logLevel: .info)
        activeMonitors.removeValue(forKey: path)?.stop()
        // Log rotation: the new log usually exists already; otherwise wait for it.
        if FileManager.default.fileExists(atPath: path) {
            startMonitor(for: config, at: path)
        } else {
            registerForFileCreation(path: path, config: config)
        }
    }

    private func handleStatus(_ event: LogStatusEvent, itemId: String?,
                              config: InspectConfig.LogMonitorConfig) {
        let status = event.text
        let scope = event.scope
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let cleanedStatus = LogPatternPreset.cleanupStatus(status, isFailure: event.isFailure)
            guard !cleanedStatus.isEmpty else { return }

            self.globalStatus = cleanedStatus

            // Explicit itemIds: route to all listed items.
            if let itemIds = config.itemIds, !itemIds.isEmpty {
                for id in itemIds {
                    self.latestStatuses[id] = cleanedStatus
                }
                writeLog("LogMonitorService: Status '\(cleanedStatus)' routed to itemIds: \(itemIds.joined(separator: ", "))", logLevel: .debug)
                return
            }

            // Explicit itemId: use it directly.
            if let itemId = itemId ?? config.itemId {
                self.latestStatuses[itemId] = cleanedStatus
                writeLog("LogMonitorService: Status '\(cleanedStatus)' routed to itemId: \(itemId)", logLevel: .debug)
                return
            }

            // Auto-match on the raw status; cleanupStatus strips the names matching needs.
            if config.autoMatch ?? true {
                // `scope` lets anonymous terminal lines reach the right row (see LogPatternPreset.routeTargets).
                var targetItems = self.findMatchingItems(for: status, scope: scope)
                // `addRows`: an item with no row gets one via `listitem: add`, then is routed to.
                if targetItems.isEmpty, config.addRows == true, let added = self.addRow(named: scope) {
                    targetItems = [added]
                }
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

    /// A row for an item the log names and no row matches: id `app-<name, a–z0–9>`, announced with
    /// `listitem: add`. A name without spaces is a file or label and loses its version; a name with spaces
    /// is a title and is kept whole.
    static func addedRow(named name: String?) -> (id: String, title: String)? {
        guard let raw = name?.trimmingCharacters(in: .whitespaces), !FleetSetup.slug(raw).isEmpty else { return nil }
        let title = raw.contains(" ") ? raw : FleetSetup.title(fromFilename: raw.contains(".") ? raw : raw + ".x")   // ".x": a name with no extension keeps all of itself
        return ("app-" + FleetSetup.slug(title), title.replacingOccurrences(of: ",", with: " "))
    }

    private func addRow(named scope: String?) -> String? {
        guard let (id, name) = Self.addedRow(named: scope) else { return nil }
        if !currentItems.contains(where: { $0.id == id }) {
            currentItems.append(InspectConfig.ItemConfig(id: id, displayName: name))
            DialogNotifications.dispatchLocally("listitem: add, id: \(id), title: \(name)")
            writeLog("LogMonitorService: added a row for '\(name)' (\(id))", logLevel: .info)
        }
        return id
    }

    /// Items whose displayName or id appears in the status, else the open scope (`LogPatternPreset.routeTargets`).
    private func findMatchingItems(for status: String, scope: String? = nil) -> [String] {
        LogPatternPreset.routeTargets(
            status: status, scope: scope,
            items: currentItems.map {
                LogRouteCandidate(id: $0.id, displayName: $0.displayName,
                                  aliases: $0.logAliases ?? [])
            })
    }

}

// MARK: - Log File Monitor

/// Monitors a single log file with a DispatchSource.
class LogFileMonitor {
    let config: InspectConfig.LogMonitorConfig
    let path: String
    var onStatusExtracted: ((LogStatusEvent) -> Void)?

    /// The item named by the last scope-opening line. Kept until a terminal line consumes it, so an anonymous
    /// line from the next install cannot fall back onto the previous one.
    private var currentScope: String?  // the captured item name
    var onFileDeleted: (() -> Void)?

    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastPosition: UInt64 = 0
    private var regex: NSRegularExpression?
    private let queue: DispatchQueue

    /// The named preset, for its terminal and scope patterns (`compileRegex` uses only the progress pattern).
    private let resolvedPreset: LogPatternPreset?

    init(config: InspectConfig.LogMonitorConfig, path: String) {
        self.config = config
        self.path = path
        self.queue = DispatchQueue(label: "com.swiftdialog.logmonitor.\(path.hashValue)")
        // A custom `pattern` replaces the preset entirely, terminal patterns included.
        self.resolvedPreset = config.pattern == nil
            ? config.preset.flatMap { LogPatternPreset.presets[$0.lowercased()] }
            : nil
        self.regex = compileRegex()
    }

    /// Whether this monitor parses a JSON status file instead of matching lines.
    private var isJSONFormat: Bool {
        config.format?.lowercased() == "json"
    }

    private func compileRegex() -> NSRegularExpression? {
        if isJSONFormat { return nil }

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

        // Start from the end (new content only) unless configured otherwise.
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
                // Deleted or renamed (log rotation).
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
        guard let handle = fileHandle else { return }

        // JSON status files are rewritten whole, so re-read the entire file.
        if isJSONFormat {
            processJSONContent(handle: handle)
            return
        }

        guard let regex = regex else { return }

        // Truncated in place (copy-truncate rotation): read from the start.
        if handle.seekToEndOfFile() < lastPosition { lastPosition = 0 }
        handle.seek(toFileOffset: lastPosition)
        let data = handle.readDataToEndOfFile()

        // Whole lines only: a partial line waits for the next read.
        guard let newline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        let whole = data[data.startIndex...newline]
        lastPosition += UInt64(whole.count)
        guard let content = String(bytes: whole, encoding: .utf8) else { return }

        let preferredCaptureGroup: Int
        if let group = config.captureGroup {
            preferredCaptureGroup = group
        } else if let presetName = config.preset,
                  let preset = LogPatternPreset.presets[presetName.lowercased()] {
            preferredCaptureGroup = preset.captureGroup
        } else {
            preferredCaptureGroup = 1
        }

        for line in content.split(separator: "\n") {
            let lineStr = String(line)

            // Apply the predicate filter, if configured.
            if let predicate = config.predicate, !predicate.isEmpty {
                guard lineStr.contains(predicate) else { continue }
            }

            // Update the scope before classifying, so an opening line also reports progress.
            if let preset = resolvedPreset,
               let scope = LogPatternPreset.scopeName(for: lineStr, using: preset) {
                currentScope = scope
                writeLog("LogFileMonitor: Scope opened: '\(scope)'", logLevel: .debug)
            }

            // Terminal states before progress, so "Download of X failed" never reads as running.
            if let preset = resolvedPreset,
               preset.failurePattern != nil || preset.successPattern != nil,
               let terminal = LogPatternPreset.status(for: lineStr, using: preset),
               LogPatternPreset.isTerminal(line: lineStr, preset: preset) {
                writeLog("LogFileMonitor: Terminal status: '\(terminal)' scope=\(currentScope ?? "none")", logLevel: .debug)
                onStatusExtracted?(LogStatusEvent(
                    text: terminal, scope: currentScope,
                    isFailure: preset.failurePattern.map {
                        LogPatternPreset.firstCapture(in: lineStr, pattern: $0, group: 1) != nil
                    } ?? false))
                // The scope is spent; cleared after the emit because the terminal line may need it.
                currentScope = nil
                continue
            }

            let range = NSRange(lineStr.startIndex..., in: lineStr)

            if let match = regex.firstMatch(in: lineStr, range: range) {
                // Preferred capture group first, then the first non-empty one.
                var extracted: String?

                if preferredCaptureGroup < match.numberOfRanges,
                   let captureRange = Range(match.range(at: preferredCaptureGroup), in: lineStr) {
                    let text = String(lineStr[captureRange])
                    if !text.isEmpty {
                        extracted = text
                    }
                }

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
                    onStatusExtracted?(LogStatusEvent(text: status, scope: currentScope))
                }
            }
        }
    }

    /// Parses the whole file as JSON and emits the value at `statusKey` (default "status") as a string.
    private func processJSONContent(handle: FileHandle) {
        handle.seek(toFileOffset: 0)
        let data = handle.readDataToEndOfFile()
        lastPosition = handle.offsetInFile

        guard !data.isEmpty,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }

        let statusKey = config.statusKey ?? "status"
        guard let rawValue = object[statusKey] else {
            writeLog("LogFileMonitor: JSON status key '\(statusKey)' not found in \(path)", logLevel: .debug)
            return
        }

        // Normalize the value to a string.
        let status: String
        if let s = rawValue as? String {
            status = s
        } else {
            status = String(describing: rawValue)
        }

        guard !status.isEmpty else { return }
        writeLog("LogFileMonitor: Extracted JSON status: '\(status)'", logLevel: .debug)
        // No scope: JSON status files carry their own itemKey.
        onStatusExtracted?(LogStatusEvent(text: status))
    }
}

// MARK: - Directory Watcher

/// Watches a directory for file creation.
private class DirectoryWatcher {
    private let path: String
    private let callback: (String) -> Void
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastContents: Set<String> = []
    private let queue = DispatchQueue(label: "com.swiftdialog.directorywatcher")

    init(path: String, callback: @escaping (String) -> Void) {
        self.path = path
        self.callback = callback

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
