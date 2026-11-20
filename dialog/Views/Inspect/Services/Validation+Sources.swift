//
//  Validation+Sources.swift
//  dialog
//
//  Validation extension: path resolution (relative, tilde, glob) and reading values from plists,
//  UserDefaults domains and JSON files.
//

import Foundation

extension Validation {
    // MARK: - Glob Pattern Resolution

    /// Joins a relative path to `basePath`, expands `~`, and resolves a `*`/`?` glob in the last component
    /// to the first match; without a match the expanded path is returned.
    func resolvePlistPath(_ path: String, basePath: String? = nil) -> String {
        var workingPath = path
        if !path.hasPrefix("/") && !path.hasPrefix("~"), let basePath = basePath {
            let combined = (basePath as NSString).appendingPathComponent(path)
            let normalizedCombined = (combined as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: normalizedCombined) {
                writeLog("Validation: Resolved relative path '\(path)' with basePath → '\(normalizedCombined)'", logLevel: .info)
                return normalizedCombined
            }
            workingPath = normalizedCombined
        }

        let expandedPath = (workingPath as NSString).expandingTildeInPath

        guard expandedPath.contains("*") || expandedPath.contains("?") else {
            return expandedPath
        }

        let directory = (expandedPath as NSString).deletingLastPathComponent
        let pattern = (expandedPath as NSString).lastPathComponent

        guard FileManager.default.fileExists(atPath: directory) else {
            writeLog("Validation: Glob directory does not exist: \(directory)", logLevel: .debug)
            return expandedPath
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            writeLog("Validation: Cannot read directory for glob: \(directory)", logLevel: .debug)
            return expandedPath
        }

        if let matchedFile = contents.first(where: { filename in
            fnmatch(pattern, filename, 0) == 0
        }) {
            let resolvedPath = "\(directory)/\(matchedFile)"
            writeLog("Validation: Resolved glob '\(expandedPath)' → '\(resolvedPath)'", logLevel: .info)
            return resolvedPath
        }

        writeLog("Validation: No files match glob pattern: \(expandedPath)", logLevel: .debug)
        return expandedPath
    }

    /// The display string of a plist value; `key` may be dotted for nested keys.
    func getPlistValue(at path: String, key: String, basePath: String? = nil) -> String? {
        let resolvedPath = resolvePlistPath(path, basePath: basePath)
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        // An exact key wins before the dotted walk: plists key by bundle identifier ("com.apple.x").
        if let direct = plist[key], !(direct is NSNull) {
            return formatValueForDisplay(direct)
        }

        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        for keyPart in keyParts {
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

    func getPlistValue(path: String, key: String, basePath: String? = nil) -> String? {
        return getPlistValue(at: path, key: key, basePath: basePath)
    }

    // MARK: - UserDefaults Support

    /// The UserDefaults domain a plist path names (its filename without ".plist"), or nil.
    func extractDomainFromPath(_ path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        let filename = (expanded as NSString).lastPathComponent

        if filename == ".GlobalPreferences.plist" {
            return ".GlobalPreferences"
        }

        if filename.hasSuffix(".plist") {
            let domain = filename.replacingOccurrences(of: ".plist", with: "")
            return domain
        }

        return nil
    }

    /// The display string of a value in a UserDefaults domain; `key` may be dotted below the root key.
    func getUserDefaultsValue(domain: String, key: String) -> String? {
        let defaults: UserDefaults?
        if domain == ".GlobalPreferences" || domain == "NSGlobalDomain" {
            defaults = UserDefaults.standard
        } else {
            defaults = UserDefaults(suiteName: domain)
        }

        guard let defaults = defaults else { return nil }

        defaults.synchronize()

        let keyParts = key.components(separatedBy: ".")

        guard let rootKey = keyParts.first, !rootKey.isEmpty else { return nil }
        guard let rootValue = defaults.object(forKey: rootKey) else { return nil }

        if keyParts.count == 1 {
            return formatValueForDisplay(rootValue)
        }

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

    /// The value of `key` in a plist at a full path, via `defaults read`; nil when it fails or is empty.
    func getUserDefaultsValueFromPath(_ path: String, key: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath

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

            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty { return nil }

            writeLog("ValidationService: defaults read '\(expandedPath)' key '\(key)' = '\(trimmed)'", logLevel: .debug)
            return trimmed

        } catch {
            writeLog("ValidationService: Error running defaults read: \(error.localizedDescription)", logLevel: .error)
            return nil
        }
    }

    /// A path (starting with "/" or "~") goes through `defaults read`; anything else is a domain.
    func getUserDefaultsValue(pathOrDomain: String, key: String) -> String? {
        let isFullPath = pathOrDomain.hasPrefix("/") || pathOrDomain.hasPrefix("~")

        if isFullPath {
            return getUserDefaultsValueFromPath(pathOrDomain, key: key)
        } else {
            return getUserDefaultsValue(domain: pathOrDomain, key: key)
        }
    }
}
