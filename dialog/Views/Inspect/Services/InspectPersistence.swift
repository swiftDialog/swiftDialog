//
//  InspectPersistence.swift
//  dialog
//
//  Plist persistence of a preset's resumable state; writes happen off the caller's thread.
//

import Foundation

// MARK: - Protocol

/// A persistable preset state. `Sendable` because it is written on the service's own serial queue.
protocol InspectPersistableState: Codable, Sendable {
    var timestamp: Date { get }
}

// MARK: - Generic Persistence Service

/// Saves and loads one preset's state as a plist. Saves and clears run on a background queue; loads
/// are synchronous. The file name and directory can be set by `DIALOG_PERSIST_FILENAME` and
/// `DIALOG_PERSIST_PATH`. All stored properties are immutable, hence `Sendable`.
final class InspectPersistence<T: InspectPersistableState>: Sendable {

    // MARK: - Properties

    private let presetName: String
    private let stateFileName: String
    private let queue: DispatchQueue

    // MARK: - Initialization

    /// File name: `customFileName`, else `DIALOG_PERSIST_FILENAME`, else `{presetName}_state.plist`.
    init(presetName: String, customFileName: String? = nil) {
        self.presetName = presetName

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

    // MARK: - File Location

    /// Directory, first writable wins: `DIALOG_PERSIST_PATH`, `$PWD/.dialog`,
    /// `~/Library/Application Support/Dialog`, then the temporary directory.
    private var stateFileURL: URL? {
        if let customPath = ProcessInfo.processInfo.environment["DIALOG_PERSIST_PATH"] {
            let url = URL(fileURLWithPath: customPath).appendingPathComponent(stateFileName)
            writeLog("InspectPersistence: Using custom path from DIALOG_PERSIST_PATH: \(url.path)", logLevel: .debug)
            return url
        }

        if let workingDir = ProcessInfo.processInfo.environment["PWD"] {
            let workingURL = URL(fileURLWithPath: workingDir)
            let dialogDir = workingURL.appendingPathComponent(".dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("InspectPersistence: Using working directory: \(url.path)", logLevel: .debug)
                return url
            }
        }

        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dialogDir = appSupport.appendingPathComponent("Dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("InspectPersistence: Using Application Support: \(url.path)", logLevel: .debug)
                return url
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dialog", isDirectory: true)
            .appendingPathComponent(stateFileName)
        writeLog("InspectPersistence: Using temp directory: \(tempURL.path)", logLevel: .info)
        return tempURL
    }

    /// Whether the directory exists, or could be created and written to.
    private func ensureDirectoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

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

    // MARK: - Save State

    /// Writes the state on the background queue.
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

    // MARK: - Load State

    /// Reads the state synchronously; nil when there is none. A file that fails to decode is deleted.
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

            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Clear State

    /// Deletes the state file on the background queue.
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

    var persistenceFilePath: String? {
        return stateFileURL?.path
    }
}
