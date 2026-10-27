//
//  InspectState+InstallationDetection.swift
//  dialog
//
//  The 2 s poller: path and cache detection, command-file parsing, side-message rotation.
//

import SwiftUI

extension InspectState {
    // MARK: - FileMonitorDelegate
    
    func updateAppStatus() {
        checkCommandFileForUpdates()
        checkDirectInstallationStatus()
    }
    
    /// Adopts the command file's current content when monitoring starts, so only lines written
    /// afterwards are processed. Seeding here rather than on the first look keeps a script's first
    /// command, written in the gap before the first poll or write event, from being adopted unrun.
    func seedCommandFileCursor() {
        let commandFilePath = InspectConstants.commandFilePath
        let content = (try? String(contentsOfFile: commandFilePath, encoding: .utf8)) ?? ""
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        lastCommandFileSize = content.count
        lastProcessedLineCount = lines.count
        commandFileCursorSeeded = true
        if !lines.isEmpty {
            writeLog("InspectState: Adopted \(lines.count) pre-existing command line(s) at "
                     + "\(commandFilePath) without replaying them", logLevel: .info)
        }
    }

    func checkCommandFileForUpdates() {
        let commandFilePath = InspectConstants.commandFilePath

        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            return
        }

        do {
            let content = try String(contentsOfFile: commandFilePath, encoding: .utf8)
            let currentSize = content.count

            // Empty lines are not counted, or a trailing newline would skip real content.
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            if commandFileCursorSeeded && currentSize == lastCommandFileSize { return }

            let newLines = CommandFileReplayGuard.linesToProcess(
                allLines: lines,
                lastProcessedLineCount: lastProcessedLineCount,
                seeded: commandFileCursorSeeded)

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
    
    func checkDirectInstallationStatus() {
        guard !items.isEmpty else { return }

        var changesDetected = false

        // Pruning expired removal notices here is what redraws the row: no `@Published` value
        // changes on its own when the dwell passes.
        let expired = AppInspector.expiredNotices(removedItems)
        if !expired.isEmpty {
            self.debouncedUpdater.debounce(key: "removal-notice-prune") { [weak self] in
                guard let self else { return }
                for id in expired { self.removedItems.removeValue(forKey: id) }
            }
        }

        let receiptsBasePath = config?.receiptsBasePath ?? "/var/db/receipts"
        for item in items {
            // Declared requirements replace the paths/plist checks, as the schema documents, so such an
            // item needs no paths.
            let requirementVerdict = RequirementEvaluator.evaluate(item, receiptsBasePath: receiptsBasePath)
            // Log words name what decided: declared requirements, or the paths and cache files.
            let source = requirementVerdict != nil ? "REQUIREMENTS" : "FILESYSTEM"
            let gone = requirementVerdict != nil ? "requirements no longer met" : "deleted"
            guard requirementVerdict != nil || !item.paths.isEmpty else {
                writeLog("InspectState: Skipping filesystem check for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            let wasCompleted = completedItems.contains(item.id)
            let wasDownloading = downloadingItems.contains(item.id)
            
            // Glob-aware; a path without glob magic keeps exact-match semantics.
            let fileExists = item.paths.first { path in
                PathGlob.exists(atPath: path)
            } != nil

            // With plistKey + evaluation, the file existing is not enough; the value must pass.
            let isInstalled: Bool
            if let requirementVerdict {
                isInstalled = requirementVerdict.done
            } else if fileExists, let plistKey = item.plistKey, !plistKey.isEmpty, let evaluation = item.evaluation {
                let plistPath = item.paths.first { $0.hasSuffix(".plist") } ?? item.paths.first ?? ""
                let expandedPath = (plistPath as NSString).expandingTildeInPath
                let actualValue: String?
                if item.useUserDefaults == true {
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
                // The only engine with a baseline, so the only one that answers `changed`.
                switch EvaluationOperator(authored: evaluation) {
                case .changed:
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
                case .exists:
                    isInstalled = actualValue != nil && !actualValue!.isEmpty
                case .boolean:
                    isInstalled = actualValue == "1" || actualValue?.lowercased() == "true"
                case .contains:
                    // An array value arrives stringified, so it can only substring-match.
                    isInstalled = EvaluationOperator.containsMatch(value: actualValue as Any,
                                                                   expected: item.expectedValue)
                case .range:
                    if let actual = Int(actualValue ?? ""),
                       let parts = item.expectedValue?.split(separator: "-"),
                       parts.count == 2,
                       let lo = Int(parts[0]), let hi = Int(parts[1]) {
                        isInstalled = actual >= lo && actual <= hi
                    } else {
                        isInstalled = false
                    }
                case .equals:
                    isInstalled = actualValue == item.expectedValue
                case nil:
                    writeLog("InspectState: unknown evaluation '\(evaluation)' on "
                             + "\(item.id) — treating as not installed", logLevel: .error)
                    isInstalled = false
                case .withinSeconds:
                    // Only `Validation` parses dates.
                    isInstalled = false
                }
            } else {
                isInstalled = fileExists
            }

            let isDownloading = !isInstalled && checkCacheForItem(item)
            // Read before this scan records it: a failure that arrived while the path was already
            // there (a failed update) stands; the poller may only clear a failure when the path
            // appears after it (a retry that worked).
            let sawInstalledBefore = pathCheckSawInstalled.contains(item.id)
            let failureStands = failedItems.contains(item.id) && sawInstalledBefore
            // The marker tracks the path, whatever the item's state: an absent path resets it, so
            // a failed item whose app is removed and put back counts as a new install.
            if isInstalled { pathCheckSawInstalled.insert(item.id) } else { pathCheckSawInstalled.remove(item.id) }
            if isDownloading { pathCheckSawCaching.insert(item.id) }

            // Kept in step with completedItems, or the row flashes "Failed" until validation catches up.
            if item.plistKey != nil && item.evaluation != nil {
                self.plistValidationResults[item.id] = isInstalled
            }

            // A reinstall clears the removal notice.
            if isInstalled, removedItems[item.id] != nil {
                self.debouncedUpdater.debounce(key: "item-unremove-\(item.id)") { [weak self] in
                    self?.removedItems.removeValue(forKey: item.id)
                }
            }

            if isInstalled && !wasCompleted && !failureStands {
                let words = DetectionLog.pollerWords(wasCompleted: wasCompleted, wasDownloading: wasDownloading,
                                                     isInstalled: isInstalled, isDownloading: isDownloading)
                self.debouncedUpdater.debounce(key: "item-install-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    DetectionLog.note(itemId: item.id, from: words.from, to: words.to,
                                      by: requirementVerdict != nil ? .requirements : .poller)
                    // Through ItemLifecycle, so completing also clears failed: never both.
                    self.applyItemStatus(item.id, .completed)
                }
                writeLog("InspectState: \(source) - \(item.displayName) detection completed", logLevel: .info)
                changesDetected = true

            } else if !isInstalled && wasCompleted && sawInstalledBefore {
                // A completed item whose path the check never saw came from a script, and stands.
                if isDownloading {
                    self.debouncedUpdater.debounce(key: "item-download-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.insert(item.id)
                    }
                    writeLog("InspectState: \(source) - \(item.displayName) \(gone) but still downloading", logLevel: .info)
                } else {
                    self.debouncedUpdater.debounce(key: "item-remove-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.remove(item.id)
                        // The state stays pending; only the row's word changes, for the dwell.
                        self.removedItems[item.id] = Date()
                        let words = DetectionLog.pollerWords(wasCompleted: wasCompleted, wasDownloading: wasDownloading,
                                                             isInstalled: isInstalled, isDownloading: isDownloading)
                        DetectionLog.note(itemId: item.id, from: words.from, to: words.to,
                                          by: requirementVerdict != nil ? .requirements : .poller)
                    }
                    writeLog("InspectState: \(source) - \(item.displayName) \(gone), reset to pending with a removal notice", logLevel: .info)
                }
                changesDetected = true

            } else if isDownloading && !wasDownloading {
                self.debouncedUpdater.debounce(key: "item-downloading-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    self.downloadingItems.insert(item.id)
                    let words = DetectionLog.pollerWords(wasCompleted: wasCompleted, wasDownloading: wasDownloading,
                                                         isInstalled: isInstalled, isDownloading: isDownloading)
                    DetectionLog.note(itemId: item.id, from: words.from, to: words.to,
                                      by: requirementVerdict != nil ? .requirements : .poller)
                    writeLog("InspectState: Added \(item.id) to downloadingItems (cache detected)", logLevel: .info)
                }
                writeLog("InspectState: FILESYSTEM - \(item.displayName) downloading", logLevel: .info)
                changesDetected = true
                
            } else if !isDownloading && !isInstalled
                        && ((wasDownloading && pathCheckSawCaching.contains(item.id))
                            || (wasCompleted && sawInstalledBefore)) {
                pathCheckSawCaching.remove(item.id)
                // The log monitor is authoritative for download state: a live status blocks the reset.
                let hasLogMonitorStatus = self.logMonitorStatuses[item.id] != nil
                if !checkCacheForItem(item) && !hasLogMonitorStatus {
                    self.debouncedUpdater.debounce(key: "item-pending-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.downloadingItems.remove(item.id)
                        self.completedItems.remove(item.id)
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
    
    private func checkCacheForItem(_ item: InspectConfig.ItemConfig) -> Bool {
        guard let config = config, let cachePaths = config.cachePaths else { return false }

        writeLog("InspectState: Checking cache for item '\(item.id)' (display: '\(item.displayName)')", logLevel: .debug)

        for cachePath in cachePaths {
            fileSystemCache.invalidateCache(for: cachePath)
            let cacheContents = fileSystemCache.cacheDirectoryContents(cachePath)

            if cacheContents.isEmpty {
                writeLog("InspectState:   Cache directory '\(cachePath)' is empty", logLevel: .debug)
            } else {
                writeLog("InspectState:   Files in cache (\(cacheContents.count) total): \(cacheContents.prefix(3).joined(separator: ", "))\(cacheContents.count > 3 ? "..." : "")", logLevel: .debug)
            }

            let extensions = config.resolvedCacheExtensions
            let downloadFiles = cacheContents.filter { file in
                guard !file.hasPrefix(".") else { return false }

                let lowercased = file.lowercased()
                return extensions.contains { lowercased.hasSuffix($0) }
            }

            if downloadFiles.isEmpty {
                writeLog("InspectState:   No package files found (looked for \(extensions.joined(separator: ", ")))", logLevel: .debug)
            } else {
                for file in downloadFiles {
                    writeLog("InspectState:   Found package: '\(file)'", logLevel: .debug)
                }
            }

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

    /// The shared filename ladder with brand-fuzzy matching on; strategy detail logs at .debug.
    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        FilenameMatching.matches(itemId: itemId, displayName: displayName, filename: filename,
                                 brandFuzzy: true,
                                 log: { writeLog("InspectState:     \u{2713} \($0)", logLevel: .debug) })
    }

    /// Parses one global command-file line: window commands, `item:` and legacy `listitem:`.
    private func parseCommandLine(_ line: String) {
        writeLog("InspectState: Parsing command line: \(line)", logLevel: .debug)

        // `minimize:` / `maximize:` (either spelling) are answered here in inspect mode;
        // DialogUpdatableContent.processCommands steps aside for them.
        switch line.trimmingCharacters(in: .whitespaces).lowercased() {
        case "minimize:", "minimise:":
            writeLog("InspectState: minimizing window", logLevel: .info)
            minimizeDialogWindow()
            return
        case "maximize:", "maximise:":
            writeLog("InspectState: restoring window", logLevel: .info)
            restoreDialogWindow()
            return
        default:
            break
        }

        // "item:itemId:status" or "item:itemId:status:message"
        if line.hasPrefix("item:") {
            let parts = line.dropFirst(5).split(separator: ":", maxSplits: 2)
            guard parts.count >= 2 else {
                writeLog("InspectState: Invalid item command format: \(line)", logLevel: .error)
                return
            }
            let itemId = String(parts[0])
            let status = String(parts[1]).lowercased()
            let message = parts.count > 2 ? String(parts[2]) : nil

            // Vocabulary and lifecycle from `ItemStatusCommand.swift`; the message is this channel's.
            guard let resolved = StepStatus(itemCommand: status) else {
                writeLog("InspectState: Unknown item status '\(status)' for '\(itemId)'", logLevel: .debug)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // This channel records any id it is sent.
                guard resolved != .skipped else {
                    writeLog("InspectState: Unknown item status '\(status)' for '\(itemId)'", logLevel: .debug)
                    return
                }
                self.applyItemStatus(itemId, resolved, knownItemsOnly: false)
                if let message = message {
                    self.logMonitorStatuses[itemId] = message
                }
                writeLog("InspectState: Item '\(itemId)' → \(status)\(message.map { ": \($0)" } ?? "")", logLevel: .info)
            }
            return
        }

        // Legacy: "listitem: index: X, status: Y, statustext: Z"
        var appIndex: Int?
        var status: String?
        var statusText: String?

        if let indexRange = line.range(of: "index: "),
           let commaRange = line.range(of: ",", range: indexRange.upperBound..<line.endIndex) {
            let indexStr = String(line[indexRange.upperBound..<commaRange.lowerBound])
            appIndex = Int(indexStr)
        }

        if let statusRange = line.range(of: "status: "),
           let nextCommaRange = line.range(of: ",", range: statusRange.upperBound..<line.endIndex) {
            status = String(line[statusRange.upperBound..<nextCommaRange.lowerBound])
        } else if let statusRange = line.range(of: "status: ") {
            status = String(line[statusRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let statusTextRange = line.range(of: "statustext: ") {
            statusText = String(line[statusTextRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

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
                    self.applyItemStatus(app.id, .completed)
                    writeLog("InspectState: \(app.displayName) completed (from command)", logLevel: .info)
                case "wait":
                    self.downloadingItems.insert(app.id)
                    writeLog("InspectState: \(app.displayName) downloading (from command)", logLevel: .info)
                case "pending":
                    self.applyItemStatus(app.id, .pending)
                    writeLog("InspectState: \(app.displayName) pending (from command)", logLevel: .info)
                case "fail", "error":
                    self.applyItemStatus(app.id, .failed)
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
    
    func startSideMessageRotation(interval: TimeInterval) {
        sideMessagePoll?.cancel()

        writeLog("InspectState: Starting side message rotation with \(uiConfiguration.sideMessages.count) messages, interval: \(interval)s", logLevel: .info)

        let poll = Poll(every: interval)
        poll.start { [weak self] in
            guard let self, self.uiConfiguration.sideMessages.count > 1 else {
                writeLog("InspectState: Rotation fired but no messages to rotate (count: \(self?.uiConfiguration.sideMessages.count ?? 0))", logLevel: .debug)
                return
            }

            self.uiConfiguration.currentSideMessageIndex = (self.uiConfiguration.currentSideMessageIndex + 1) % self.uiConfiguration.sideMessages.count
            writeLog("InspectState: Rotated to side message index \(self.uiConfiguration.currentSideMessageIndex) of \(self.uiConfiguration.sideMessages.count)", logLevel: .info)
        }
        sideMessagePoll = poll

        writeLog("InspectState: Side message rotation configured", logLevel: .info)
    }
}
