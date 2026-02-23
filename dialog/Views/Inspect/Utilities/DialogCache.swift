//
//  DialogCache.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Persistent cache system using plist storage
//  Initially stores icon details and metadata for inspect mode - but expandable as we see in experimental mode WIP
//

import Foundation

class DialogCache {

    struct CacheEntry: Codable {
        let filename: String
        let resolvedPath: String
        let fileSize: Int64
        let lastModified: Date
        let checksum: String?
        let metadata: [String: String]
        let timestamp: Date
    }

    struct CacheMetadata: Codable {
        let version: String
        let created: Date
        var lastUpdated: Date
        var entryCount: Int
        let bundleIdentifier: String
    }

    static let shared = DialogCache()

    private let cacheDir: String
    private let cachePlistPath: String
    private let metadataPlistPath: String
    private var entries: [String: CacheEntry] = [:]
    private var metadata: CacheMetadata
    private let queue = DispatchQueue(label: "dialog.cache", attributes: .concurrent)
    private let bundleID: String
    private var isDirty = false
    private var saveTimer: Timer?

    private init() {
        self.bundleID = Bundle.main.bundleIdentifier ?? "au.csiro.dialog"
        self.cacheDir = "/var/tmp/\(bundleID).cache"
        self.cachePlistPath = "\(cacheDir)/entries.plist"
        self.metadataPlistPath = "\(cacheDir)/metadata.plist"

        self.metadata = CacheMetadata(
            version: "1.0",
            created: Date(),
            lastUpdated: Date(),
            entryCount: 0,
            bundleIdentifier: bundleID
        )

        setupCacheDirectory()
        loadCache()
        startAutoSave()

        writeLog("DialogCache: Initialized at \(cacheDir)", logLevel: .info)
    }

    deinit {
        saveTimer?.invalidate()
        saveIfNeeded()
    }

    private func setupCacheDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDir) {
            do {
                try fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
                writeLog("DialogCache: Created cache directory", logLevel: .debug)
            } catch {
                writeLog("DialogCache: Failed to create cache directory: \(error)", logLevel: .error)
            }
        }
    }

    private func startAutoSave() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveIfNeeded()
        }
    }

    // MARK: - Cache Operations

    func store(_ key: String, resolvedPath: String, metadata: [String: String] = [:]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let filename = (key as NSString).lastPathComponent
            var fileSize: Int64 = 0
            var lastModified = Date()
            var checksum: String?

            if let attributes = try? FileManager.default.attributesOfItem(atPath: resolvedPath) {
                fileSize = attributes[.size] as? Int64 ?? 0
                lastModified = attributes[.modificationDate] as? Date ?? Date()
            }

            // Calculate simple checksum for validation
            if fileSize > 0 && fileSize < 1024 * 1024 { // Only for files < 1MB
                checksum = self.calculateChecksum(for: resolvedPath)
            }

            let entry = CacheEntry(
                filename: filename,
                resolvedPath: resolvedPath,
                fileSize: fileSize,
                lastModified: lastModified,
                checksum: checksum,
                metadata: metadata,
                timestamp: Date()
            )

            self.entries[key] = entry
            self.isDirty = true
            self.metadata.entryCount = self.entries.count
            self.metadata.lastUpdated = Date()

            writeLog("DialogCache: Stored \(key) -> \(resolvedPath)", logLevel: .debug)
        }
    }

    func retrieve(_ key: String) -> CacheEntry? {
        queue.sync {
            if let entry = entries[key] {
                // Validate that the file still exists
                if FileManager.default.fileExists(atPath: entry.resolvedPath) {
                    return entry
                } else {
                    // Remove invalid entry
                    queue.async(flags: .barrier) { [weak self] in
                        self?.entries.removeValue(forKey: key)
                        self?.isDirty = true
                    }
                    writeLog("DialogCache: Removed invalid entry for \(key)", logLevel: .debug)
                }
            }
            return nil
        }
    }

    func remove(_ key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.entries.removeValue(forKey: key)
            self?.isDirty = true
            self?.metadata.entryCount = self?.entries.count ?? 0
            self?.metadata.lastUpdated = Date()
            writeLog("DialogCache: Removed \(key)", logLevel: .debug)
        }
    }

    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.entries.removeAll()
            self?.isDirty = true
            self?.metadata.entryCount = 0
            self?.metadata.lastUpdated = Date()
            writeLog("DialogCache: Cleared all entries", logLevel: .info)
        }
    }

    func getAllEntries() -> [String: CacheEntry] {
        queue.sync {
            return entries
        }
    }

    // MARK: - Persistence

    private func loadCache() {
        // Load metadata
        if let metadataData = try? Data(contentsOf: URL(fileURLWithPath: metadataPlistPath)),
           let loadedMetadata = try? PropertyListDecoder().decode(CacheMetadata.self, from: metadataData) {
            self.metadata = loadedMetadata
            writeLog("DialogCache: Loaded metadata - \(loadedMetadata.entryCount) entries", logLevel: .debug)
        }

        // Load entries
        if let entriesData = try? Data(contentsOf: URL(fileURLWithPath: cachePlistPath)),
           let loadedEntries = try? PropertyListDecoder().decode([String: CacheEntry].self, from: entriesData) {
            self.entries = loadedEntries
            writeLog("DialogCache: Loaded \(loadedEntries.count) cache entries", logLevel: .info)

            // Validate entries
            validateEntries()
        }
    }

    private func validateEntries() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let invalidKeys = self.entries
                .filter { !FileManager.default.fileExists(atPath: $0.value.resolvedPath) }
                .map { $0.key }

            for key in invalidKeys {
                self.entries.removeValue(forKey: key)
            }

            if !invalidKeys.isEmpty {
                self.isDirty = true
                self.metadata.entryCount = self.entries.count
                writeLog("DialogCache: Removed \(invalidKeys.count) invalid entries", logLevel: .info)
            }
        }
    }

    private func saveIfNeeded() {
        queue.sync {
            if isDirty {
                save()
            }
        }
    }

    private func save() {
        do {
            // Save metadata
            let metadataData = try PropertyListEncoder().encode(metadata)
            try metadataData.write(to: URL(fileURLWithPath: metadataPlistPath))

            // Save entries
            let entriesData = try PropertyListEncoder().encode(entries)
            try entriesData.write(to: URL(fileURLWithPath: cachePlistPath))

            isDirty = false
            writeLog("DialogCache: Saved \(entries.count) entries", logLevel: .debug)
        } catch {
            writeLog("DialogCache: Failed to save cache: \(error)", logLevel: .error)
        }
    }

    // MARK: - Utilities

    private func calculateChecksum(for path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        // Simple checksum using first and last 1KB of file
        let sampleSize = 1024
        var sample = Data()

        if data.count <= sampleSize * 2 {
            sample = data
        } else {
            sample.append(data.prefix(sampleSize))
            sample.append(data.suffix(sampleSize))
        }

        return sample.base64EncodedString().prefix(32).description
    }

    // MARK: - Image Resolution Integration

    func getCachedImagePath(for key: String) -> String? {
        if let entry = retrieve(key) {
            return entry.resolvedPath
        }
        return nil
    }

    func storeImageResolution(originalPath: String, resolvedPath: String, appId: String? = nil) {
        var metadata: [String: String] = [:]
        if let appId = appId {
            metadata["appId"] = appId
        }
        metadata["originalPath"] = originalPath

        store(originalPath, resolvedPath: resolvedPath, metadata: metadata)
    }

    // MARK: - Statistics

    func getStatistics() -> [String: Any] {
        queue.sync {
            return [
                "entryCount": entries.count,
                "cacheSize": calculateCacheSize(),
                "created": metadata.created,
                "lastUpdated": metadata.lastUpdated,
                "version": metadata.version,
                "bundleIdentifier": metadata.bundleIdentifier
            ]
        }
    }

    private func calculateCacheSize() -> Int64 {
        entries.values.reduce(0) { $0 + $1.fileSize }
    }
}
