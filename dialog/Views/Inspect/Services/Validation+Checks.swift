//
//  Validation+Checks.swift
//  dialog
//
//  Validation extension: the file-existence check and the plist cache.
//

import Foundation

extension Validation {
    // MARK: - File Existence

    /// Valid when any of the item's paths exists.
    func validateFileExistence(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> ValidationResult {
        writeLog("ValidationService: Checking file existence for '\(item.id)'", logLevel: .debug)

        var foundPath: String?
        let exists = item.paths.first { path in
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            let fileExists = FileManager.default.fileExists(atPath: resolvedPath)
            writeLog("ValidationService: Path '\(path)' resolved to '\(resolvedPath)' exists: \(fileExists)", logLevel: .debug)
            if fileExists {
                foundPath = resolvedPath
            }
            return fileExists
        } != nil
        
        writeLog("ValidationService: File existence result for '\(item.id)': \(exists)", logLevel: .debug)
        
        return ValidationResult(
            itemId: item.id,
            isValid: exists,
            validationType: .fileExistence,
            details: foundPath != nil ? ValidationDetails(
                path: foundPath!,
                key: nil,
                expectedValue: "File exists",
                actualValue: exists ? "Found" : "Not found",
                evaluationType: "file_existence"
            ) : nil
        )
    }
    
    // MARK: - Cache Management

    /// Loads every plist the items and sources name into the cache, reporting (loaded, total).
    func preCachePlistsAsyncWithProgress(from items: [InspectConfig.ItemConfig],
                                                  and sources: [InspectConfig.PlistSourceConfig]?,
                                                  onProgress: (@MainActor @Sendable (Int, Int) -> Void)?) async {
        var uniquePaths = Set<String>()

        for item in items {
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if expandedPath.hasSuffix(".plist") {
                    uniquePaths.insert(expandedPath)
                }
            }
        }

        if let sources = sources {
            for source in sources {
                let expandedPath = (source.path as NSString).expandingTildeInPath
                uniquePaths.insert(expandedPath)
            }
        }

        let totalFiles = uniquePaths.count
        var loadedCount = 0

        await MainActor.run {
            onProgress?(0, totalFiles)
        }

        let pathsArray = Array(uniquePaths)
        await withTaskGroup(of: Bool.self) { group in
            for path in pathsArray {
                group.addTask(priority: .userInitiated) { [weak self] in
                    _ = await self?.loadPlistCachedAsync(at: path)
                    return true
                }
            }

            while await group.next() != nil {
                loadedCount += 1
                let currentCount = loadedCount
                let total = totalFiles
                await MainActor.run {
                    onProgress?(currentCount, total)
                }
            }
        }

        writeLog("ValidationService: Pre-cached \(uniquePaths.count) plist files", logLevel: .debug)
    }

    func preCachePlistsAsync(from items: [InspectConfig.ItemConfig],
                                    and sources: [InspectConfig.PlistSourceConfig]?) async {
        await preCachePlistsAsyncWithProgress(from: items, and: sources, onProgress: nil)
    }

    /// The plist at `path`, from the cache while its modification date and size are unchanged.
    /// Reads happen inside `cacheQueue.sync`; cache writes hop to the main actor.
    func loadPlistCachedAsync(at path: String, basePath: String? = nil) async -> [String: Any]? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath

        return await withCheckedContinuation { continuation in
            cacheQueue.sync {
                if let cached = plistCache[expandedPath] {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                       let modifiedDate = attributes[.modificationDate] as? Date,
                       let fileSize = attributes[.size] as? NSNumber {

                        if cached.lastModified == modifiedDate && cached.fileSize == fileSize.int64Value {
                            continuation.resume(returning: cached.data)
                            return
                        }
                    }
                }

                guard let data = FileManager.default.contents(atPath: expandedPath),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                      let modifiedDate = attributes[.modificationDate] as? Date,
                      let fileSize = attributes[.size] as? NSNumber else {
                    continuation.resume(returning: nil)
                    return
                }

                let cached = CachedPlist(data: plist, lastModified: modifiedDate, fileSize: fileSize.int64Value)

                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if self.plistCache.count >= self.maxCacheSize {
                        // Evicts 10 arbitrary entries; Dictionary order is unspecified.
                        let keysToRemove = Array(self.plistCache.keys.prefix(10))
                        for key in keysToRemove {
                            self.plistCache.removeValue(forKey: key)
                        }
                        writeLog("ValidationService: Cache cleanup performed, removed \(keysToRemove.count) entries", logLevel: .debug)
                    }

                    self.plistCache[expandedPath] = cached
                }

                continuation.resume(returning: plist)
            }
        }
    }

    func clearCache() {
        Task { @MainActor [weak self] in
            self?.plistCache.removeAll()
        }
        writeLog("ValidationService: Cache cleared", logLevel: .debug)
    }
}
