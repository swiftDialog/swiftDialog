//
//  FilenameMatching.swift
//  Dialog
//
//  Shared filename heuristics for download and cache monitoring, used by FileMonitor,
//  InspectState+InstallationDetection, InstallNarration, DetectionExplain and MonitoringModule.
//  Every behavioural difference between callers is a named flag or a named variant.
//

import Foundation

enum FilenameMatching {

    /// Whether a filename looks like a download. With `includeInstallerMarkers`, "installer" and
    /// "setup" names count too (MonitoringModule passes false).
    static func isDownloadFile(_ filename: String, cacheExtensions: [String],
                               includeInstallerMarkers: Bool = true) -> Bool {
        let lowercased = filename.lowercased()
        if cacheExtensions.contains(where: { lowercased.hasSuffix($0) }) ||
           lowercased.contains(".partial") ||
           lowercased.contains(".tmp") {
            return true
        }
        return includeInstallerMarkers &&
               (lowercased.contains("installer") || lowercased.contains("setup"))
    }

    /// Two-way fast check (item id, space-stripped display name) used by MonitoringModule.
    /// Lacks the underscore-stripped term of `matches` strategy 1 on purpose.
    static func directMatch(itemId: String, displayName: String, filename: String) -> Bool {
        let cleanFilename = filename.lowercased()
        return cleanFilename.contains(itemId.lowercased()) ||
               cleanFilename.contains(displayName.lowercased()
                                        .replacingOccurrences(of: " ", with: ""))
    }

    /// Filename matching ladder. Strategies 1–3 always run; strategy 4 (brand fuzzy, e.g.
    /// microsoft_office → Office_365) runs only with `brandFuzzy`. `log` receives strategy hits.
    static func matches(itemId: String, displayName: String, filename: String,
                        brandFuzzy: Bool, log: ((String) -> Void)? = nil) -> Bool {
        let cleanFilename = filename.lowercased()
        let cleanItemId = itemId.lowercased()
        let cleanDisplayName = displayName.lowercased().replacingOccurrences(of: " ", with: "")

        let cleanDisplayNameNoUnderscore = displayName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Strategy 1: direct substring match
        if cleanFilename.contains(cleanItemId) ||
           cleanFilename.contains(cleanDisplayName) ||
           cleanFilename.contains(cleanDisplayNameNoUnderscore) {
            log?("Strategy 1 match: '\(filename)' matched")
            return true
        }

        // Strategy 2: every significant component (longer than 2 chars) appears in the filename
        let itemComponents = cleanItemId.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }

        let displayComponents = cleanDisplayName.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }

        let allItemComponentsMatch = !itemComponents.isEmpty && itemComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        let allDisplayComponentsMatch = !displayComponents.isEmpty && displayComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        if allItemComponentsMatch || allDisplayComponentsMatch {
            log?("Strategy 2 match: '\(filename)' component match")
            return true
        }

        // Strategy 3: condensed forms without underscores
        let condensedItemId = cleanItemId.replacingOccurrences(of: "_", with: "")
        let condensedDisplayName = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        if cleanFilename.contains(condensedItemId) || cleanFilename.contains(condensedDisplayName) {
            log?("Strategy 3 match: '\(filename)' contains condensed form")
            return true
        }

        // Strategy 4: brand fuzzy, microsoft_* matches on the app name (second component)
        if brandFuzzy, let primaryComponent = itemComponents.first, primaryComponent.count >= 4 {
            if primaryComponent == "microsoft" && itemComponents.count > 1 {
                let appName = itemComponents[1]
                if cleanFilename.contains(appName) {
                    log?("Strategy 4 match: '\(filename)' contains app name '\(appName)'")
                    return true
                }
            }
        }

        return false
    }
}
