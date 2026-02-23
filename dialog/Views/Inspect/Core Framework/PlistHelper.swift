//
//  PlistHelper.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Reusable plist read/write utilities for the Inspect framework
//  Consolidates repeated FileManager + NSDictionary patterns
//

import Foundation

/// Helper utilities for reading and writing plist files
enum PlistHelper {

    // MARK: - Reading

    /// Read a plist file and return as NSDictionary
    /// - Parameter path: The file path (can contain ~ for home directory)
    /// - Returns: NSDictionary if file exists and is valid, nil otherwise
    static func readPlist(at path: String) -> NSDictionary? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }
        return NSDictionary(contentsOfFile: expandedPath)
    }

    /// Read a plist file and return as typed dictionary
    /// - Parameter path: The file path (can contain ~ for home directory)
    /// - Returns: Dictionary if file exists and is valid, nil otherwise
    static func readPlistAsDict(at path: String) -> [String: Any]? {
        return readPlist(at: path) as? [String: Any]
    }

    /// Read a specific key from a plist file
    /// - Parameters:
    ///   - key: The key to read
    ///   - path: The plist file path
    /// - Returns: The value for the key, or nil if not found
    static func readValue<T>(forKey key: String, from path: String) -> T? {
        guard let dict = readPlist(at: path) else {
            return nil
        }
        return dict[key] as? T
    }

    // MARK: - Writing

    /// Write a dictionary to a plist file
    /// - Parameters:
    ///   - dict: The dictionary to write
    ///   - path: The destination file path
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func writePlist(_ dict: NSDictionary, to path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Ensure parent directory exists
        let directory = (expandedPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dict.write(toFile: expandedPath, atomically: true)
    }

    /// Write a Swift dictionary to a plist file
    /// - Parameters:
    ///   - dict: The dictionary to write
    ///   - path: The destination file path
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func writePlist(_ dict: [String: Any], to path: String) -> Bool {
        return writePlist(dict as NSDictionary, to: path)
    }

    /// Update specific keys in a plist file (merge with existing)
    /// - Parameters:
    ///   - updates: Dictionary of key-value pairs to update
    ///   - path: The plist file path
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func updatePlist(_ updates: [String: Any], at path: String) -> Bool {
        var existing = readPlistAsDict(at: path) ?? [:]
        for (key, value) in updates {
            existing[key] = value
        }
        return writePlist(existing, to: path)
    }

    // MARK: - File Operations

    /// Check if a plist file exists
    /// - Parameter path: The file path
    /// - Returns: true if file exists
    static func plistExists(at path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    /// Delete a plist file
    /// - Parameter path: The file path
    /// - Returns: true if deleted or didn't exist
    @discardableResult
    static func deletePlist(at path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return true // Already doesn't exist
        }
        do {
            try FileManager.default.removeItem(atPath: expandedPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Trigger Files

    /// Create an empty trigger file
    /// - Parameter path: The file path
    static func createTriggerFile(at path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        try? "".write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }

    /// Create a trigger file with content
    /// - Parameters:
    ///   - path: The file path
    ///   - content: The content to write
    static func createTriggerFile(at path: String, content: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        try? content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }
}
