//
//  InspectState+RuntimeSupport.swift
//  dialog
//
//  Interaction log sink, bundle info reads and the FileMonitor delegate.
//

import SwiftUI

extension InspectState {
    func writeToInteractionLog(_ message: String) {
        // One sink for every preset, so scripts tail one file.
        appendToInteractionLog(message)
    }

    // MARK: - Progress Tracking

    func initializeProgressTracker() {
        let preset = uiConfiguration.preset.lowercased()
        let totalItems = items.count

        updatePresetSpecificProgress()

        writeLog("InspectState: Progress tracker initialized for \(preset) with \(totalItems) items", logLevel: .info)
    }

    private func updatePresetSpecificProgress() {
        switch uiConfiguration.preset.lowercased() {
        case "preset1":
            break

        case "preset6":
            break

        default:
            break
        }
    }

    // MARK: - Bundle Info

    /// Reads an app bundle's Info.plist. `infoType` is "version", "build", "identifier" or "all"
    /// ("version (build) - identifier"); anything else reads as "version".
    func getBundleInfo(appPath: String, infoType: String) -> String? {
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

        guard FileManager.default.fileExists(atPath: infoPlistPath),
              let plist = NSDictionary(contentsOfFile: infoPlistPath) else {
            writeLog("InspectState: Could not read Info.plist at \(infoPlistPath)", logLevel: .debug)
            return nil
        }

        let version = plist["CFBundleShortVersionString"] as? String
        let build = plist["CFBundleVersion"] as? String
        let identifier = plist["CFBundleIdentifier"] as? String

        switch infoType.lowercased() {
        case "version":
            return version
        case "build":
            return build
        case "identifier":
            return identifier
        case "all":
            var parts: [String] = []
            if let v = version {
                if let b = build {
                    parts.append("\(v) (\(b))")
                } else {
                    parts.append(v)
                }
            } else if let b = build {
                parts.append(b)
            }
            if let id = identifier {
                parts.append(id)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")
        default:
            writeLog("InspectState: Unknown bundle info type '\(infoType)', use 'version', 'build', 'identifier', or 'all'", logLevel: .info)
            return version
        }
    }

    /// Bundle info for a row whose `showBundleInfo` is set and whose first path is an installed .app.
    func getBundleInfoForItem(_ item: any MonitoredItem) -> String? {
        guard let infoType = item.showBundleInfo,
              let firstPath = item.paths.first,
              firstPath.hasSuffix(".app"),
              FileManager.default.fileExists(atPath: firstPath) else {
            return nil
        }
        return getBundleInfo(appPath: firstPath, infoType: infoType)
    }

    // MARK: - FileMonitorDelegate

    // These callbacks arrive on FileMonitor's own queue and are observers only: the 2 s poller
    // is the single writer of `completedItems`, `downloadingItems` and `removedItems`. The prior
    // state is unknown here, so the detection log's `from` is "watched".
    nonisolated func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String) {
        writeLog("InspectState: Installation detected for \(itemId)", logLevel: .debug)
        DetectionLog.note(itemId: itemId, from: "watched", to: "present", by: .fsevents)
    }

    nonisolated func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String) {
        writeLog("InspectState: Removal detected for \(itemId)", logLevel: .debug)
        DetectionLog.note(itemId: itemId, from: "watched", to: "absent", by: .fsevents)
    }

    nonisolated func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String) {
        writeLog("InspectState: Download detected for \(itemId)", logLevel: .debug)
        DetectionLog.note(itemId: itemId, from: "watched", to: "caching", by: .fsevents)
    }

    nonisolated func fileMonitorDidDetectChanges(_ monitor: FileMonitor) {
        writeLog("InspectState: File monitor detected changes", logLevel: .debug)
    }
}
