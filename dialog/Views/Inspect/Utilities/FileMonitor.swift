//
//  FileMonitor.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//  Centralized file system monitoring service using FSEvents
//  Handles all file monitoring, caching, and change detection
//

import Foundation

/// Protocol for file system monitoring callbacks
protocol FileMonitorDelegate: AnyObject {
    func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectCacheChange path: String)
    func fileMonitorDidDetectChanges(_ monitor: FileMonitor)
}

// Optional methods with default implementation
extension FileMonitorDelegate {
    func fileMonitor(_ monitor: FileMonitor, didDetectCacheChange path: String) {}
}

class FileMonitor {

    // MARK: - Singleton
    static let shared = FileMonitor()

    // MARK: - Properties
    weak var delegate: FileMonitorDelegate?

    private var fsEventStream: FSEventStreamRef?
    private var monitoredItems: [InspectConfig.ItemConfig] = []
    private var cachePaths: [String] = []
    private var eventDebouncer = EventDebouncer()
    private var pathToItemMap: [String: String] = [:] // path -> itemId mapping

    // File system cache for performance
    private let fileSystemCache = InspectFileCache()

    // Tracking states
    private var installedItems: Set<String> = []
    private var downloadingItems: Set<String> = []

    // Plist monitoring
    private var plistCallbacks: [String: (String) -> Void] = [:] // path -> callback

    // MARK: - Public Interface

    func startMonitoring(items: [InspectConfig.ItemConfig], cachePaths: [String]) {
        self.monitoredItems = items
        self.cachePaths = cachePaths

        buildPathMappings()
        setupFSEvents()
        performInitialScan()

        writeLog("FileMonitor: Started monitoring \(items.count) items and \(cachePaths.count) cache paths", logLevel: .info)
    }
    
    func stopMonitoring() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
            
            eventDebouncer.cleanupDebouncer()
            
            writeLog("FileMonitor: Stopped monitoring and cleaned up resources", logLevel: .info)
        }
    }
    
    /// Check if an item is installed
    func isInstalled(_ item: InspectConfig.ItemConfig) -> Bool {
        for path in item.paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }

    /// Check if an item is downloading
    func isDownloading(_ item: InspectConfig.ItemConfig) -> Bool {
        for cachePath in cachePaths {
            // Always invalidate cache for fresh data
            fileSystemCache.invalidateCache(for: cachePath)
            let cacheContents = fileSystemCache.cacheDirectoryContents(cachePath)

            for file in cacheContents {
                guard !file.hasPrefix(".") else { continue }

                if isDownloadFile(file) && fileMatchesItem(file, item: item) {
                    writeLog("FileMonitor: Found download for '\(item.displayName)': \(file)", logLevel: .debug)
                    return true
                }
            }
        }
        return false
    }

    /// Force a status check for all monitored items
    func performStatusCheck() {
        var changesDetected = false

        for item in monitoredItems {
            // Skip items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping status check for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            let wasInstalled = installedItems.contains(item.id)
            let wasDownloading = downloadingItems.contains(item.id)

            let isInstalled = self.isInstalled(item)
            let isDownloading = !isInstalled && self.isDownloading(item)

            // Update states and notify delegate
            if isInstalled && !wasInstalled {
                installedItems.insert(item.id)
                downloadingItems.remove(item.id)
                delegate?.fileMonitor(self, didDetectInstallation: item.id, at: item.paths.first ?? "")
                changesDetected = true
            } else if !isInstalled && wasInstalled {
                installedItems.remove(item.id)
                if isDownloading {
                    downloadingItems.insert(item.id)
                    delegate?.fileMonitor(self, didDetectDownload: item.id, at: "")
                } else {
                    downloadingItems.remove(item.id)
                    delegate?.fileMonitor(self, didDetectRemoval: item.id, at: "")
                }
                changesDetected = true
            } else if isDownloading && !wasDownloading {
                downloadingItems.insert(item.id)
                delegate?.fileMonitor(self, didDetectDownload: item.id, at: "")
                changesDetected = true
            } else if !isDownloading && !isInstalled && wasDownloading {
                downloadingItems.remove(item.id)
                delegate?.fileMonitor(self, didDetectRemoval: item.id, at: "")
                changesDetected = true
            }
        }

        if changesDetected {
            delegate?.fileMonitorDidDetectChanges(self)
        }
    }

    // MARK: - Private Implementation

    private func performInitialScan() {
        // Perform initial scan to set up current state
        for item in monitoredItems {
            // Skip items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping initial scan for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            if isInstalled(item) {
                installedItems.insert(item.id)
            } else if isDownloading(item) {
                downloadingItems.insert(item.id)
            }
        }
        writeLog("FileMonitor: Initial scan - \(installedItems.count) installed, \(downloadingItems.count) downloading", logLevel: .info)
    }

    private func buildPathMappings() {
        pathToItemMap.removeAll()

        // Build mappings for quick lookups
        for item in monitoredItems {
            // Skip items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping path mappings for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                pathToItemMap[expandedPath] = item.id
            }
        }

        writeLog("FileMonitor: Built mappings for \(pathToItemMap.count) paths", logLevel: .debug)
    }
    
    private func setupFSEvents() {
        var pathsToWatch = Set<String>()
        
        // Watch both app paths and cache paths
        for item in monitoredItems {
            // Skip items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping FSEvents setup for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                // Add parent directory to watch list
                let parentDir = (expandedPath as NSString).deletingLastPathComponent
                if FileManager.default.fileExists(atPath: parentDir) {
                    pathsToWatch.insert(parentDir)
                }
            }
        }

        for cachePath in cachePaths {
            let expandedPath = (cachePath as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                pathsToWatch.insert(expandedPath)
            }
        }
        
        let pathsArray = Array(pathsToWatch)
        guard !pathsArray.isEmpty else {
            writeLog("FileMonitor: No cache paths to monitor", logLevel: .info)
            return
        }
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            retain: nil,
            release: { info in
                if let info = info {
                    Unmanaged<FileMonitor>.fromOpaque(info).release()
                }
            },
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { _, clientInfo, numEvents, eventPaths, eventFlags, _ in
            guard let clientInfo = clientInfo else { return }
            let monitor = Unmanaged<FileMonitor>.fromOpaque(clientInfo).takeUnretainedValue()
            
            guard let pathsArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] else {
                writeLog("FileMonitor: Failed to convert event paths", logLevel: .error)
                return
            }
            let paths = pathsArray
            
            for i in 0..<numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                
                guard monitor.isMonitoredPath(path) else { continue }
                
                monitor.eventDebouncer.debounce(key: path, delay: 0.1) {
                    monitor.handleOptimizedFSEvent(path: path, flags: flags)
                }
                
                if i % 1000 == 0 {
                    monitor.eventDebouncer.cleanupDebouncer()
                }
            }
        }
        
        fsEventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsArray as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, 
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )
        
        guard let stream = fsEventStream else {
            writeLog("FileMonitor: Failed to create FSEventStream", logLevel: .error)
            return
        }
        // TODO: remove following comments once behaviour is verified
        // following generates a warning
        // 'FSEventStreamScheduleWithRunLoop' was deprecated in macOS 13.0: Use FSEventStreamSetDispatchQueue instead.
        // FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let queue = DispatchQueue(label: bundleID + ".fsEventStream")
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        
        writeLog("FileMonitor: Started FSEvents monitoring \(pathsArray.count) paths", logLevel: .info)
    }
    
    private func isMonitoredPath(_ path: String) -> Bool {
        for cachePath in cachePaths {
            let expandedPath = (cachePath as NSString).expandingTildeInPath
            if path.hasPrefix(expandedPath) {
                return true
            }
        }
        
        return false
    }
    
    private func handleOptimizedFSEvent(path: String, flags: FSEventStreamEventFlags) {
        DispatchQueue.main.async { [weak self] in
            self?.processEvent(path: path, flags: flags)
        }
    }
    
    private func processEvent(path: String, flags: FSEventStreamEventFlags) {
        let isCreated = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
        let isRemoved = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
        let isModified = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0
        let isRenamed = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0

        let filename = (path as NSString).lastPathComponent

        if isCreated {
            writeLog("FileMonitor: CREATE event for '\(filename)' at \(path)", logLevel: .info)
            handleFileCreated(at: path)
        } else if isRemoved {
            writeLog("FileMonitor: REMOVE event for '\(filename)' at \(path)", logLevel: .info)
            handleFileRemoved(at: path)
        } else if isModified {
            writeLog("FileMonitor: MODIFY event for '\(filename)' at \(path)", logLevel: .debug)
        } else if isRenamed {
            writeLog("FileMonitor: RENAME event for '\(filename)' at \(path)", logLevel: .info)
        }
    }
    
    private func handleFileCreated(at path: String) {
        // Invalidate cache for this path
        for cachePath in cachePaths where path.hasPrefix(cachePath) {
            fileSystemCache.invalidateCache(for: cachePath)
        }

        // Check if this is an app installation
        if let itemId = findItemIdForPath(path) {
            eventDebouncer.debounce(key: "install-\(itemId)", delay: 0.5) { [weak self] in
                guard let self = self else { return }
                self.performStatusCheck()
            }
        } else if isCacheFile(path) {
            // Cache file created - might be a download
            delegate?.fileMonitor(self, didDetectCacheChange: path)
            eventDebouncer.debounce(key: "cache-change", delay: 0.5) { [weak self] in
                guard let self = self else { return }
                self.performStatusCheck()
            }
        }
    }

    private func handleFileRemoved(at path: String) {
        // Invalidate cache for this path
        for cachePath in cachePaths where path.hasPrefix(cachePath) {
            fileSystemCache.invalidateCache(for: cachePath)
        }

        // Check if this is an app removal
        if let itemId = findItemIdForPath(path) {
            eventDebouncer.debounce(key: "remove-\(itemId)", delay: 0.5) { [weak self] in
                guard let self = self else { return }
                self.performStatusCheck()
            }
        } else if isCacheFile(path) {
            delegate?.fileMonitor(self, didDetectCacheChange: path)
            eventDebouncer.debounce(key: "cache-change", delay: 0.5) { [weak self] in
                guard let self = self else { return }
                self.performStatusCheck()
            }
        }
    }
    
    private func findItemIdForPath(_ path: String) -> String? {
        // Direct match
        if let itemId = pathToItemMap[path] {
            return itemId
        }

        // Check if path is a child of a monitored path
        for (monitoredPath, itemId) in pathToItemMap where path.hasPrefix(monitoredPath) {
            return itemId
        }

        // Check by filename matching
        let filename = (path as NSString).lastPathComponent
        for item in monitoredItems {
            // Skip items with empty paths - they should be managed by presets
            guard !item.paths.isEmpty else {
                continue
            }
            
            if fileMatchesItem(filename, item: item) {
                return item.id
            }
        }

        return nil
    }
    
    private func isCacheFile(_ path: String) -> Bool {
        let lowercasePath = path.lowercased()
        return lowercasePath.hasSuffix(".pkg") ||
               lowercasePath.hasSuffix(".dmg") ||
               lowercasePath.hasSuffix(".download") ||
               lowercasePath.hasSuffix(".zip") ||
               lowercasePath.hasSuffix(".app") ||
               lowercasePath.contains(".partial") ||
               lowercasePath.contains(".tmp")
    }

    private func isDownloadFile(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
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

    /// Smart filename matching algorithm
    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        let cleanFilename = filename.lowercased()
        let cleanItemId = itemId.lowercased()
        let cleanDisplayName = displayName.lowercased().replacingOccurrences(of: " ", with: "")
        let cleanDisplayNameNoUnderscore = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        // Strategy 1: Direct substring match
        if cleanFilename.contains(cleanItemId) ||
           cleanFilename.contains(cleanDisplayName) ||
           cleanFilename.contains(cleanDisplayNameNoUnderscore) {
            return true
        }

        // Strategy 2: Component matching
        let itemComponents = cleanItemId.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }
        let displayComponents = cleanDisplayName.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }

        let allItemComponentsMatch = !itemComponents.isEmpty && itemComponents.allSatisfy { cleanFilename.contains($0) }
        let allDisplayComponentsMatch = !displayComponents.isEmpty && displayComponents.allSatisfy { cleanFilename.contains($0) }

        if allItemComponentsMatch || allDisplayComponentsMatch {
            return true
        }

        // Strategy 3: Condensed matching
        let condensedItemId = cleanItemId.replacingOccurrences(of: "_", with: "")
        let condensedDisplayName = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        return cleanFilename.contains(condensedItemId) || cleanFilename.contains(condensedDisplayName)
    }

    // MARK: - Plist Monitoring

    /// Add a plist file to FSEvents monitoring with callback
    /// - Parameters:
    ///   - path: Plist file path (should be expanded)
    ///   - key: Plist key to monitor
    ///   - callback: Called when file changes (receives new value as String)
    func addPlistMonitor(path: String, key: String, callback: @escaping (String) -> Void) {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Store callback
        plistCallbacks[expandedPath] = callback

        // Note: FSEvents monitors parent directories, so we don't need to restart the stream
        // The existing setupFSEvents() will catch changes to any files in monitored directories

        writeLog("FileMonitor: Added plist monitor for \(expandedPath) key=\(key)", logLevel: .info)
    }

    /// Remove plist monitor for a path
    /// - Parameter path: Plist file path
    func removePlistMonitor(path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        plistCallbacks.removeValue(forKey: expandedPath)
        writeLog("FileMonitor: Removed plist monitor for \(expandedPath)", logLevel: .debug)
    }

    /// Handle plist file change event
    /// - Parameter path: Path to changed plist file
    private func handlePlistChange(path: String) {
        guard let callback = plistCallbacks[path] else { return }

        // Read new value - this is a simplified version, real implementation would need to know the key
        // For now, just trigger the callback with a placeholder
        // The actual plist reading happens in the callback via Validation.shared
        callback("changed")

        writeLog("FileMonitor: Plist changed, triggered callback for \(path)", logLevel: .info)
    }
}

// MARK: - File System Cache

/// High-performance file system cache to avoid repeated directory scans
private class InspectFileCache {
    private var cache: [String: [String]] = [:]
    private let queue = DispatchQueue(label: "fs.cache", attributes: .concurrent)

    func cacheDirectoryContents(_ path: String) -> [String] {
        let expandedPath = (path as NSString).expandingTildeInPath

        return queue.sync {
            // Return cached contents if available
            if let cached = cache[expandedPath] {
                return cached
            }

            // Otherwise, read from disk
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
                // Update cache
                queue.async(flags: .barrier) {
                    self.cache[expandedPath] = contents
                }
                return contents
            } catch {
                writeLog("InspectFileCache: Failed to read directory \(expandedPath): \(error)", logLevel: .debug)
                return []
            }
        }
    }

    func invalidateCache(for path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: expandedPath)
        }
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Event Debouncer

/// This should debounce potential rapid FSEvents to prevent excessive UI updates
private class EventDebouncer {
    private var pendingEvents: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "fs.events.debouncer", qos: .userInitiated)
    
    func debounce(key: String, delay: TimeInterval, action: @escaping () -> Void) {

        pendingEvents[key]?.cancel()
        
        let workItem = DispatchWorkItem {
            action()
            DispatchQueue.main.async {
                self.pendingEvents.removeValue(forKey: key)
            }
        }
        
        pendingEvents[key] = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    func cleanupDebouncer() {
        for workItem in pendingEvents.values {
            workItem.cancel()
        }
        pendingEvents.removeAll()
    }
}
