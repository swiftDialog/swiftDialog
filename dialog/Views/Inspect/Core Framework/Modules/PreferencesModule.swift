//
//  PreferencesModule.swift
//  dialog
//
//  Collects preferences from intro steps (pickers, forms), keeps them in UserDefaults across
//  runs and writes them to a plist that MDM or osquery can read. Used by preset 5.
//

import Foundation
import Combine

// MARK: - Preferences Output Configuration

/// Where and when collected preferences are written.
/// The three flags default to true when absent, as the schema documents; only an explicit false turns one off.
struct PreferencesOutputConfig: Codable {
    /// Plist path, e.g. "/Library/Preferences/com.example.enrollment.plist".
    let plistPath: String

    /// Write after every `setValue` (default true).
    let writeOnStepComplete: Bool?

    /// Write on exit if anything changed (default true).
    let writeOnDialogExit: Bool?

    /// Merge into an existing plist (true) or overwrite it (false).
    let mergeWithExisting: Bool?

    /// Keys always written with fixed values.
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

/// Type-erased Codable wrapper for heterogeneous dictionary values.
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

/// Collects user preferences and writes them to the configured plist; the plist also gets an
/// `EnrollmentTimestamp` key on every write.
class PreferencesService: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var collectedPreferences: [String: Any] = [:]

    /// Modified since the last write.
    @Published public private(set) var isDirty: Bool = false

    @Published public private(set) var lastWriteDate: Date?

    @Published public private(set) var lastError: String?

    // MARK: - Private Properties

    private let config: PreferencesOutputConfig?
    private let userDefaultsSuite: String?
    private var userDefaults: UserDefaults?

    // MARK: - Initialization

    /// Restores previously saved preferences from `userDefaultsSuite` when one is given.
    init(config: PreferencesOutputConfig? = nil, userDefaultsSuite: String? = nil) {
        self.config = config
        self.userDefaultsSuite = userDefaultsSuite

        if let suite = userDefaultsSuite {
            self.userDefaults = UserDefaults(suiteName: suite)
        }

        loadFromUserDefaults()
    }

    // MARK: - Public API

    /// Stores a plist-compatible value (String, Int, Double, Bool, Array, Dictionary) and
    /// writes the plist unless `writeOnStepComplete` is false.
    func setValue(_ value: Any, forKey key: String) {
        collectedPreferences[key] = value
        isDirty = true

        saveToUserDefaults()

        writeLog("PreferencesService: Set '\(key)' = '\(value)'", logLevel: .debug)

        if config?.writeOnStepComplete != false {
            writeToPlist()
        }
    }

    func getValue(forKey key: String) -> Any? {
        return collectedPreferences[key]
    }

    func getValue<T>(forKey key: String, as type: T.Type) -> T? {
        return collectedPreferences[key] as? T
    }

    func removeValue(forKey key: String) {
        collectedPreferences.removeValue(forKey: key)
        isDirty = true
        saveToUserDefaults()
    }

    /// Writes collected preferences, static values and `EnrollmentTimestamp` to the configured plist.
    @discardableResult
    func writeToPlist() -> Bool {
        guard let config = config else {
            writeLog("PreferencesService: No plist config provided, skipping write", logLevel: .debug)
            return false
        }

        let path = (config.plistPath as NSString).expandingTildeInPath

        var outputDict: [String: Any] = [:]

        if config.mergeWithExisting != false,
           let existingDict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            outputDict = existingDict
        }

        for (key, value) in collectedPreferences {
            outputDict[key] = value
        }

        if let staticValues = config.staticValues {
            for (key, codable) in staticValues {
                outputDict[key] = codable.value
            }
        }

        outputDict["EnrollmentTimestamp"] = Date()

        let dict = outputDict as NSDictionary

        do {
            let parentDir = (path as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: parentDir) {
                try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            }

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

    /// Writes the plist if dirty, unless `writeOnDialogExit` is false.
    func writeOnExitIfNeeded() {
        if isDirty && config?.writeOnDialogExit != false {
            writeToPlist()
        }
    }

    // MARK: - UserDefaults Persistence

    private func saveToUserDefaults() {
        guard let defaults = userDefaults else { return }

        // Values are stored as binary plist Data so any plist type survives UserDefaults.
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
        writeOnExitIfNeeded()
    }
}

// Preference keys live on the config types: `gridPreferenceKey` on InspectConfig.IntroStep,
// `preferenceKey` on its wallpaper, option and dock payloads.
