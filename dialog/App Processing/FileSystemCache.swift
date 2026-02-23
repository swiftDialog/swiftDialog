//
//  FileSystemCache.swift
//  dialog
//
//  Created by Henry Stamerjohann on 19/7/2025.
//

import Foundation

/// Intelligent file system cache that handles permission issues and missing directories
class FileSystemCache {
    
    // MARK: - Cache Entry
    private struct CacheEntry {
        let contents: [String]
        let timestamp: Date
        let accessGranted: Bool
        
        var isValid: Bool {
            return accessGranted && Date().timeIntervalSince(timestamp) < InspectConstants.cacheTimeout
        }
    }
    
    // MARK: - Properties
    private var directoryCache: [String: CacheEntry] = [:]
    private var accessiblePaths: Set<String> = []
    private var inaccessiblePaths: Set<String> = []
    private let cacheTimeout: TimeInterval
    private let maxCacheEntries: Int
    private let maxMemoryUsage: Int
    private var currentMemoryUsage: Int = 0
    
    // MARK: - Initialization
    init(
        cacheTimeout: TimeInterval = InspectConstants.cacheTimeout,
        maxCacheEntries: Int = InspectConstants.maxCacheEntries,
        maxMemoryUsage: Int = InspectConstants.maxMemoryUsage
    ) {
        self.cacheTimeout = cacheTimeout
        self.maxCacheEntries = maxCacheEntries
        self.maxMemoryUsage = maxMemoryUsage
    }
    
    // MARK: - Public Interface
    
    /// Get cached directory contents if available and valid
    /// - Parameter path: Directory path to check
    /// - Returns: Array of filenames if cached and valid, nil otherwise
    func getCachedDirectoryContents(_ path: String) -> [String]? {
        // Quick check for known inaccessible paths
        if inaccessiblePaths.contains(path) {
            return nil
        }
        
        guard let cached = directoryCache[path], cached.isValid else {
            return nil
        }
        
        writeLog("FileSystemCache: Cache HIT for \(path) (\(cached.contents.count) files)", logLevel: .debug)
        return cached.contents
    }
    
    /// Cache directory contents with intelligent error handling
    /// - Parameter path: Directory path to cache
    /// - Returns: Array of filenames or empty array if inaccessible
    @discardableResult
    func cacheDirectoryContents(_ path: String) -> [String] {
        // Skip if we know this path is inaccessible
        if inaccessiblePaths.contains(path) {
            return []
        }
        
        // Check if directory exists first
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            writeLog("FileSystemCache: Directory does not exist: \(path)", logLevel: .debug)
            markPathInaccessible(path, reason: "Directory does not exist")
            return []
        }
        
        // Try to read directory contents
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            
            // Success - cache the results
            setCachedDirectoryContents(path, contents: contents, accessGranted: true)
            accessiblePaths.insert(path)
            
            writeLog("FileSystemCache: Successfully cached \(contents.count) files from \(path)", logLevel: .debug)
            return contents
            
        } catch let error as NSError {
            // Handle specific error types
            let reason: String
            switch error.code {
            case NSFileReadNoPermissionError:
                reason = "Permission denied"
            case NSFileReadNoSuchFileError:
                reason = "Directory not found"
            default:
                reason = "Error: \(error.localizedDescription)"
            }
            
            writeLog("FileSystemCache: Cannot access \(path) - \(reason)", logLevel: .info)
            markPathInaccessible(path, reason: reason)
            return []
        }
    }
    
    /// Invalidate cache for specific path
    /// - Parameter path: Path to invalidate
    func invalidateCache(for path: String) {
        if let entry = directoryCache.removeValue(forKey: path) {
            currentMemoryUsage -= estimateMemoryUsage(for: entry.contents)
            writeLog("FileSystemCache: Invalidated cache for \(path)", logLevel: .debug)
        }
    }
    
    /// Invalidate all cached data
    func invalidateAll() {
        directoryCache.removeAll()
        currentMemoryUsage = 0
        writeLog("FileSystemCache: Invalidated all cache entries", logLevel: .debug)
    }
    
    /// Get cache statistics
    func getStatistics() -> (entries: Int, memoryUsage: Int, accessiblePaths: Int, inaccessiblePaths: Int) {
        return (
            entries: directoryCache.count,
            memoryUsage: currentMemoryUsage,
            accessiblePaths: accessiblePaths.count,
            inaccessiblePaths: inaccessiblePaths.count
        )
    }
    
    // MARK: - Private Methods
    
    private func setCachedDirectoryContents(_ path: String, contents: [String], accessGranted: Bool) {
        // Memory management - check limits
        if currentMemoryUsage > maxMemoryUsage {
            clearOldestEntries()
        }
        
        if directoryCache.count >= maxCacheEntries {
            removeOldestEntry()
        }
        
        // Calculate memory usage for new entry
        let memoryUsage = estimateMemoryUsage(for: contents)
        
        // Remove old entry if exists
        if let oldEntry = directoryCache[path] {
            currentMemoryUsage -= estimateMemoryUsage(for: oldEntry.contents)
        }
        
        // Add new entry
        directoryCache[path] = CacheEntry(
            contents: contents,
            timestamp: Date(),
            accessGranted: accessGranted
        )
        currentMemoryUsage += memoryUsage
    }
    
    private func markPathInaccessible(_ path: String, reason: String) {
        inaccessiblePaths.insert(path)
        accessiblePaths.remove(path)
        
        // Cache an empty result with access denied flag
        setCachedDirectoryContents(path, contents: [], accessGranted: false)
        
        writeLog("FileSystemCache: Marked path inaccessible: \(path) (\(reason))", logLevel: .info)
    }
    
    private func removeOldestEntry() {
        guard let oldestKey = directoryCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }
        
        if let entry = directoryCache.removeValue(forKey: oldestKey) {
            currentMemoryUsage -= estimateMemoryUsage(for: entry.contents)
            writeLog("FileSystemCache: Removed oldest entry: \(oldestKey)", logLevel: .debug)
        }
    }
    
    private func clearOldestEntries() {
        let sortedEntries = directoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(directoryCache.count / 4) // Remove 25%
        
        for (key, entry) in entriesToRemove {
            directoryCache.removeValue(forKey: key)
            currentMemoryUsage -= estimateMemoryUsage(for: entry.contents)
        }
        
        writeLog("FileSystemCache: Cleared \(entriesToRemove.count) oldest entries (memory cleanup)", logLevel: .debug)
    }
    
    private func estimateMemoryUsage(for contents: [String]) -> Int {
        return contents.reduce(0) { $0 + $1.utf8.count } + (contents.count * 64) // Rough estimate
    }
}

// MARK: - Cache-aware Directory Operations
extension FileSystemCache {
    
    /// Check if any files in directory match the given criteria with caching
    /// - Parameters:
    ///   - path: Directory path to search
    ///   - matchCriteria: Closure that returns true if file matches
    /// - Returns: True if any matching file found
    func containsMatchingFile(in path: String, matchCriteria: (String) -> Bool) -> Bool {
        let contents: [String]
        
        // Try cache first
        if let cached = getCachedDirectoryContents(path) {
            contents = cached
        } else {
            // Cache miss - read and cache
            contents = cacheDirectoryContents(path)
        }
        
        return contents.contains(where: matchCriteria)
    }
    
    /// Get all accessible cache paths from configuration
    /// - Parameter cachePaths: Array of potential cache paths
    /// - Returns: Array of verified accessible paths
    func getAccessibleCachePaths(from cachePaths: [String]?) -> [String] {
        guard let cachePaths = cachePaths else { return [] }
        
        var accessible: [String] = []
        
        for path in cachePaths {
            if accessiblePaths.contains(path) {
                accessible.append(path)
            } else if !inaccessiblePaths.contains(path) {
                // Unknown path - test it
                if !cacheDirectoryContents(path).isEmpty || 
                   (FileManager.default.fileExists(atPath: path) && !inaccessiblePaths.contains(path)) {
                    accessible.append(path)
                }
            }
        }
        
        writeLog("FileSystemCache: \(accessible.count)/\(cachePaths.count) cache paths accessible", logLevel: .info)
        return accessible
    }
}
