//
//  PreferencesModule.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/01/2026
//
//  User preferences collection and persistence module for Inspect presets
//
//  This module provides:
//  - Preference collection from intro steps (pickers, forms)
//  - Plist output for MDM/osquery integration
//  - UserDefaults integration for state persistence
//
//  Use Case Flow:
//  Intro Step (picker/form) → PreferencesModule → Plist file → osquery reads → Device labeled
//
//  Used by: Preset5 (and future presets with preference collection)
//

import Foundation
import Combine

// MARK: - Preferences Output Configuration

/// Configuration for preferences output destination
struct PreferencesOutputConfig: Codable {
    /// Path to write the preferences plist file
    /// Example: "/Library/Preferences/com.company.enrollment.plist"
    let plistPath: String

    /// Whether to write preferences when each step completes
    let writeOnStepComplete: Bool?

    /// Whether to write preferences when dialog exits
    let writeOnDialogExit: Bool?

    /// Whether to merge with existing plist (true) or overwrite (false)
    let mergeWithExisting: Bool?

    /// Custom keys to always include (with hardcoded values)
    let staticValues: [String: AnyCodable]?

    init(
        plistPath: String,
        writeOnStepComplete: Bool? = true,
        writeOnDialogExit: Bool? = true,
        mergeWithExisting: Bool? = true,
        staticValues: [String: AnyCodable]? = nil
    ) {
        self.plistPath = plistPath
        self.writeOnStepComplete = writeOnStepComplete
        self.writeOnDialogExit = writeOnDialogExit
        self.mergeWithExisting = mergeWithExisting
        self.staticValues = staticValues
    }
}

// MARK: - AnyCodable Helper

/// Type-erased codable wrapper for heterogeneous dictionary values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Preferences Service

/// Service for collecting and persisting user preferences
///
/// This service manages preference collection during onboarding flows,
/// writing to plist files that can be read by osquery for device labeling
/// and MDM profile assignment.
///
/// ## Usage Example
/// ```swift
/// let preferencesService = PreferencesService(config: preferencesOutputConfig)
///
/// // In intro step picker handler
/// preferencesService.setValue("developer", forKey: "UserRole")
///
/// // In form input handler
/// preferencesService.setValue(300, forKey: "LockScreenInterval")
/// preferencesService.setValue(true, forKey: "RequirePasswordOnWake")
///
/// // Write to plist (automatic or manual)
/// preferencesService.writeToPlist()
/// ```
///
/// ## osquery Integration
/// ```sql
/// SELECT key, value FROM plist
/// WHERE path = '/Library/Preferences/com.company.enrollment.plist'
/// AND key = 'UserRole';
/// ```
class PreferencesService: ObservableObject {

    // MARK: - Published Properties

    /// All collected preferences
    @Published public private(set) var collectedPreferences: [String: Any] = [:]

    /// Whether preferences have been modified since last write
    @Published public private(set) var isDirty: Bool = false

    /// Last write timestamp
    @Published public private(set) var lastWriteDate: Date?

    /// Last error message (if any)
    @Published public private(set) var lastError: String?

    // MARK: - Private Properties

    private let config: PreferencesOutputConfig?
    private let userDefaultsSuite: String?
    private var userDefaults: UserDefaults?

    // MARK: - Initialization

    /// Initialize with optional output configuration
    /// - Parameters:
    ///   - config: Plist output configuration
    ///   - userDefaultsSuite: Optional UserDefaults suite name for state persistence
    init(config: PreferencesOutputConfig? = nil, userDefaultsSuite: String? = nil) {
        self.config = config
        self.userDefaultsSuite = userDefaultsSuite

        if let suite = userDefaultsSuite {
            self.userDefaults = UserDefaults(suiteName: suite)
        }

        // Load any previously saved preferences
        loadFromUserDefaults()
    }

    // MARK: - Public API

    /// Set a preference value
    /// - Parameters:
    ///   - value: The value to store (String, Int, Double, Bool, Array, Dictionary)
    ///   - key: The preference key
    func setValue(_ value: Any, forKey key: String) {
        collectedPreferences[key] = value
        isDirty = true

        // Save to UserDefaults immediately for state persistence
        saveToUserDefaults()

        writeLog("PreferencesService: Set '\(key)' = '\(value)'", logLevel: .debug)

        // Auto-write if configured
        if config?.writeOnStepComplete == true {
            writeToPlist()
        }
    }

    /// Get a preference value
    /// - Parameter key: The preference key
    /// - Returns: The stored value, or nil if not found
    func getValue(forKey key: String) -> Any? {
        return collectedPreferences[key]
    }

    /// Get a typed preference value
    /// - Parameters:
    ///   - key: The preference key
    ///   - type: The expected type
    /// - Returns: The stored value cast to the specified type, or nil
    func getValue<T>(forKey key: String, as type: T.Type) -> T? {
        return collectedPreferences[key] as? T
    }

    /// Remove a preference
    /// - Parameter key: The preference key to remove
    func removeValue(forKey key: String) {
        collectedPreferences.removeValue(forKey: key)
        isDirty = true
        saveToUserDefaults()
    }

    /// Clear all preferences
    func clearAll() {
        collectedPreferences.removeAll()
        isDirty = true
        saveToUserDefaults()
        writeLog("PreferencesService: Cleared all preferences", logLevel: .info)
    }

    /// Write collected preferences to plist file
    /// - Returns: True if write succeeded
    @discardableResult
    func writeToPlist() -> Bool {
        guard let config = config else {
            writeLog("PreferencesService: No plist config provided, skipping write", logLevel: .debug)
            return false
        }

        let path = (config.plistPath as NSString).expandingTildeInPath

        // Prepare output dictionary
        var outputDict: [String: Any] = [:]

        // Merge with existing if configured
        if config.mergeWithExisting == true,
           let existingDict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            outputDict = existingDict
        }

        // Add collected preferences
        for (key, value) in collectedPreferences {
            outputDict[key] = value
        }

        // Add static values
        if let staticValues = config.staticValues {
            for (key, codable) in staticValues {
                outputDict[key] = codable.value
            }
        }

        // Add timestamp
        outputDict["EnrollmentTimestamp"] = Date()

        // Write to file
        let dict = outputDict as NSDictionary

        do {
            // Create parent directory if needed
            let parentDir = (path as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: parentDir) {
                try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            }

            // Write plist
            let success = dict.write(toFile: path, atomically: true)

            if success {
                isDirty = false
                lastWriteDate = Date()
                lastError = nil
                writeLog("PreferencesService: Wrote preferences to \(path)", logLevel: .info)
                return true
            } else {
                lastError = "Failed to write plist file"
                writeLog("PreferencesService: Failed to write to \(path)", logLevel: .error)
                return false
            }
        } catch {
            lastError = error.localizedDescription
            writeLog("PreferencesService: Error writing plist: \(error)", logLevel: .error)
            return false
        }
    }

    /// Read preferences from plist file
    /// - Returns: Dictionary of preferences, or nil if file doesn't exist
    func readFromPlist() -> [String: Any]? {
        guard let config = config else { return nil }

        let path = (config.plistPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: path),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }

        return dict
    }

    /// Write preferences to plist if dirty and configured for exit write
    func writeOnExitIfNeeded() {
        if isDirty && config?.writeOnDialogExit == true {
            writeToPlist()
        }
    }

    // MARK: - Picker/Form Integration

    /// Handle grid picker selection
    /// - Parameters:
    ///   - selectionKey: The selection key (for storing in local state)
    ///   - preferenceKey: The preference key (for plist output)
    ///   - selectedValue: The selected value
    func handleGridSelection(selectionKey: String, preferenceKey: String?, selectedValue: String) {
        if let prefKey = preferenceKey {
            setValue(selectedValue, forKey: prefKey)
        }
        writeLog("PreferencesService: Grid selection '\(selectionKey)' = '\(selectedValue)', preferenceKey: \(preferenceKey ?? "none")", logLevel: .debug)
    }

    /// Handle form input change
    /// - Parameters:
    ///   - inputKey: The form input key
    ///   - preferenceKey: The preference key (for plist output)
    ///   - value: The input value
    func handleFormInput(inputKey: String, preferenceKey: String?, value: Any) {
        if let prefKey = preferenceKey {
            setValue(value, forKey: prefKey)
        }
        writeLog("PreferencesService: Form input '\(inputKey)' = '\(value)', preferenceKey: \(preferenceKey ?? "none")", logLevel: .debug)
    }

    // MARK: - UserDefaults Persistence

    private func saveToUserDefaults() {
        guard let defaults = userDefaults else { return }

        // Convert preferences to a format that can be stored in UserDefaults
        var storable: [String: Any] = [:]
        for (key, value) in collectedPreferences {
            if let data = try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0) {
                storable[key] = data
            }
        }

        defaults.set(storable, forKey: "collectedPreferences")
        defaults.synchronize()
    }

    private func loadFromUserDefaults() {
        guard let defaults = userDefaults,
              let storable = defaults.dictionary(forKey: "collectedPreferences") else { return }

        for (key, value) in storable {
            if let data = value as? Data,
               let decoded = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                collectedPreferences[key] = decoded
            }
        }
    }

    // MARK: - Deinitialization

    deinit {
        // Final write on exit if configured
        writeOnExitIfNeeded()
    }
}

// MARK: - Preference Input Types

/// Types of preference inputs supported in forms
enum PreferenceInputType: String, Codable {
    case dropdown
    case toggle
    case radio
    case checkbox
    case slider
    case textfield
}

// MARK: - Preference Input Configuration

/// Configuration for a form input that writes to preferences
struct PreferenceInputConfig: Codable, Identifiable {
    var id: String { key }

    /// Form input key (for local state)
    let key: String

    /// Preference key (for plist output) - if nil, won't write to preferences
    let preferenceKey: String?

    /// Input type
    let type: PreferenceInputType

    /// Display label
    let label: String

    /// Default value
    let defaultValue: AnyCodable?

    /// Options for dropdown/radio (display labels)
    let options: [String]?

    /// Values for dropdown/radio (actual values to store)
    let values: [AnyCodable]?

    /// Minimum value for slider
    let minValue: Double?

    /// Maximum value for slider
    let maxValue: Double?

    /// Step value for slider
    let step: Double?

    /// Placeholder text for textfield
    let placeholder: String?

    /// Whether this input is required
    let required: Bool?

    init(
        key: String,
        preferenceKey: String? = nil,
        type: PreferenceInputType,
        label: String,
        defaultValue: AnyCodable? = nil,
        options: [String]? = nil,
        values: [AnyCodable]? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        step: Double? = nil,
        placeholder: String? = nil,
        required: Bool? = nil
    ) {
        self.key = key
        self.preferenceKey = preferenceKey
        self.type = type
        self.label = label
        self.defaultValue = defaultValue
        self.options = options
        self.values = values
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.placeholder = placeholder
        self.required = required
    }
}

// MARK: - Preference Grid Item Configuration

/// Configuration for a grid item that writes to preferences
struct PreferenceGridItemConfig: Codable, Identifiable {
    var id: String { value }

    /// Value to store when selected
    let value: String

    /// Display title
    let title: String

    /// Optional subtitle
    let subtitle: String?

    /// SF Symbol name
    let sfSymbol: String?

    /// Image path
    let imagePath: String?

    init(
        value: String,
        title: String,
        subtitle: String? = nil,
        sfSymbol: String? = nil,
        imagePath: String? = nil
    ) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.sfSymbol = sfSymbol
        self.imagePath = imagePath
    }
}

// MARK: - Preferences Helper Extensions

// Note: gridPreferenceKey and preferenceKey are now defined directly
// in InspectConfig.IntroStep and InspectConfig.GuidanceContent respectively
