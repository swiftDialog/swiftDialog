//
// IconCache.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Extracted from PresetCommonHelpers.swift
//  Icon caching and resolution for preset layouts
//

import SwiftUI

// MARK: - Icon Cache Manager

class PresetIconCache: ObservableObject {
    @Published var mainIcon: String?
    @Published var itemIcons: [String: String] = [:]
    @Published var bannerImage: NSImage?

    private let resolver = ImageResolver.shared

    func cacheMainIcon(for state: InspectState) {
        guard mainIcon == nil,
              let iconPath = state.uiConfiguration.iconPath else {
            writeLog("PresetIconCache: cacheMainIcon called but mainIcon='\(mainIcon ?? "nil")' iconPath='\(state.uiConfiguration.iconPath ?? "nil")'", logLevel: .info)
            return
        }

        writeLog("PresetIconCache: Caching main icon - iconPath='\(iconPath)' iconBasePath='\(state.uiConfiguration.iconBasePath ?? "nil")'", logLevel: .info)

        // Don't resolve SF Symbols or special keywords - pass them through directly
        if iconPathHasIgnoredPrefixKeywords(for: iconPath) {
            DispatchQueue.main.async { [weak self] in
                self?.mainIcon = iconPath
                writeLog("PresetIconCache: Main icon has ignored prefix, using directly: '\(iconPath)'", logLevel: .info)
            }
        } else {
            let resolvedIcon = resolver.resolveImagePath(
                iconPath,
                basePath: state.uiConfiguration.iconBasePath,
                fallbackIcon: nil
            )
            DispatchQueue.main.async { [weak self] in
                self?.mainIcon = resolvedIcon
                writeLog("PresetIconCache: Main icon cached as: '\(resolvedIcon ?? "nil")'", logLevel: .info)
            }
        }
    }

    /// Resolve and cache a single icon path
    private func resolveAndCacheIcon(_ icon: String, for itemId: String, basePath: String?) {
        // Don't resolve SF Symbols or special keywords - pass them through directly
        if iconPathHasIgnoredPrefixKeywords(for: icon) {
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = icon
            }
        } else if let resolved = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
            // Only cache if resolution succeeded
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = resolved
            }
        }
        // If resolution fails, don't cache anything (leave itemIcons[itemId] as nil/uncached)
    }

    func cacheItemIcons(for state: InspectState, limit: Int = 20) {
        // Stick to simple synchronous caching - remember to build on lazy loading - the SwiftUI way to prevent blocking
        // Added batch limit to prevent hanging with large item counts
        let basePath = state.uiConfiguration.iconBasePath
        let itemsToCache = state.items.prefix(limit)

        for item in itemsToCache {
            if itemIcons[item.id] == nil, let icon = item.icon {
                resolveAndCacheIcon(icon, for: item.id, basePath: basePath)
            }
        }
    }

    // Backwards compatible overload without limit
    func cacheItemIcons(for state: InspectState) {
        cacheItemIcons(for: state, limit: 20)
    }

    // Progressive caching for visible items only
    func cacheVisibleItemIcons(for items: [InspectConfig.ItemConfig], state: InspectState) {
        let basePath = state.uiConfiguration.iconBasePath

        for item in items {
            if itemIcons[item.id] == nil, let icon = item.icon {
                resolveAndCacheIcon(icon, for: item.id, basePath: basePath)
            }
        }
    }

    func cacheBannerImage(for state: InspectState) {
        guard bannerImage == nil,
              let bannerPath = state.uiConfiguration.bannerImage else { return }

        let resolvedPath = resolver.resolveImagePath(
            bannerPath,
            basePath: state.uiConfiguration.iconBasePath,
            fallbackIcon: nil
        )

        if let resolvedPath = resolvedPath,
           FileManager.default.fileExists(atPath: resolvedPath),
           let nsImage = NSImage(contentsOfFile: resolvedPath) {
            DispatchQueue.main.async { [weak self] in
                self?.bannerImage = nsImage
            }
        }
    }

    func iconPathHasIgnoredPrefixKeywords(for iconPath: String) -> Bool {
        return iconPath.lowercased().hasPrefix("sf=") ||
           iconPath.lowercased() == "default" ||
           iconPath.lowercased() == "computer" ||
            iconPath.lowercased().hasPrefix("http")
    }

    func getMainIconPath(for state: InspectState) -> String {
        if let cached = mainIcon { return cached }

        // Check if we have an icon path to cache
        if let iconPath = state.uiConfiguration.iconPath {
            // Don't resolve SF Symbols or special keywords - pass them through directly
            if iconPathHasIgnoredPrefixKeywords(for: iconPath) {
                DispatchQueue.main.async { [weak self] in
                    self?.mainIcon = iconPath
                }
                return iconPath
            }
        }

        cacheMainIcon(for: state)
        return mainIcon ?? ""
    }

    func getOverlayIconPath(for state: InspectState) -> String {
        guard let overlayIcon = state.uiConfiguration.overlayIcon, !overlayIcon.isEmpty else {
            return ""
        }

        // Don't resolve SF Symbols or special keywords - pass them through directly
        if iconPathHasIgnoredPrefixKeywords(for: overlayIcon) {
            return overlayIcon
        }

        // Resolve path using iconBasePath
        let resolvedPath = resolver.resolveImagePath(
            overlayIcon,
            basePath: state.uiConfiguration.iconBasePath,
            fallbackIcon: nil
        )

        return resolvedPath ?? ""
    }

    func getItemIconPath(for item: InspectConfig.ItemConfig, state: InspectState) -> String {
        if let cached = itemIcons[item.id] { return cached }

        guard let icon = item.icon else { return "" }

        // Use the common resolution logic
        resolveAndCacheIcon(icon, for: item.id, basePath: state.uiConfiguration.iconBasePath)
        return itemIcons[item.id] ?? ""
    }

    // Helper for resolving paths (e.g., for rotating images in Preset6)
    func resolveImagePath(_ path: String, basePath: String?) -> String? {
        return resolver.resolveImagePath(path, basePath: basePath, fallbackIcon: nil)
    }
}
