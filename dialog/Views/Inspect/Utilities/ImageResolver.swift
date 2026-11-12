//
//  ImageResolver.swift
//  dialog
//
//  Resolves image paths for inspect mode: absolute, relative to a base path, the standard icon
//  folders, or an SF Symbol name.
//

import Foundation
import Synchronization
import SwiftUI

/// Thread-safe resolver; the path cache and `configBasePath` sit behind one `Mutex` because
/// they are read from any thread that draws an image.
final class ImageResolver: Sendable {

    static let shared = ImageResolver()

    private let searchPaths: [String] = [
        "/opt/mgmt/resources/icons/",
        "/Library/Application Support/Dialog/icons/",
        "/Users/Shared/dialog/icons/"
    ]

    private struct State: Sendable {
        var configBasePath: String?
        var imageCache: [String: String] = [:]
    }

    private let state = Mutex(State())

    /// Set once from the config's `iconBasePath`; the fallback when callers pass no `basePath`.
    var configBasePath: String? {
        get { state.withLock { $0.configBasePath } }
        set { state.withLock { $0.configBasePath = newValue } }
    }

    private init() {
        validateSearchPaths()
        writeLog("ImageResolver: Initialized with search paths: \(searchPaths)", logLevel: .debug)
    }

    private func validateSearchPaths() {
        for path in searchPaths {
            if !FileManager.default.fileExists(atPath: path) {
                writeLog("ImageResolver: Search path does not exist: \(path)", logLevel: .debug)
            } else if !FileManager.default.isReadableFile(atPath: path) {
                writeLog("ImageResolver: Search path not accessible: \(path)", logLevel: .info)
            } else {
                writeLog("ImageResolver: Search path accessible: \(path)", logLevel: .debug)
            }
        }
    }

    func resolveImagePath(_ path: String?, basePath: String? = nil, fallbackIcon: String? = nil) -> String? {
        guard let path = path, !path.isEmpty else {
            writeLog("ImageResolver: No path provided, using fallback", logLevel: .debug)
            return fallbackIcon
        }

        writeLog("ImageResolver: Resolving path='\(path)' with basePath='\(basePath ?? "nil")'", logLevel: .info)

        // Relative paths are cached per base path; the same name under two bases is two answers.
        let effectiveBasePath = basePath ?? configBasePath
        let cacheKey = path.hasPrefix("/") ? path : "\(effectiveBasePath ?? "")|\(path)"

        if let cached = getCachedPath(for: cacheKey) {
            writeLog("ImageResolver: Using cached path: \(cached)", logLevel: .debug)
            return cached
        }

        var resolvedPath: String?

        // 1. Absolute path that exists
        if path.hasPrefix("/") {
            writeLog("ImageResolver: Checking absolute path: \(path)", logLevel: .debug)
            if FileManager.default.fileExists(atPath: path) {
                resolvedPath = path
                writeLog("ImageResolver: ✓ Found absolute path: \(path)", logLevel: .info)
            } else {
                writeLog("ImageResolver: ✗ Absolute path not found: \(path)", logLevel: .info)
            }
        }

        // 2. Relative path under the base path
        if resolvedPath == nil, let basePath = effectiveBasePath, !path.hasPrefix("/") {
            let combined = (basePath as NSString).appendingPathComponent(path)
            writeLog("ImageResolver: Checking combined path: \(combined)", logLevel: .debug)
            if FileManager.default.fileExists(atPath: combined) {
                resolvedPath = combined
                writeLog("ImageResolver: ✓ Found with basePath: \(combined)", logLevel: .info)
            } else {
                writeLog("ImageResolver: ✗ Combined path not found: \(combined)", logLevel: .info)
            }
        }

        // 3. The filename in the standard icon folders
        if resolvedPath == nil {
            let filename = (path as NSString).lastPathComponent
            resolvedPath = searchForIcon(filename: filename)
        }

        // 4. A dotted name without slashes is taken as an SF Symbol
        if resolvedPath == nil && (path.contains(".") && !path.contains("/")) {
            resolvedPath = path
            writeLog("ImageResolver: Treating as SF Symbol: \(path)", logLevel: .debug)
        }

        if let resolved = resolvedPath {
            setCachedPath(resolved, for: cacheKey)
        }

        let finalPath = resolvedPath ?? fallbackIcon
        writeLog("ImageResolver: Final resolved path for '\(path)': '\(finalPath ?? "nil")'", logLevel: .info)
        return finalPath
    }

    /// An icon named after the app id in the standard folders, else one extracted from an app bundle in `paths`.
    func resolveAppIcon(for appId: String, paths: [String]? = nil) -> String? {
        let possibleNames = [
            "\(appId).png",
            "\(appId).icns",
            "\(appId.replacingOccurrences(of: "_", with: " ")).png",
            "\(appId.replacingOccurrences(of: "_", with: " ")).icns"
        ]

        for name in possibleNames {
            if let found = searchForIcon(filename: name) {
                writeLog("ImageResolver: Found app icon for \(appId): \(found)", logLevel: .debug)
                return found
            }
        }

        if let paths = paths {
            for appPath in paths {
                if let icon = extractAppBundleIcon(from: appPath) {
                    writeLog("ImageResolver: Extracted icon from bundle: \(appPath)", logLevel: .debug)
                    return icon
                }
            }
        }

        return nil
    }

    private func searchForIcon(filename: String) -> String? {
        for searchPath in searchPaths {
            let fullPath = (searchPath as NSString).appendingPathComponent(filename)

            guard FileManager.default.isReadableFile(atPath: searchPath) else {
                continue
            }

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) && !isDirectory.boolValue {
                if FileManager.default.isReadableFile(atPath: fullPath) {
                    writeLog("ImageResolver: Found in search path: \(fullPath)", logLevel: .debug)
                    return fullPath
                } else {
                    writeLog("ImageResolver: Found but cannot read: \(fullPath)", logLevel: .debug)
                }
            }
        }
        return nil
    }

    private func extractAppBundleIcon(from appPath: String) -> String? {
        guard FileManager.default.fileExists(atPath: appPath) else { return nil }

        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let iconFile = plist["CFBundleIconFile"] as? String else {
            return nil
        }

        var iconName = iconFile
        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }

        let iconPath = (appPath as NSString).appendingPathComponent("Contents/Resources/\(iconName)")
        return FileManager.default.fileExists(atPath: iconPath) ? iconPath : nil
    }

    // MARK: - Cache Management

    private func getCachedPath(for key: String) -> String? {
        state.withLock { $0.imageCache[key] }
    }

    private func setCachedPath(_ path: String, for key: String) {
        state.withLock { $0.imageCache[key] = path }
    }

    func clearCache() {
        state.withLock { $0.imageCache.removeAll() }
        writeLog("ImageResolver: Cache cleared", logLevel: .debug)
    }

}
