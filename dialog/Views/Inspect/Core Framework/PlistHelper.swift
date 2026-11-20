//
//  PlistHelper.swift
//  Dialog
//
//  Plist read/write helpers and the plist item status poller used by Inspect presets.
//

import Foundation

/// Helpers for reading and writing plist files.
enum PlistHelper {

    // MARK: - Reading

    /// Reads a plist file; `~` is expanded. nil if missing or invalid.
    static func readPlist(at path: String) -> NSDictionary? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }
        return NSDictionary(contentsOfFile: expandedPath)
    }

    /// Reads a plist file as a dictionary; `~` is expanded. nil if missing or invalid.
    static func readPlistAsDict(at path: String) -> [String: Any]? {
        return readPlist(at: path) as? [String: Any]
    }

    // MARK: - Writing

    /// Writes a dictionary to a plist file, creating the parent directory. Returns success.
    @discardableResult
    static func writePlist(_ dict: NSDictionary, to path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath

        let directory = (expandedPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dict.write(toFile: expandedPath, atomically: true)
    }

    /// Writes a Swift dictionary to a plist file. Returns success.
    @discardableResult
    static func writePlist(_ dict: [String: Any], to path: String) -> Bool {
        return writePlist(dict as NSDictionary, to: path)
    }

    // MARK: - File Operations

    /// Whether a plist file exists.
    static func plistExists(at path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    // MARK: - Trigger Files

    /// Creates an empty trigger file.
    static func createTriggerFile(at path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        try? "".write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }

    /// Creates a trigger file with the given content.
    static func createTriggerFile(at path: String, content: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        try? content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }
}
