//
//  Validation.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/07/2025
//  Centralized validation service for all file and plist validation logic
//  Integrates caching, batch processing, and async validation
//  MODERNIZED: Replaced DispatchSemaphore with Swift Concurrency for production stability
//

import Foundation

// MARK: - Validation Models

struct ValidationRequest {
    let item: InspectConfig.ItemConfig
    let plistSources: [InspectConfig.PlistSourceConfig]?
    let basePath: String?  // Config directory for resolving relative paths

    init(item: InspectConfig.ItemConfig, plistSources: [InspectConfig.PlistSourceConfig]? = nil, basePath: String? = nil) {
        self.item = item
        self.plistSources = plistSources
        self.basePath = basePath
    }
}

struct ValidationResult {
    let itemId: String
    let isValid: Bool
    let validationType: ValidationType
    let details: ValidationDetails?
}

enum ValidationType {
    case fileExistence
    case plistValidation
    case complexPlistValidation
}

struct ValidationDetails {
    let path: String
    let key: String?
    let expectedValue: String?
    let actualValue: String?
    let evaluationType: String?
}

// MARK: - Validation Service

@MainActor
class Validation: ObservableObject {

    // MARK: - Singleton
    static let shared = Validation()

    // MARK: - Caching
    private struct CachedPlist {
        let data: [String: Any]
        let lastModified: Date
        let fileSize: Int64
    }

    private var plistCache = [String: CachedPlist]()
    private let cacheQueue = DispatchQueue(label: "validation.cache", qos: .userInitiated, attributes: .concurrent)
    private let maxCacheSize = 100 // Limit cache to 100 plists to prevent memory issues

    // MARK: - Publishers
    @Published var validationProgress: Double = 0.0
    @Published var isValidating: Bool = false
    
    // MARK: - Public API

    /// Modern async batch validation with progress reporting
    func validateItemsBatch(_ items: [InspectConfig.ItemConfig],
                           plistSources: [InspectConfig.PlistSourceConfig]? = nil) async -> [String: Bool] {
        
        isValidating = true
        validationProgress = 0.0
        
        defer {
            isValidating = false
            validationProgress = 1.0
        }
        
        // Pre-cache all unique plist files with timeout protection
        await withTimeout(seconds: 30.0) { [weak self] in
            await self?.preCachePlistsAsync(from: items, and: plistSources)
        }
        
        let totalItems = items.count
        var results = [String: Bool]()
        
        // Process items with controlled concurrency and timeout protection
        await withTaskGroup(of: (String, Bool).self, returning: Void.self) { group in
            // Limit concurrent tasks to avoid overwhelming the system
            let maxConcurrency = min(12, items.count)  // High concurrency for fast validation
            var currentIndex = 0
            
            // Start initial batch of tasks
            for _ in 0..<min(maxConcurrency, items.count) where currentIndex < items.count {
                let item = items[currentIndex]
                currentIndex += 1
                
                group.addTask(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return (item.id, false) }
                    
                    // Add timeout protection for individual validations
                    let result = await withTimeout(seconds: 10.0) { [weak self] in
                        guard let self = self else { return ValidationResult(itemId: item.id, isValid: false, validationType: .fileExistence, details: nil) }
                        let request = ValidationRequest(item: item, plistSources: plistSources)
                        return await self.validateItemCachedAsync(request)
                    }
                    return (item.id, result?.isValid ?? false)
                }
            }
            
            // Process results and add new tasks as they complete
            while let (itemId, isValid) = await group.next() {
                results[itemId] = isValid
                
                // Update progress on main actor
                let progress = Double(results.count) / Double(totalItems)
                await MainActor.run {
                    self.validationProgress = progress
                }
                
                // Add next task if available
                if currentIndex < items.count {
                    let nextItem = items[currentIndex]
                    currentIndex += 1
                    
                    group.addTask(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return (nextItem.id, false) }
                        
                        // Add timeout protection for individual validations
                        let result = await withTimeout(seconds: 10.0) { [weak self] in
                            guard let self = self else { return ValidationResult(itemId: nextItem.id, isValid: false, validationType: .fileExistence, details: nil) }
                            let request = ValidationRequest(item: nextItem, plistSources: plistSources)
                            return await self.validateItemCachedAsync(request)
                        }
                        
                        return (nextItem.id, result?.isValid ?? false)
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: - Timeout Protection Helper
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            // Add the main operation
            group.addTask {
                await operation()
            }
            
            // Add timeout task
            group.addTask {
                do {
                    try await Task.sleep(for: .seconds(seconds))
                    return nil // Timeout
                } catch {
                    return nil // Task was cancelled (good)
                }
            }
            
            // Return first result and cancel the rest
            // swiftlint:disable:next redundant_nil_coalescing
            let result = await group.next() ?? nil  // Flatten T?? to T?
            group.cancelAll()
            return result
        }
    }

    /// Legacy completion-based batch validation (for backward compatibility)
    /// ⚠️  LEGACY: Use async version for new code
    func validateItemsBatch(_ items: [InspectConfig.ItemConfig],
                           plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                           completion: @escaping ([String: Bool]) -> Void) {

        Task { @MainActor in
            let results = await validateItemsBatch(items, plistSources: plistSources)
            completion(results)
        }
    }

    /// STREAMING: Batch validation with per-item callbacks for progressive UI updates
    /// Each validation result is emitted immediately via onItemValidated callback
    /// Optional onPreCacheProgress callback reports progress during plist file loading phase
    func validateItemsBatchStreaming(_ items: [InspectConfig.ItemConfig],
                                    plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                                    onPreCacheProgress: ((Int, Int) -> Void)? = nil,
                                    onItemValidated: @escaping (String, Bool) -> Void,
                                    completion: @escaping ([String: Bool]) -> Void) {

        Task { @MainActor in
            isValidating = true
            validationProgress = 0.0

            defer {
                isValidating = false
                validationProgress = 1.0
            }

            // Pre-cache all unique plist files with progress reporting
            await withTimeout(seconds: 30.0) { [weak self] in
                await self?.preCachePlistsAsyncWithProgress(from: items, and: plistSources, onProgress: onPreCacheProgress)
            }

            let totalItems = items.count
            var results = [String: Bool]()

            // Process items with controlled concurrency
            await withTaskGroup(of: (String, Bool).self, returning: Void.self) { group in
                let maxConcurrency = min(12, items.count)  // High concurrency for fast validation
                var currentIndex = 0

                // Start initial batch
                for _ in 0..<min(maxConcurrency, items.count) where currentIndex < items.count {
                    let item = items[currentIndex]
                    currentIndex += 1

                    group.addTask(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return (item.id, false) }
                        let result = await withTimeout(seconds: 10.0) { [weak self] in
                            guard let self = self else { return ValidationResult(itemId: item.id, isValid: false, validationType: .fileExistence, details: nil) }
                            let request = ValidationRequest(item: item, plistSources: plistSources)
                            return await self.validateItemCachedAsync(request)
                        }
                        return (item.id, result?.isValid ?? false)
                    }
                }

                // Process results as they complete - emit each one immediately
                while let (itemId, isValid) = await group.next() {
                    results[itemId] = isValid

                    // STREAM: Emit this result immediately for per-card progress
                    await MainActor.run {
                        onItemValidated(itemId, isValid)
                        self.validationProgress = Double(results.count) / Double(totalItems)
                    }

                    // Add next task if available
                    if currentIndex < items.count {
                        let nextItem = items[currentIndex]
                        currentIndex += 1

                        group.addTask(priority: .userInitiated) { [weak self] in
                            guard let self = self else { return (nextItem.id, false) }
                            let result = await withTimeout(seconds: 10.0) { [weak self] in
                                guard let self = self else { return ValidationResult(itemId: nextItem.id, isValid: false, validationType: .fileExistence, details: nil) }
                                let request = ValidationRequest(item: nextItem, plistSources: plistSources)
                                return await self.validateItemCachedAsync(request)
                            }
                            return (nextItem.id, result?.isValid ?? false)
                        }
                    }
                }
            }

            completion(results)
        }
    }

    /// Single item validation (cached)
    func validateItemCached(_ request: ValidationRequest) -> ValidationResult {
        let item = request.item

        // Check for simplified plist validation first
        if item.plistKey != nil {
            return validateSimplePlistItemCached(item, basePath: request.basePath)
        }

        // Check for complex plist sources validation
        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return validateComplexPlistItemCached(item, source: source)
            }
        }

        // Fallback to file existence validation
        return validateFileExistence(item, basePath: request.basePath)
    }

    /// Async version of cached item validation
    private func validateItemCachedAsync(_ request: ValidationRequest) async -> ValidationResult {
        let item = request.item

        // Check for simplified plist validation first
        if item.plistKey != nil {
            return await validateSimplePlistItemCachedAsync(item, basePath: request.basePath)
        }

        // Check for complex plist sources validation
        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return await validateComplexPlistItemCachedAsync(item, source: source)
            }
        }

        // Fallback to file existence validation
        return validateFileExistence(item, basePath: request.basePath)
    }

    /// Main validation entry point (synchronous for backward compatibility)
    func validateItem(_ request: ValidationRequest) -> ValidationResult {
        let item = request.item

        // Check for simplified plist validation first
        if item.plistKey != nil {
            return validateSimplePlistItem(item, basePath: request.basePath)
        }

        // Check for complex plist sources validation
        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return validateComplexPlistItem(item, source: source)
            }
        }

        // Fallback to file existence validation with basePath support
        return validateFileExistence(item, basePath: request.basePath)
    }

    // MARK: - Glob Pattern Resolution

    /// Resolve glob patterns in plist paths to actual file paths
    /// Supports wildcards for UUID'd files like "*.installinfo.plist"
    /// - Parameters:
    ///   - path: Path that may contain glob patterns (* or ?) or be relative
    ///   - basePath: Optional base directory for resolving relative paths (e.g., config file directory)
    /// - Returns: First matching file path, or original path if no pattern or no match
    func resolvePlistPath(_ path: String, basePath: String? = nil) -> String {
        // Handle relative paths with basePath
        var workingPath = path
        if !path.hasPrefix("/") && !path.hasPrefix("~"), let basePath = basePath {
            let combined = (basePath as NSString).appendingPathComponent(path)
            // Normalize the path to resolve .. and .
            let normalizedCombined = (combined as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: normalizedCombined) {
                writeLog("Validation: Resolved relative path '\(path)' with basePath → '\(normalizedCombined)'", logLevel: .info)
                return normalizedCombined
            }
            // Even if file doesn't exist yet, use the combined path for further resolution
            workingPath = normalizedCombined
        }

        // Expand tilde
        let expandedPath = (workingPath as NSString).expandingTildeInPath

        // Check if path contains glob patterns
        guard expandedPath.contains("*") || expandedPath.contains("?") else {
            return expandedPath  // No pattern, return as-is
        }

        // Split into directory and filename pattern
        let directory = (expandedPath as NSString).deletingLastPathComponent
        let pattern = (expandedPath as NSString).lastPathComponent

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: directory) else {
            writeLog("Validation: Glob directory does not exist: \(directory)", logLevel: .debug)
            return expandedPath  // Return original if directory doesn't exist
        }

        // Get directory contents
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            writeLog("Validation: Cannot read directory for glob: \(directory)", logLevel: .debug)
            return expandedPath  // Return original if can't read directory
        }

        // Find first matching file using fnmatch (shell-style pattern matching)
        if let matchedFile = contents.first(where: { filename in
            fnmatch(pattern, filename, 0) == 0
        }) {
            let resolvedPath = "\(directory)/\(matchedFile)"
            writeLog("Validation: Resolved glob '\(expandedPath)' → '\(resolvedPath)'", logLevel: .info)
            return resolvedPath
        }

        writeLog("Validation: No files match glob pattern: \(expandedPath)", logLevel: .debug)
        return expandedPath  // No match, return original
    }

    /// Get actual plist value for display purposes
    /// - Parameters:
    ///   - path: Path to the plist file (can be relative if basePath is provided)
    ///   - key: Plist key with optional dot notation for nested keys
    ///   - basePath: Optional base directory for resolving relative paths
    func getPlistValue(at path: String, key: String, basePath: String? = nil) -> String? {
        // Resolve glob patterns and relative paths first
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        // Support nested keys with dot notation - thread-safe navigation
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue } // Skip empty key parts
            
            if let dict = current as? [String: Any] {
                guard let nextValue = dict[keyPart] else {
                    return nil // Key doesn't exist
                }
                current = nextValue
            } else if let array = current as? [Any], let index = Int(keyPart) {
                // Safe array access with bounds checking
                guard index >= 0 && index < array.count else {
                    return nil // Index out of bounds
                }
                current = array[index]
            } else {
                return nil // Key doesn't exist or wrong type
            }
            
            // Handle NSNull safely
            if current is NSNull {
                return nil // Key exists but value is null
            }
        }
        
        // Convert value to string for display
        return formatValueForDisplay(current)
    }

    /// Convenience overload with different parameter label
    func getPlistValue(path: String, key: String, basePath: String? = nil) -> String? {
        return getPlistValue(at: path, key: key, basePath: basePath)
    }

    // MARK: - UserDefaults Support

    /// Extract UserDefaults domain from plist path
    /// - Parameter path: Plist file path (e.g., "~/Library/Preferences/.GlobalPreferences.plist")
    /// - Returns: Domain name (e.g., ".GlobalPreferences") or nil if not a valid UserDefaults path
    func extractDomainFromPath(_ path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        let filename = (expanded as NSString).lastPathComponent

        // Handle .GlobalPreferences specially
        if filename == ".GlobalPreferences.plist" {
            return ".GlobalPreferences"
        }

        // Extract domain from com.company.app.plist format
        if filename.hasSuffix(".plist") {
            let domain = filename.replacingOccurrences(of: ".plist", with: "")
            return domain
        }

        return nil
    }

    /// Get plist value using UserDefaults (faster, cached)
    /// - Parameters:
    ///   - domain: UserDefaults suite name (e.g., ".GlobalPreferences", "com.apple.dock")
    ///   - key: Plist key with optional dot notation (e.g., "AppleInterfaceStyle", "Settings.Network.Proxy")
    /// - Returns: String representation of the value, or nil if not found
    func getUserDefaultsValue(domain: String, key: String) -> String? {
        // Get appropriate UserDefaults instance
        let defaults: UserDefaults?
        if domain == ".GlobalPreferences" || domain == "NSGlobalDomain" {
            // NSGlobalDomain and .GlobalPreferences are special - use standard defaults
            defaults = UserDefaults.standard
        } else {
            defaults = UserDefaults(suiteName: domain)
        }

        guard let defaults = defaults else { return nil }

        // Force synchronize to ensure we have latest values from disk
        defaults.synchronize()

        // Handle nested keys with dot notation
        let keyParts = key.components(separatedBy: ".")

        // Get root value from UserDefaults
        guard let rootKey = keyParts.first, !rootKey.isEmpty else { return nil }
        guard let rootValue = defaults.object(forKey: rootKey) else { return nil }

        // If single key, return it
        if keyParts.count == 1 {
            return formatValueForDisplay(rootValue)
        }

        // Navigate nested path (same logic as getPlistValue)
        var current: Any = rootValue
        for keyPart in keyParts.dropFirst() {
            guard !keyPart.isEmpty else { continue }

            if let dict = current as? [String: Any] {
                guard let nextValue = dict[keyPart] else {
                    return nil
                }
                current = nextValue
            } else if let array = current as? [Any], let index = Int(keyPart) {
                guard index >= 0 && index < array.count else {
                    return nil
                }
                current = array[index]
            } else {
                return nil
            }

            if current is NSNull {
                return nil
            }
        }

        return formatValueForDisplay(current)
    }

    /// Get plist value using full file path with `defaults read` command
    /// - Parameters:
    ///   - path: Full path to plist file (e.g., "/private/var/db/ConfigurationProfiles/Settings/com.apple.mdm.enrollmentnotification.plist")
    ///   - key: Plist key with optional dot notation
    /// - Returns: String representation of the value, or nil if not found
    func getUserDefaultsValueFromPath(_ path: String, key: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Use `defaults read` command with full path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", expandedPath, key]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                writeLog("ValidationService: defaults read failed for '\(expandedPath)' key '\(key)' (exit code: \(process.terminationStatus))", logLevel: .debug)
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Trim whitespace and newlines
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

            // If empty, return nil
            if trimmed.isEmpty { return nil }

            writeLog("ValidationService: defaults read '\(expandedPath)' key '\(key)' = '\(trimmed)'", logLevel: .debug)
            return trimmed

        } catch {
            writeLog("ValidationService: Error running defaults read: \(error.localizedDescription)", logLevel: .error)
            return nil
        }
    }

    /// Get plist value using either domain name or full path
    /// - Parameters:
    ///   - pathOrDomain: Either a UserDefaults domain (e.g., "com.apple.dock") or full path (e.g., "/private/var/db/.../file.plist")
    ///   - key: Plist key with optional dot notation
    /// - Returns: String representation of the value, or nil if not found
    func getUserDefaultsValue(pathOrDomain: String, key: String) -> String? {
        // Detect if this is a full path or a domain name
        let isFullPath = pathOrDomain.hasPrefix("/") || pathOrDomain.hasPrefix("~")

        if isFullPath {
            // Use defaults read with full path
            return getUserDefaultsValueFromPath(pathOrDomain, key: key)
        } else {
            // Use UserDefaults API with domain
            return getUserDefaultsValue(domain: pathOrDomain, key: key)
        }
    }

    // MARK: - JSON File Support

    /// Resolve glob patterns in JSON paths to actual file paths
    /// Supports wildcards for dynamic files like "*.config.json"
    /// - Parameter path: Path that may contain glob patterns (* or ?)
    /// - Returns: First matching file path, or original path if no pattern or no match
    func resolveJsonPath(_ path: String) -> String {
        // Expand tilde first
        let expandedPath = (path as NSString).expandingTildeInPath

        // Check if path contains glob patterns
        guard expandedPath.contains("*") || expandedPath.contains("?") else {
            return expandedPath  // No pattern, return as-is
        }

        // Split into directory and filename pattern
        let directory = (expandedPath as NSString).deletingLastPathComponent
        let pattern = (expandedPath as NSString).lastPathComponent

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: directory) else {
            writeLog("Validation: JSON glob directory does not exist: \(directory)", logLevel: .debug)
            return expandedPath  // Return original if directory doesn't exist
        }

        // Get directory contents
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            writeLog("Validation: Cannot read directory for JSON glob: \(directory)", logLevel: .debug)
            return expandedPath  // Return original if can't read directory
        }

        // Find first matching file using fnmatch (shell-style pattern matching)
        if let matchedFile = contents.first(where: { filename in
            fnmatch(pattern, filename, 0) == 0
        }) {
            let resolvedPath = "\(directory)/\(matchedFile)"
            writeLog("Validation: Resolved JSON glob '\(expandedPath)' → '\(resolvedPath)'", logLevel: .info)
            return resolvedPath
        }

        writeLog("Validation: No files match JSON glob pattern: \(expandedPath)", logLevel: .debug)
        return expandedPath  // No match, return original
    }

    /// Get JSON value for display purposes
    /// Supports dot notation for nested keys (e.g., "deployment.status")
    /// - Parameters:
    ///   - path: Path to JSON file (supports glob patterns)
    ///   - key: JSON key path with optional dot notation
    /// - Returns: String representation of the value, or nil if not found
    func getJsonValue(at path: String, key: String) -> String? {
        // Resolve glob patterns first
        let resolvedPath = resolveJsonPath(path)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath

        // Check file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            writeLog("Validation: JSON file not found: \(expandedPath)", logLevel: .debug)
            return nil
        }

        // Read JSON data
        guard let data = FileManager.default.contents(atPath: expandedPath) else {
            writeLog("Validation: Cannot read JSON file: \(expandedPath)", logLevel: .debug)
            return nil
        }

        // Parse JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            writeLog("Validation: Invalid JSON in file: \(expandedPath)", logLevel: .debug)
            return nil
        }

        // Support nested keys with dot notation - thread-safe navigation
        let keyParts = key.components(separatedBy: ".")
        var current: Any = jsonObject

        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue } // Skip empty key parts

            if let dict = current as? [String: Any] {
                guard let nextValue = dict[keyPart] else {
                    writeLog("Validation: JSON key '\(keyPart)' not found in path '\(key)'", logLevel: .debug)
                    return nil // Key doesn't exist
                }
                current = nextValue
            } else if let array = current as? [Any], let index = Int(keyPart) {
                // Safe array access with bounds checking
                guard index >= 0 && index < array.count else {
                    writeLog("Validation: JSON array index \(index) out of bounds (0..\(array.count-1))", logLevel: .debug)
                    return nil // Index out of bounds
                }
                current = array[index]
            } else {
                writeLog("Validation: JSON key '\(keyPart)' not found or wrong type in path '\(key)'", logLevel: .debug)
                return nil // Key doesn't exist or wrong type
            }

            // Handle NSNull safely
            if current is NSNull {
                writeLog("Validation: JSON key '\(key)' exists but value is null", logLevel: .debug)
                return nil // Key exists but value is null
            }
        }

        // Convert value to string for display
        return formatValueForDisplay(current)
    }

    /// Convenience overload with different parameter label
    func getJsonValue(path: String, key: String) -> String? {
        return getJsonValue(at: path, key: key)
    }

    // MARK: - Private Validation Methods
    
    private func validateFileExistence(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> ValidationResult {
        // Debug logging to understand what's happening
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

    /// Pre-cache with progress reporting for UI feedback
    private func preCachePlistsAsyncWithProgress(from items: [InspectConfig.ItemConfig],
                                                  and sources: [InspectConfig.PlistSourceConfig]?,
                                                  onProgress: ((Int, Int) -> Void)?) async {
        var uniquePaths = Set<String>()

        // Collect all unique plist paths
        for item in items {
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if expandedPath.hasSuffix(".plist") {
                    uniquePaths.insert(expandedPath)
                }
            }
        }

        // Add paths from plist sources
        if let sources = sources {
            for source in sources {
                let expandedPath = (source.path as NSString).expandingTildeInPath
                uniquePaths.insert(expandedPath)
            }
        }

        let totalFiles = uniquePaths.count
        var loadedCount = 0

        // Report initial state
        await MainActor.run {
            onProgress?(0, totalFiles)
        }

        // Load all plists into cache with progress tracking
        let pathsArray = Array(uniquePaths)
        await withTaskGroup(of: Bool.self) { group in
            for path in pathsArray {
                group.addTask(priority: .userInitiated) { [weak self] in
                    _ = await self?.loadPlistCachedAsync(at: path)
                    return true
                }
            }

            // Report progress as each file completes
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

    private func preCachePlistsAsync(from items: [InspectConfig.ItemConfig],
                                    and sources: [InspectConfig.PlistSourceConfig]?) async {
        // Delegate to progress version without callback
        await preCachePlistsAsyncWithProgress(from: items, and: sources, onProgress: nil)
    }

    private func preCachePlists(from items: [InspectConfig.ItemConfig],
                                and sources: [InspectConfig.PlistSourceConfig]?) {
        var uniquePaths = Set<String>()

        // Collect all unique plist paths
        for item in items {
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if expandedPath.hasSuffix(".plist") {
                    uniquePaths.insert(expandedPath)
                }
            }
        }

        // Add paths from plist sources
        if let sources = sources {
            for source in sources {
                let expandedPath = (source.path as NSString).expandingTildeInPath
                uniquePaths.insert(expandedPath)
            }
        }

        // Load all plists into cache
        for path in uniquePaths {
            _ = loadPlistCached(at: path)
        }

        writeLog("ValidationService: Pre-cached \(uniquePaths.count) plist files", logLevel: .debug)
    }

    private func loadPlistCachedAsync(at path: String, basePath: String? = nil) async -> [String: Any]? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath

        // Check cache first (using actor to ensure thread safety)
        return await withCheckedContinuation { continuation in
            cacheQueue.sync {
                if let cached = plistCache[expandedPath] {
                    // Check if file has been modified
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                       let modifiedDate = attributes[.modificationDate] as? Date,
                       let fileSize = attributes[.size] as? NSNumber {

                        if cached.lastModified == modifiedDate && cached.fileSize == fileSize.int64Value {
                            continuation.resume(returning: cached.data) // Cache is still valid
                            return
                        }
                    }
                }

                // Load from disk
                guard let data = FileManager.default.contents(atPath: expandedPath),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                      let modifiedDate = attributes[.modificationDate] as? Date,
                      let fileSize = attributes[.size] as? NSNumber else {
                    continuation.resume(returning: nil)
                    return
                }

                // Update cache with size management
                let cached = CachedPlist(data: plist, lastModified: modifiedDate, fileSize: fileSize.int64Value)

                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    // Manage cache size
                    if self.plistCache.count >= self.maxCacheSize {
                        // Remove oldest entries (simple FIFO cleanup)
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

    private func loadPlistCached(at path: String, basePath: String? = nil) -> [String: Any]? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath

        // Check cache first
        return cacheQueue.sync {
            if let cached = plistCache[expandedPath] {
                // Check if file has been modified
                if let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                   let modifiedDate = attributes[.modificationDate] as? Date,
                   let fileSize = attributes[.size] as? NSNumber {

                    if cached.lastModified == modifiedDate && cached.fileSize == fileSize.int64Value {
                        return cached.data // Cache is still valid
                    }
                }
            }

            // Load from disk
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                  let modifiedDate = attributes[.modificationDate] as? Date,
                  let fileSize = attributes[.size] as? NSNumber else {
                return nil
            }

            // Update cache with size management
            let cached = CachedPlist(data: plist, lastModified: modifiedDate, fileSize: fileSize.int64Value)

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Manage cache size
                if self.plistCache.count >= self.maxCacheSize {
                    // Remove oldest entries (simple FIFO cleanup)
                    let keysToRemove = Array(self.plistCache.keys.prefix(10))
                    for key in keysToRemove {
                        self.plistCache.removeValue(forKey: key)
                    }
                    writeLog("ValidationService: Cache cleanup performed, removed \(keysToRemove.count) entries", logLevel: .debug)
                }

                self.plistCache[expandedPath] = cached
            }

            return plist
        }
    }

    func clearCache() {
        Task { @MainActor [weak self] in
            self?.plistCache.removeAll()
        }
        writeLog("ValidationService: Cache cleared", logLevel: .debug)
    }

    func invalidateCacheForPath(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        Task { @MainActor [weak self] in
            self?.plistCache.removeValue(forKey: expandedPath)
        }
    }

    // MARK: - Async Cached Validation Methods

    private func validateSimplePlistItemCachedAsync(_ item: InspectConfig.ItemConfig, basePath: String? = nil) async -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            if let plist = await loadPlistCachedAsync(at: path, basePath: basePath) {
                let result = validatePlistValue(plist: plist, key: plistKey,
                                               expectedValue: item.expectedValue,
                                               evaluation: item.evaluation)
                if result {
                    let actualValue = extractPlistValue(from: plist, key: plistKey)
                    return ValidationResult(
                        itemId: item.id,
                        isValid: true,
                        validationType: .plistValidation,
                        details: ValidationDetails(
                            path: resolvedPath,
                            key: plistKey,
                            expectedValue: item.expectedValue,
                            actualValue: formatValueForDisplay(actualValue),
                            evaluationType: item.evaluation
                        )
                    )
                }
            }
        }

        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: nil
        )
    }

    private func validateComplexPlistItemCachedAsync(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) async -> ValidationResult {
        guard let plist = await loadPlistCachedAsync(at: source.path) else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }

        // General validation using critical keys
        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }

        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }

    // MARK: - Cached Validation Methods

    private func validateSimplePlistItemCached(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            if let plist = loadPlistCached(at: path, basePath: basePath) {
                let result = validatePlistValue(plist: plist, key: plistKey,
                                               expectedValue: item.expectedValue,
                                               evaluation: item.evaluation)
                if result {
                    let actualValue = extractPlistValue(from: plist, key: plistKey)
                    return ValidationResult(
                        itemId: item.id,
                        isValid: true,
                        validationType: .plistValidation,
                        details: ValidationDetails(
                            path: resolvedPath,
                            key: plistKey,
                            expectedValue: item.expectedValue,
                            actualValue: formatValueForDisplay(actualValue),
                            evaluationType: item.evaluation
                        )
                    )
                }
            }
        }

        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: nil
        )
    }

    private func validateComplexPlistItemCached(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) -> ValidationResult {
        guard let plist = loadPlistCached(at: source.path) else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }

        // General validation using critical keys
        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }

        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }

    private func validatePlistValue(plist: [String: Any], key: String, expectedValue: String?, evaluation: String?) -> Bool {
        // Navigate nested keys safely with depth protection
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        // Circuit breaker: Prevent excessive nesting (max 20 levels)
        guard keyParts.count <= 20 else {
            writeLog("ValidationService: Key '\(key)' has too many nested levels (\(keyParts.count))", logLevel: .error)
            return false
        }

        for (index, keyPart) in keyParts.enumerated() {
            guard !keyPart.isEmpty else { continue } // Skip empty key parts
            
            // Safety check: Prevent excessively long key parts
            guard keyPart.count < 1000 else {
                writeLog("ValidationService: Key part '\(keyPart)' is too long", logLevel: .error)
                return false
            }
            
            if let dict = current as? [String: Any] {
                guard let next = dict[keyPart] else { 
                    writeLog("ValidationService: Dictionary key '\(keyPart)' not found at level \(index) in '\(key)'", logLevel: .debug)
                    return false 
                }
                current = next
            } else if let array = current as? [Any], let index = Int(keyPart) {
                // Safe array access with bounds checking
                guard index >= 0 && index < array.count else {
                    writeLog("ValidationService: Array index \(index) out of bounds (size: \(array.count)) for key '\(key)'", logLevel: .debug)
                    return false // Index out of bounds
                }
                current = array[index]
            } else {
                writeLog("ValidationService: Invalid navigation - expected dict or array, got \(type(of: current)) for key part '\(keyPart)' in '\(key)'", logLevel: .debug)
                return false // Key doesn't exist or wrong type
            }
            
            // Handle NSNull safely
            if current is NSNull {
                writeLog("ValidationService: Encountered NSNull at key part '\(keyPart)' in '\(key)'", logLevel: .debug)
                return false // Key exists but value is null
            }
        }

        return performSmartEvaluation(
            value: current,
            evaluationType: evaluation ?? "equals",
            expectedValue: expectedValue,
            key: key
        )
    }

    private func extractPlistValue(from plist: [String: Any], key: String) -> Any {
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        // Circuit breaker: Prevent excessive nesting (max 20 levels)
        guard keyParts.count <= 20 else {
            writeLog("ValidationService: Key '\(key)' has too many nested levels (\(keyParts.count))", logLevel: .error)
            return NSNull()
        }

        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue } // Skip empty key parts
            
            // Safety check: Prevent excessively long key parts
            guard keyPart.count < 1000 else {
                writeLog("ValidationService: Key part '\(keyPart)' is too long", logLevel: .error)
                return NSNull()
            }
            
            if let dict = current as? [String: Any] {
                current = dict[keyPart] ?? NSNull()
            } else if let array = current as? [Any], let index = Int(keyPart) {
                // Safe array access with bounds checking
                guard index >= 0 && index < array.count else {
                    return NSNull() // Index out of bounds
                }
                current = array[index]
            } else {
                return NSNull() // Key doesn't exist or wrong type
            }
        }

        return current
    }

    private func validateSimplePlistItem(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            let resolvedPath = resolvePlistPath(path, basePath: basePath)
            if let result = checkSimplePlistKey(at: path, key: plistKey, expectedValue: item.expectedValue, evaluation: item.evaluation, basePath: basePath) {
                let actualValue = getPlistValue(at: path, key: plistKey, basePath: basePath)
                let details = ValidationDetails(
                    path: resolvedPath,
                    key: plistKey,
                    expectedValue: item.expectedValue,
                    actualValue: actualValue,
                    evaluationType: item.evaluation
                )

                return ValidationResult(
                    itemId: item.id,
                    isValid: result,
                    validationType: .plistValidation,
                    details: details
                )
            }
        }

        // If we reach here, file doesn't exist or key not found - this is a failure
        let firstPath = item.paths.first ?? ""
        let resolvedFirstPath = resolvePlistPath(firstPath, basePath: basePath)
        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: ValidationDetails(
                path: resolvedFirstPath,
                key: plistKey,
                expectedValue: item.expectedValue,
                actualValue: nil,
                evaluationType: item.evaluation
            )
        )
    }
    
    private func validateComplexPlistItem(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) -> ValidationResult {
        let expandedPath = (source.path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }
        
        // General validation using critical keys
        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }
        
        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }
    
    // MARK: - Smart Evaluation System
    
    private func checkSimplePlistKey(at path: String, key: String, expectedValue: String?, evaluation: String? = nil, basePath: String? = nil) -> Bool? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil // File doesn't exist or can't be read
        }
        
        // Support nested keys with dot notation (e.g., "Sets.0.ProxyAutoConfigURLString")
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        for keyPart in keyParts {
            guard !keyPart.isEmpty else { continue } // Skip empty key parts
            
            if let dict = current as? [String: Any] {
                guard let nextValue = dict[keyPart] else {
                    writeLog("ValidationService: Key part '\(keyPart)' not found in path '\(key)'", logLevel: .info)
                    return false // Key doesn't exist
                }
                current = nextValue
            } else if let array = current as? [Any], let index = Int(keyPart) {
                // Safe array access with bounds checking
                guard index >= 0 && index < array.count else {
                    writeLog("ValidationService: Array index '\(index)' out of bounds for key '\(key)'", logLevel: .info)
                    return false // Index out of bounds
                }
                current = array[index]
            } else {
                writeLog("ValidationService: Key part '\(keyPart)' not found in path '\(key)'", logLevel: .info)
                return false // Key doesn't exist or wrong type
            }
            
            if current is NSNull {
                writeLog("ValidationService: Key '\(key)' is NSNull", logLevel: .info)
                return false // Key doesn't exist
            }
        }
        
        // Smart evaluation system
        let evaluationType = evaluation ?? "equals" // Default to equals for backward compatibility
        
        return performSmartEvaluation(
            value: current,
            evaluationType: evaluationType,
            expectedValue: expectedValue,
            key: key
        )
    }
    
    private func performSmartEvaluation(value: Any, evaluationType: String, expectedValue: String?, key: String) -> Bool {
        // Handle NSNull safely
        if value is NSNull {
            writeLog("ValidationService: Key '\(key)', Value is NSNull, Result: false", logLevel: .info)
            return false
        }
        
        switch evaluationType.lowercased() {
        case "exists":
            // Just check if key exists (ignore expectedValue)
            let result = !(value is NSNull)
            writeLog("ValidationService: Key '\(key)', Evaluation 'exists', Result: \(result)", logLevel: .info)
            return result
            
        case "boolean":
            // Smart boolean evaluation: 1, true, YES = true; 0, false, NO = false
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'boolean' requires expectedValue", logLevel: .error)
                return false
            }
            
            let expectedBool = parseSmartBoolean(expectedValue)
            let actualBool = parseSmartBoolean(value)
            let result = actualBool == expectedBool
            writeLog("ValidationService: Key '\(key)', Expected bool '\(expectedBool)', Actual bool '\(actualBool)', Result: \(result)", logLevel: .info)
            return result
            
        case "contains":
            // For arrays, check if contains the expectedValue
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'contains' requires expectedValue", logLevel: .error)
                return false
            }
            
            if let arrayValue = value as? [Any] {
                let result = arrayValue.contains { item in
                    if item is NSNull { return false } // Skip NSNull items
                    if let stringItem = item as? String {
                        return stringItem == expectedValue
                    }
                    return String(describing: item) == expectedValue
                }
                writeLog("ValidationService: Key '\(key)', Array contains '\(expectedValue)', Result: \(result)", logLevel: .info)
                return result
            } else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'contains' requires array value", logLevel: .error)
                return false
            }
            
        case "range":
            // For numbers, expectedValue like "1-100" checks range
            guard let expectedValue = expectedValue, expectedValue.contains("-") else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires format 'min-max'", logLevel: .error)
                return false
            }

            let rangeParts = expectedValue.components(separatedBy: "-")
            guard rangeParts.count == 2,
                  let minValue = Double(rangeParts[0]),
                  let maxValue = Double(rangeParts[1]) else {
                writeLog("ValidationService: Key '\(key)', Invalid range format '\(expectedValue)'", logLevel: .error)
                return false
            }

            let actualNumber: Double?
            if let intVal = value as? Int {
                actualNumber = Double(intVal)
            } else if let doubleVal = value as? Double {
                actualNumber = doubleVal
            } else if let floatVal = value as? Float {
                actualNumber = Double(floatVal)
            } else if let nsNumber = value as? NSNumber {
                actualNumber = nsNumber.doubleValue
            } else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires numeric value, got: \(type(of: value))", logLevel: .error)
                return false
            }

            guard let number = actualNumber else {
                return false
            }

            let result = number >= minValue && number <= maxValue
            writeLog("ValidationService: Key '\(key)', Value \(number) in range \(minValue)-\(maxValue), Result: \(result)", logLevel: .info)
            return result

        case "withinseconds", "within_seconds", "recentseconds", "recent":
            // Check if date/timestamp is within X seconds of now
            // expectedValue = number of seconds (e.g., "300" for 5 minutes)
            guard let expectedValue = expectedValue, let maxSeconds = Double(expectedValue) else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'withinSeconds' requires numeric expectedValue (seconds)", logLevel: .error)
                return false
            }

            // Parse the value as a date
            let now = Date()
            var parsedDate: Date?

            // Handle native Date type from plist
            if let dateValue = value as? Date {
                parsedDate = dateValue
            }

            // Try Unix timestamp (Double seconds since 1970)
            if parsedDate == nil, let timestamp = value as? Double {
                parsedDate = Date(timeIntervalSince1970: timestamp)
            }
            if parsedDate == nil, let timestamp = value as? Int {
                parsedDate = Date(timeIntervalSince1970: Double(timestamp))
            }
            if parsedDate == nil, let nsNumber = value as? NSNumber {
                parsedDate = Date(timeIntervalSince1970: nsNumber.doubleValue)
            }

            // Try string date formats
            if parsedDate == nil, let stringValue = value as? String {
                // Try ISO8601 with fractional seconds
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsedDate = iso8601Formatter.date(from: stringValue)

                // Try ISO8601 without fractional seconds
                if parsedDate == nil {
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    parsedDate = iso8601Formatter.date(from: stringValue)
                }

                // Try common plist date formats
                if parsedDate == nil {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ssZ",
                        "yyyy-MM-dd HH:mm:ss Z",
                        "yyyy-MM-dd HH:mm:ss",
                        "MMM d, yyyy 'at' h:mm:ss a",
                        "MMM d, yyyy, h:mm:ss a"
                    ]

                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: stringValue) {
                            parsedDate = date
                            break
                        }
                    }
                }

                // Try parsing as Unix timestamp string
                if parsedDate == nil, let timestamp = Double(stringValue) {
                    parsedDate = Date(timeIntervalSince1970: timestamp)
                }
            }

            guard let date = parsedDate else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'withinSeconds' could not parse date from '\(value)'", logLevel: .error)
                return false
            }

            let secondsAgo = now.timeIntervalSince(date)
            let isWithin = secondsAgo >= 0 && secondsAgo <= maxSeconds
            writeLog("ValidationService: Key '\(key)', withinSeconds check - date=\(date), secondsAgo=\(secondsAgo), maxSeconds=\(maxSeconds), pass=\(isWithin)", logLevel: .debug)
            return isWithin

        default: // "equals" and any other unknown types
            // Default: exact string comparison (backward compatible)
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'equals' requires expectedValue", logLevel: .error)
                return false
            }
            
            let result: Bool
            if let stringValue = value as? String {
                result = stringValue == expectedValue
            } else if let boolValue = value as? Bool {
                result = String(boolValue) == expectedValue
            } else if let intValue = value as? Int {
                result = String(intValue) == expectedValue
            } else if let doubleValue = value as? Double {
                result = String(doubleValue) == expectedValue
            } else if let floatValue = value as? Float {
                result = String(floatValue) == expectedValue
            } else if let nsNumber = value as? NSNumber {
                result = nsNumber.stringValue == expectedValue
            } else {
                result = String(describing: value) == expectedValue
            }
            
            writeLog("ValidationService: Key '\(key)', Expected '\(expectedValue)', Actual '\(String(describing: value))', Result: \(result)", logLevel: .info)
            return result
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseSmartBoolean(_ value: Any) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            let lower = stringValue.lowercased()
            return lower == "true" || lower == "yes" || lower == "1"
        } else if let intValue = value as? Int {
            return intValue == 1
        } else if let doubleValue = value as? Double {
            return doubleValue == 1.0
        }
        return false
    }
    
    private func formatValueForDisplay(_ value: Any) -> String {
        // Handle NSNull specifically to avoid crashes
        if value is NSNull {
            return "null"
        }
        
        if let stringValue = value as? String {
            return stringValue
        } else if let boolValue = value as? Bool {
            return String(boolValue)
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let doubleValue = value as? Double {
            return String(doubleValue)
        } else if let arrayValue = value as? [Any] {
            return "[\(arrayValue.count) items]"
        } else if let dictValue = value as? [String: Any] {
            return "{\(dictValue.keys.count) keys}"
        } else if let floatValue = value as? Float {
            return String(floatValue)
        } else if let nsNumber = value as? NSNumber {
            return nsNumber.stringValue
        } else if let dateValue = value as? Date {
            // Format dates with ISO8601 including timezone for reliable parsing
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            return iso8601Formatter.string(from: dateValue)
        }

        // Safe fallback for any other types
        return String(describing: value)
    }
    
    private func checkNestedKey(_ keyPath: String, in dict: [String: Any], expectedValues: [String]?) -> Bool {
        let components = keyPath.split(separator: ".")
        var current: Any = dict
        
        for component in components {
            let componentStr = String(component)
            
            if component == "*" {
                // Handle wildcard - would need more complex logic
                return true
            }
            
            guard let currentDict = current as? [String: Any] else {
                return false // Current value is not a dictionary
            }
            
            guard let nextValue = currentDict[componentStr] else {
                return false // Key doesn't exist
            }
            
            current = nextValue
        }
        
        // Check if value matches expected
        if let expectedValues = expectedValues {
            if let stringValue = current as? String {
                return expectedValues.contains(stringValue)
            } else if let intValue = current as? Int {
                return expectedValues.contains(String(intValue))
            } else if let boolValue = current as? Bool {
                return expectedValues.contains(String(boolValue))
            } else {
                // Try string representation as fallback
                return expectedValues.contains(String(describing: current))
            }
        }
        
        return true
    }
}
