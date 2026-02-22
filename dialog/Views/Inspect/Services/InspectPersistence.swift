//
//  InspectPersistence.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 09/10/2025
//
//  Generic reusable persistence service for all Inspect presets
//  Non-blocking, type-safe, and flexible for different state structures
//

import Foundation

// MARK: - Protocol

/// Protocol that all persistable preset states must conform to
protocol InspectPersistableState: Codable {
    var timestamp: Date { get }
}

// MARK: - Generic Persistence Service

/// Generic persistence service for Inspect mode presets
/// - Non-blocking: Uses background queue for all I/O operations
/// - Type-safe: Enforces Codable conformance at compile time
/// - Flexible: Each preset defines its own state structure
/// - Customizable: Supports custom filenames via parameter or environment variable
///
/// **Basic Usage:**
/// ```swift
/// struct MyPresetState: InspectPersistableState {
///     let completedItems: Set<String>
///     let currentIndex: Int
///     let timestamp: Date
/// }
///
/// // Default filename: preset3_state.plist
/// let persistence = InspectPersistence<MyPresetState>(presetName: "preset3")
/// persistence.saveState(myState)
/// if let state = persistence.loadState() { ... }
/// ```
///
/// **Custom Filename:**
/// ```swift
/// // Custom filename for multi-instance support
/// let persistence = InspectPersistence<MyPresetState>(
///     presetName: "preset3",
///     customFileName: "onboarding_user1.plist"
/// )
/// ```
///
/// **Environment Variable:**
/// ```bash
/// export DIALOG_PERSIST_FILENAME="custom_state.plist"
/// export DIALOG_PERSIST_PATH="/var/lib/dialog"
/// # Results in: /var/lib/dialog/custom_state.plist
/// ```
class InspectPersistence<T: InspectPersistableState> {

    // MARK: - Properties

    private let presetName: String
    private let stateFileName: String
    private let queue: DispatchQueue

    // MARK: - Initialization

    /// Initialize persistence for a specific preset
    /// - Parameters:
    ///   - presetName: Unique preset identifier (e.g., "preset5", "preset3")
    ///   - customFileName: Optional custom filename (overrides default naming)
    ///
    /// **Filename Resolution Priority:**
    /// 1. `customFileName` parameter (if provided)
    /// 2. `DIALOG_PERSIST_FILENAME` environment variable (if set)
    /// 3. Default pattern: `{presetName}_state.plist`
    ///
    /// **Examples:**
    /// ```swift
    /// // Default: preset6_state.plist
    /// let p1 = InspectPersistence<State>(presetName: "preset6")
    ///
    /// // Custom: onboarding.plist
    /// let p2 = InspectPersistence<State>(presetName: "preset6", customFileName: "onboarding.plist")
    ///
    /// // Multi-instance: preset6_user1.plist
    /// let p3 = InspectPersistence<State>(presetName: "preset6", customFileName: "preset6_user1.plist")
    /// ```
    init(presetName: String, customFileName: String? = nil) {
        self.presetName = presetName
        
        // Filename resolution priority: parameter > env var > default
        if let customFileName = customFileName {
            self.stateFileName = customFileName
            writeLog("InspectPersistence<\(T.self)>: Using custom filename '\(customFileName)'", logLevel: .debug)
        } else if let envFileName = ProcessInfo.processInfo.environment["DIALOG_PERSIST_FILENAME"] {
            self.stateFileName = envFileName
            writeLog("InspectPersistence<\(T.self)>: Using filename from DIALOG_PERSIST_FILENAME: '\(envFileName)'", logLevel: .info)
        } else {
            self.stateFileName = "\(presetName)_state.plist"
            writeLog("InspectPersistence<\(T.self)>: Using default filename '\(self.stateFileName)'", logLevel: .debug)
        }
        
        self.queue = DispatchQueue(label: "dialog.inspect.\(presetName).persistence", qos: .background)
        writeLog("InspectPersistence<\(T.self)>: Initialized for '\(presetName)' with file '\(self.stateFileName)'", logLevel: .debug)
    }

    // MARK: - File Location Strategy

    /// Smart file location strategy with fallback chain:
    /// 1. DIALOG_PERSIST_PATH environment variable (enterprise deployments)
    /// 2. Working directory .dialog subdirectory (portable/project-specific)
    /// 3. User's Application Support directory (standard macOS location)
    /// 4. Temp directory (last resort fallback)
    ///
    /// **Filename Customization:**
    /// - Custom filename via `init` parameter takes highest priority
    /// - `DIALOG_PERSIST_FILENAME` environment variable (if no custom parameter)
    /// - Default: `{presetName}_state.plist`
    ///
    /// **Examples:**
    /// ```
    /// Default:
    ///   ~/Library/Application Support/Dialog/preset6_state.plist
    ///
    /// Custom via parameter:
    ///   ~/Library/Application Support/Dialog/onboarding.plist
    ///
    /// Custom via environment:
    ///   export DIALOG_PERSIST_PATH="/opt/dialog"
    ///   export DIALOG_PERSIST_FILENAME="deployment.plist"
    ///   → /opt/dialog/deployment.plist
    /// ```
    private var stateFileURL: URL? {
        // Option 1: Environment variable override
        if let customPath = ProcessInfo.processInfo.environment["DIALOG_PERSIST_PATH"] {
            let url = URL(fileURLWithPath: customPath).appendingPathComponent(stateFileName)
            writeLog("InspectPersistence: Using custom path from DIALOG_PERSIST_PATH: \(url.path)", logLevel: .debug)
            return url
        }

        // Option 2: Working directory .dialog subdirectory
        if let workingDir = ProcessInfo.processInfo.environment["PWD"] {
            let workingURL = URL(fileURLWithPath: workingDir)
            let dialogDir = workingURL.appendingPathComponent(".dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("InspectPersistence: Using working directory: \(url.path)", logLevel: .debug)
                return url
            }
        }

        // Option 3: User's Application Support directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dialogDir = appSupport.appendingPathComponent("Dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("InspectPersistence: Using Application Support: \(url.path)", logLevel: .debug)
                return url
            }
        }

        // Option 4: Temp directory as last resort
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dialog", isDirectory: true)
            .appendingPathComponent(stateFileName)
        writeLog("InspectPersistence: Using temp directory: \(tempURL.path)", logLevel: .info)
        return tempURL
    }

    /// Ensures directory exists and is writable
    private func ensureDirectoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        // Check if directory already exists
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }

        // Try to create directory
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            // Verify we can write to it with a test file
            let testFile = url.appendingPathComponent(".write_test")
            if FileManager.default.createFile(atPath: testFile.path, contents: nil, attributes: nil) {
                try? FileManager.default.removeItem(at: testFile)
                return true
            }
        } catch {
            writeLog("InspectPersistence: Cannot create/write to directory at \(url.path): \(error)", logLevel: .info)
        }

        return false
    }

    // MARK: - Save State (Non-blocking)

    /// Save state asynchronously on background queue
    /// - Parameter state: The state to persist
    func saveState(_ state: T) {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.stateFileURL else {
                writeLog("InspectPersistence: Cannot determine save location for \(self?.presetName ?? "unknown")", logLevel: .error)
                return
            }

            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(state)
                try data.write(to: url, options: .atomic)
                writeLog("InspectPersistence: State saved successfully to \(url.path)", logLevel: .debug)
            } catch {
                writeLog("InspectPersistence: Failed to save state - \(error.localizedDescription)", logLevel: .error)
            }
        }
    }

    // MARK: - Load State (Synchronous)

    /// Load persisted state synchronously
    /// - Returns: The loaded state, or nil if no state exists or loading fails
    func loadState() -> T? {
        guard let url = stateFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            writeLog("InspectPersistence: No persisted state found for \(presetName)", logLevel: .debug)
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let state = try decoder.decode(T.self, from: data)

            writeLog("InspectPersistence: State loaded from \(state.timestamp)", logLevel: .info)
            return state
        } catch {
            writeLog("InspectPersistence: Failed to load state - \(error.localizedDescription)", logLevel: .error)

            // Remove corrupt file to prevent repeated errors
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Clear State (Non-blocking)

    /// Clear persisted state asynchronously
    func clearState() {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.stateFileURL else { return }

            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    writeLog("InspectPersistence: State cleared for \(self.presetName)", logLevel: .info)
                }
            } catch {
                writeLog("InspectPersistence: Failed to clear state - \(error.localizedDescription)", logLevel: .error)
            }
        }
    }

    // MARK: - Utilities

    /// Check if state is stale (older than specified hours)
    /// - Parameters:
    ///   - state: The state to check
    ///   - hours: Number of hours to consider stale (default: 24)
    /// - Returns: True if state is older than specified hours
    func isStateStale(_ state: T, hours: Double = 24) -> Bool {
        let hoursSinceLastSave = Date().timeIntervalSince(state.timestamp) / 3600
        let isStale = hoursSinceLastSave > hours

        if isStale {
            writeLog("InspectPersistence: State is \(Int(hoursSinceLastSave)) hours old (stale)", logLevel: .info)
        }

        return isStale
    }

    /// Get the current persistence file path (for debugging)
    var persistenceFilePath: String? {
        return stateFileURL?.path
    }
}

// MARK: - Example State Structures & Usage

/// Example state structure for reference
/// Presets should define their own states conforming to InspectPersistableState
///
/// **Example 1: Basic Preset State**
/// ```swift
/// struct PresetState: InspectPersistableState {
///     let completedSteps: Set<String>
///     let currentPage: Int
///     let currentStep: Int
///     let timestamp: Date
/// }
///
/// // Default filename: preset5_state.plist
/// let persistence = InspectPersistence<PresetState>(presetName: "preset5")
/// ```
///
/// **Example 2: Custom Filename for Multi-Instance Support**
/// ```swift
/// // Support multiple users on same Mac with isolated state
/// let username = ProcessInfo.processInfo.environment["USER"] ?? "default"
/// let persistence = InspectPersistence<Preset6State>(
///     presetName: "preset6",
///     customFileName: "preset6_\(username).plist"
/// )
/// // Results in: preset6_johndoe.plist
/// ```
///
/// **Example 3: Corporate Naming Standards**
/// ```swift
/// // Use descriptive filenames matching enterprise requirements
/// let persistence = InspectPersistence<OnboardingState>(
///     presetName: "onboarding",
///     customFileName: "corporate_onboarding_progress.plist"
/// )
/// ```
///
/// **Example 4: Environment Variable Override**
/// ```bash
/// # Set custom filename via environment variable
/// export DIALOG_PERSIST_FILENAME="deployment_state.plist"
/// export DIALOG_PERSIST_PATH="/var/lib/dialog/state"
///
/// # Results in: /var/lib/dialog/state/deployment_state.plist
/// ./dialog --inspect-mode
/// ```
///
/// **Example 5: Testing with Isolated State**
/// ```swift
/// // Use unique filenames for unit tests to avoid conflicts
/// let testPersistence = InspectPersistence<Preset3State>(
///     presetName: "preset3",
///     customFileName: "preset3_test_\(UUID().uuidString).plist"
/// )
/// // Results in: preset3_test_A1B2C3D4-E5F6-7890-ABCD-EF1234567890.plist
/// ```
