//
//  ImageResolver.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/09/2025
//
//  Unified image resolver system for inspect mode
//  Supports both absolute and relative paths with intelligent fallback
//

import Foundation
import SwiftUI

class ImageResolver {

    static let shared = ImageResolver()

    private let searchPaths: [String] = [
        "/opt/mgmt/resources/icons/",
        "/Library/Application Support/Dialog/icons/",
        "/Users/Shared/dialog/icons/"
    ]

    /// Set once from config's iconBasePath — used as fallback when callers don't pass basePath
    var configBasePath: String?

    private var imageCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "dialog.inspect.imagecache", attributes: .concurrent)

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

        // Check cache first
        if let cached = getCachedPath(for: path) {
            writeLog("ImageResolver: Using cached path: \(cached)", logLevel: .debug)
            return cached
        }

        // Try to resolve the path
        var resolvedPath: String?

        // 1. If it's an absolute path and exists, use it
        if path.hasPrefix("/") {
            writeLog("ImageResolver: Checking absolute path: \(path)", logLevel: .debug)
            if FileManager.default.fileExists(atPath: path) {
                resolvedPath = path
                writeLog("ImageResolver: ✓ Found absolute path: \(path)", logLevel: .info)
            } else {
                writeLog("ImageResolver: ✗ Absolute path not found: \(path)", logLevel: .info)
            }
        }

        // 2. If we have a basePath and path is relative, try combining them
        let effectiveBasePath = basePath ?? configBasePath
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

        // 3. Search standard locations for the filename
        if resolvedPath == nil {
            let filename = (path as NSString).lastPathComponent
            resolvedPath = searchForIcon(filename: filename)
        }

        // 4. Try SF Symbols if it looks like one
        if resolvedPath == nil && (path.contains(".") && !path.contains("/")) {
            // This might be an SF Symbol
            resolvedPath = path
            writeLog("ImageResolver: Treating as SF Symbol: \(path)", logLevel: .debug)
        }

        // Cache the result
        if let resolved = resolvedPath {
            setCachedPath(resolved, for: path)
        }

        // Return resolved path or fallback
        let finalPath = resolvedPath ?? fallbackIcon
        writeLog("ImageResolver: Final resolved path for '\(path)': '\(finalPath ?? "nil")'", logLevel: .info)
        return finalPath
    }

    func resolveAppIcon(for appId: String, paths: [String]? = nil) -> String? {
        // Try to find app icon in standard locations
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

        // Try to extract icon from app bundle if paths provided
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

            // Check if we can access the directory first
            guard FileManager.default.isReadableFile(atPath: searchPath) else {
                // Skip directories we can't read
                continue
            }

            // Use proper file existence check with error handling
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) && !isDirectory.boolValue {
                // Tedious but necessary - caveman style: verify we can actually read the file
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
        cacheQueue.sync {
            return imageCache[key]
        }
    }

    private func setCachedPath(_ path: String, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.imageCache[key] = path
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.imageCache.removeAll()
            writeLog("ImageResolver: Cache cleared", logLevel: .debug)
        }
    }

    // MARK: - SwiftUI Integration

    func loadImage(from path: String?) -> Image? {
        guard let resolvedPath = resolveImagePath(path) else {
            return nil
        }

        // Check if it's an SF Symbol - this should work but you never know
        if !resolvedPath.contains("/") && resolvedPath.contains(".") {
            return Image(systemName: resolvedPath)
        }

        // Load from file
        if let nsImage = NSImage(contentsOfFile: resolvedPath) {
            return Image(nsImage: nsImage)
        }

        return nil
    }

    func loadImageWithFallback(from path: String?, fallback: String = "questionmark.circle") -> Image {
        if let image = loadImage(from: path) {
            return image
        }

        // Try fallback as SF Symbol first
        if !fallback.contains("/") {
            return Image(systemName: fallback)
        }

        // Try fallback as file path
        if let nsImage = NSImage(contentsOfFile: fallback) {
            return Image(nsImage: nsImage)
        }

        // Ultimate fallback
        return Image(systemName: "questionmark.circle")
    }
}

// MARK: - Preset Integration Helper

extension ImageResolver {

    func resolveItemIcon(_ item: InspectConfig.ItemConfig, basePath: String? = nil) -> String? {
        // First try the item's icon field
        if let icon = item.icon {
            return resolveImagePath(icon, basePath: basePath)
        }

        // Then try to find based on app ID and paths
        return resolveAppIcon(for: item.id, paths: item.paths)
    }

    func resolveAllIcons(for items: [InspectConfig.ItemConfig], basePath: String? = nil) -> [String: String] {
        var resolved: [String: String] = [:]

        for item in items {
            if let iconPath = resolveItemIcon(item, basePath: basePath) {
                resolved[item.id] = iconPath
            }
        }

        writeLog("ImageResolver: Resolved \(resolved.count) icons for \(items.count) items", logLevel: .info)
        return resolved
    }
}