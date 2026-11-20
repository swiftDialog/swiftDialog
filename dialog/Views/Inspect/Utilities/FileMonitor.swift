//
//  FileMonitor.swift
//  dialog
//
//  FSEvents-based monitoring of item paths and download caches for presets 1–4; reports
//  installs, removals and downloads to a delegate.
//

import Foundation
import Synchronization

/// Callbacks are delivered on `FileMonitor.callbackQueue` (main in the app).
protocol FileMonitorDelegate: AnyObject {
    func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String)
    func fileMonitor(_ monitor: FileMonitor, didDetectCacheChange path: String)
    func fileMonitorDidDetectChanges(_ monitor: FileMonitor)
}

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
    private var cacheExtensions: [String] = [".download", ".pkg", ".dmg"]
    private var eventDebouncer = EventDebouncer()
    private var pathToItemMap: [String: String] = [:] // canonical path -> itemId
    /// The canonical directories the FSEvents stream was created with; `isMonitoredPath` filters
    /// against this same list so the two cannot disagree.
    private var watchedRoots: [String] = []

    /// True only while a stream is running; set false first when stopping. Guarded by
    /// `lifecycleLock` because it is read on the debouncer's queue and written on the caller's.
    private var isMonitoring = false
    private let lifecycleLock = NSLock()

    private var live: Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        return isMonitoring
    }

    private let fileSystemCache = InspectFileCache()

    private var installedItems: Set<String> = []
    private var downloadingItems: Set<String> = []

    /// One spelling for a path, by text alone: `/tmp`, `/var` and `/etc` become their `/private`
    /// form, which FSEvents reports. Must not touch the filesystem, so a path canonicalises the
    /// same way before and after the file it names is deleted.
    static func canonicalPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        for short in ["/tmp", "/var", "/etc"] where expanded == short || expanded.hasPrefix(short + "/") {
            return "/private" + expanded
        }
        return expanded
    }

    // MARK: - Public Interface

    func startMonitoring(items: [InspectConfig.ItemConfig], cachePaths: [String], cacheExtensions: [String]? = nil) {
        self.monitoredItems = items
        self.cachePaths = cachePaths
        self.cacheExtensions = cacheExtensions ?? [".download", ".pkg", ".dmg"]

        buildPathMappings()
        setupFSEvents()
        performInitialScan()

        lifecycleLock.lock(); isMonitoring = true; lifecycleLock.unlock()
        writeLog("FileMonitor: Started monitoring \(items.count) items and \(cachePaths.count) cache paths", logLevel: .info)
    }
    
    func stopMonitoring() {
        // Goes false first so a late debounced work item finds the monitor already stopped.
        lifecycleLock.lock(); isMonitoring = false; lifecycleLock.unlock()
        // Outside the stream guard: a monitor with no stream can still hold scheduled work.
        eventDebouncer.cleanupDebouncer()
        watchedRoots.removeAll()
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
            
            writeLog("FileMonitor: Stopped monitoring and cleaned up resources", logLevel: .info)
        }
    }

    
    /// Whether any of the item's paths exists.
    func isInstalled(_ item: InspectConfig.ItemConfig) -> Bool {
        for path in item.paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }

    /// Whether a cache path holds a download file matching the item.
    func isDownloading(_ item: InspectConfig.ItemConfig) -> Bool {
        for cachePath in cachePaths {
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

    /// Re-checks every monitored item and reports state changes to the delegate.
    func performStatusCheck() {
        guard live else { return }
        var changesDetected = false

        for item in monitoredItems {
            // Items without paths are the presets' business.
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping status check for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            let wasInstalled = installedItems.contains(item.id)
            let wasDownloading = downloadingItems.contains(item.id)

            let isInstalled = self.isInstalled(item)
            let isDownloading = !isInstalled && self.isDownloading(item)

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
        for item in monitoredItems {
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

        for item in monitoredItems {
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping path mappings for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                // Canonical on both sides, or an item authored as /tmp/x never matches its own event.
                pathToItemMap[Self.canonicalPath(expandedPath)] = item.id
            }
        }

        writeLog("FileMonitor: Built mappings for \(pathToItemMap.count) paths", logLevel: .debug)
    }
    
    private func setupFSEvents() {
        var pathsToWatch = Set<String>()

        for item in monitoredItems {
            guard !item.paths.isEmpty else {
                writeLog("FileMonitor: Skipping FSEvents setup for item \(item.id) - empty paths array", logLevel: .debug)
                continue
            }
            
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
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
        
        // Canonical before watching and filtering: FSEvents reports /private/tmp for /tmp.
        let pathsArray = pathsToWatch.map { Self.canonicalPath($0) }
        watchedRoots = pathsArray
        guard !pathsArray.isEmpty else {
            writeLog("FileMonitor: No paths to monitor", logLevel: .info)
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
                // No debouncer sweep in this loop: it would cancel work just scheduled.
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
        // FSEventStreamScheduleWithRunLoop is deprecated since macOS 13.
        let queue = DispatchQueue(label: bundleID + ".fsEventStream")
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        
        writeLog("FileMonitor: Started FSEvents monitoring \(pathsArray.count) paths", logLevel: .info)
    }
    
    private func isMonitoredPath(_ path: String) -> Bool {
        let resolved = Self.canonicalPath(path)
        for root in watchedRoots where resolved.hasPrefix(root) {
            return true
        }

        // For a caller that set cachePaths without going through setupFSEvents.
        for cachePath in cachePaths where resolved.hasPrefix(Self.canonicalPath(cachePath)) {
            return true
        }

        return false
    }
    
    /// Queue for `processEvent` and delegate callbacks. Main in the app, since downstream code
    /// touches UI state; tests may substitute their own queue.
    var callbackQueue: DispatchQueue = .main

    private func handleOptimizedFSEvent(path: String, flags: FSEventStreamEventFlags) {
        callbackQueue.async { [weak self] in
            self?.processEvent(path: path, flags: flags)
        }
    }
    
    private func processEvent(path: String, flags: FSEventStreamEventFlags) {
        guard live else { return }
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
            // An installer's atomic move arrives as a rename; the disk says whether it came or went.
            if FileManager.default.fileExists(atPath: path) {
                handleFileCreated(at: path)
            } else {
                handleFileRemoved(at: path)
            }
        }
    }
    
    // Status checks are debounced onto `callbackQueue`, where the monitor's sets and delegate live.
    private func handleFileCreated(at path: String) {
        for cachePath in cachePaths where path.hasPrefix(cachePath) {
            fileSystemCache.invalidateCache(for: cachePath)
        }

        if let itemId = findItemIdForPath(path) {
            eventDebouncer.debounce(key: "install-\(itemId)", delay: 0.5, on: callbackQueue) { [weak self] in
                self?.performStatusCheck()
            }
        } else if isCacheFile(path) {
            delegate?.fileMonitor(self, didDetectCacheChange: path)
            eventDebouncer.debounce(key: "cache-change", delay: 0.5, on: callbackQueue) { [weak self] in
                self?.performStatusCheck()
            }
        }
    }

    private func handleFileRemoved(at path: String) {
        for cachePath in cachePaths where path.hasPrefix(cachePath) {
            fileSystemCache.invalidateCache(for: cachePath)
        }

        if let itemId = findItemIdForPath(path) {
            eventDebouncer.debounce(key: "remove-\(itemId)", delay: 0.5, on: callbackQueue) { [weak self] in
                self?.performStatusCheck()
            }
        } else if isCacheFile(path) {
            delegate?.fileMonitor(self, didDetectCacheChange: path)
            eventDebouncer.debounce(key: "cache-change", delay: 0.5, on: callbackQueue) { [weak self] in
                self?.performStatusCheck()
            }
        }
    }
    
    /// Exact path, then a child of a monitored path, then filename matching.
    private func findItemIdForPath(_ path: String) -> String? {
        let path = Self.canonicalPath(path)
        if let itemId = pathToItemMap[path] {
            return itemId
        }

        for (monitoredPath, itemId) in pathToItemMap where path.hasPrefix(monitoredPath) {
            return itemId
        }

        let filename = (path as NSString).lastPathComponent
        for item in monitoredItems {
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
        return cacheExtensions.contains { lowercasePath.hasSuffix($0) } ||
               lowercasePath.contains(".partial") ||
               lowercasePath.contains(".tmp")
    }

    private func isDownloadFile(_ filename: String) -> Bool {
        FilenameMatching.isDownloadFile(filename, cacheExtensions: cacheExtensions)
    }

    private func fileMatchesItem(_ filename: String, item: InspectConfig.ItemConfig) -> Bool {
        return smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: filename)
    }

    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        FilenameMatching.matches(itemId: itemId, displayName: displayName, filename: filename,
                                 brandFuzzy: false, log: nil)
    }

}

// MARK: - File System Cache

/// Directory listing cache behind one `Mutex`. The disk read does not hold the lock; two
/// threads that miss on the same directory both read and both write the same value.
private final class InspectFileCache: Sendable {
    private let cache = Mutex<[String: [String]]>([:])

    func cacheDirectoryContents(_ path: String) -> [String] {
        let expandedPath = (path as NSString).expandingTildeInPath
        if let cached = cache.withLock({ $0[expandedPath] }) { return cached }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
            cache.withLock { $0[expandedPath] = contents }
            return contents
        } catch {
            writeLog("InspectFileCache: Failed to read directory \(expandedPath): \(error)", logLevel: .debug)
            return []
        }
    }

    func invalidateCache(for path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        cache.withLock { _ = $0.removeValue(forKey: expandedPath) }
    }

    func clearCache() {
        cache.withLock { $0.removeAll() }
    }
}

// MARK: - Event Debouncer

/// Coalesces rapid FSEvents per key. Thread-safe: `debounce` is called from several queues.
final class EventDebouncer {
    /// Guarded by `lock`; touched from the FSEvents queue, `callbackQueue` and the caller's thread.
    private var pendingEvents: [String: (id: UUID, item: DispatchWorkItem)] = [:]
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "fs.events.debouncer", qos: .userInitiated)

    /// Entries not yet run or cancelled; at most one per key.
    var pendingCount: Int { lock.withLock { pendingEvents.count } }

    /// Runs `action` on `target` (default: the debouncer's own queue) after `delay`, replacing
    /// any pending action for the same key.
    func debounce(key: String, delay: TimeInterval, on target: DispatchQueue? = nil,
                  action: @escaping () -> Void) {
        let id = UUID()
        let workItem = DispatchWorkItem { [weak self] in
            action()
            // Remove only this item's entry; a newer event on the key may have replaced it.
            guard let self else { return }
            self.lock.withLock {
                if self.pendingEvents[key]?.id == id { self.pendingEvents.removeValue(forKey: key) }
            }
        }

        lock.withLock {
            pendingEvents[key]?.item.cancel()
            pendingEvents[key] = (id, workItem)
        }

        (target ?? queue).asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cleanupDebouncer() {
        lock.withLock {
            pendingEvents.values.forEach { $0.item.cancel() }
            pendingEvents.removeAll()
        }
    }
}
