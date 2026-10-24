//
//  InspectConfig+ListItem.swift
//  dialog
//
//  The MonitoredItem read seam the monitoring, detection and validation services share, and ListItem, the row inside a step.
//

import Foundation
import SwiftUI

// MARK: - The shared detection seam

/// What monitoring, detection and validation read from something that can complete. Implemented by
/// `ItemConfig` (root `items[]`) and `ListItem` (rows inside a step) under the same member names.
/// Adding a member means a service reads something new.
protocol MonitoredItem {
    var id: String { get }
    var displayName: String { get }
    var icon: String? { get }
    var paths: [String] { get }
    var plistKey: String? { get }
    var expectedValue: String? { get }
    var evaluation: String? { get }
    var plistRecheckInterval: Int? { get }
    var useUserDefaults: Bool? { get }
    var jsonMonitors: [InspectConfig.JsonMonitor]? { get }
    var requirements: [InspectConfig.ItemConfig.Requirement]? { get }
    var satisfy: String? { get }
    var showBundleInfo: String? { get }

    /// Extra names this row answers to in log text, for lines naming the file rather than the item
    /// (e.g. "Downloading Example Utility-1.5.0.dmg"). Used by `LogMonitorService` and
    /// `InstallNarration.item(named:in:)`. Unlike `paths`, these are not filesystem locations.
    var logAliases: [String]? { get }

    /// The authored row facts, defaulted in the extension below so `ListItem` conforms unchanged.
    var claim: String? { get }
    var size: String? { get }
    var version: String? { get }
    var timeEstimate: Double? { get }
}

extension MonitoredItem {
    var claim: String? { nil }
    var size: String? { nil }
    var version: String? { nil }
    var timeEstimate: Double? { nil }

    /// The bundle identifier shown in the fine print (`size · bundle id`), derived from the app requirement's
    /// `bundleId` so it always matches what is checked. nil for rows detected by path.
    var displayIdentifier: String? {
        requirements?.first { $0.type == "app" && $0.bundleId != nil }?.bundleId
    }
}

extension InspectConfig {

    /// A row inside a step (`step.items`). Rows never enter the flow: they leave `steps[]`, `totalSteps`
    /// and the rail count unchanged. A separate type so rows do not offer the step vocabulary.
    struct ListItem: Codable, Identifiable, MonitoredItem, Sendable {

        /// The row shape; absent is a plain row. Independent of status. `stepType` is the older spelling of
        /// these values (`kindAliases`, folded at decode).
        enum Kind: String, Codable, CaseIterable, Sendable {
            case info           // no badge
            case confirmation   // checkbox that gates the footer
            case completion     // terminal summary row
        }

        /// Older `stepType` spellings that name a row kind; folded at decode with an advisory.
        static let kindAliases: [String: Kind] = [
            "info": .info, "confirmation": .confirmation, "completion": .completion
        ]

        var kind: Kind?

        // Identity and label
        let id: String
        let displayName: String
        let subtitle: String?

        /// Authored facts, spelled as on `ItemConfig`; both row types carry them because presets walk different types.
        let claim: String?
        let size: String?
        let version: String?            // rows state version · size
        let timeEstimate: Double?       // seconds; the install sidecar's Time-left sums these
        var guiIndex: Int
        let icon: String?
        /// An icon name, not a lifecycle state; the name is shared with `ItemConfig`.
        let status: String?
        let info: [String]?

        // Detection payload — the `MonitoredItem` seam
        let paths: [String]
        /// Names this row also answers to in log text; see `MonitoredItem.logAliases`.
        let logAliases: [String]?
        let plistKey: String?
        let expectedValue: String?
        let evaluation: String?
        let plistRecheckInterval: Int?
        let useUserDefaults: Bool?
        let plistMonitors: [PlistMonitor]?
        let jsonMonitors: [JsonMonitor]?
        let requirements: [ItemConfig.Requirement]?
        let satisfy: String?
        let managedPrefDomain: String?
        let managedPrefKey: String?
        let showBundleInfo: String?
        let openURL: String?

        // Labels — strings that feed the trailing Text, never the badge state
        let completedStatus: String?
        let downloadingStatus: String?
        let pendingStatus: String?
        let finalButtonText: String?
        let failureMessage: String?

        // Cosmetic and disclosure
        let highlightColor: String?
        let category: String?
        /// Anchor: item ⇒ popover by default. The step anchor stays `stepOverlay`.
        let itemOverlay: DetailOverlayConfig?

        private enum CodingKeys: String, CodingKey {
            case kind
            case id, displayName, subtitle, claim, size, version, timeEstimate, guiIndex, icon, status, info
            case paths, plistKey, expectedValue, evaluation, plistRecheckInterval, useUserDefaults
            case logAliases
            case plistMonitors, jsonMonitors, requirements, satisfy
            case managedPrefDomain, managedPrefKey, showBundleInfo, openURL
            case completedStatus, downloadingStatus, pendingStatus, finalButtonText, failureMessage
            case highlightColor, category, itemOverlay
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try decoder.container(keyedBy: RawCodingKey.self)

            id = try container.decode(String.self, forKey: .id)

            // Unknown-key detection, the same contract items have.
            let authored = Set(raw.allKeys.map(\.stringValue))
            for key in InspectConfig.unknownKeys(in: authored, against: InspectConfig.knownListItemKeys) {
                InspectConfig.unknownKeyWarnings.append("Unknown key '\(key)' in row '\(id)'")
            }

            // `title` is an accepted alias; fall back to the id so a path-only row is not blank.
            if let name = try container.decodeIfPresent(String.self, forKey: .displayName) {
                displayName = name
            } else {
                displayName = (try? raw.decodeIfPresent(String.self,
                                                        forKey: RawCodingKey(stringValue: "title"))) ?? id
            }

            // `kind` wins; an older `stepType` naming a kind folds with an advisory. Any other `stepType` on a row
            // is reported as having no effect.
            let authoredKind = try container.decodeIfPresent(String.self, forKey: .kind)
            let legacy = (try? raw.decodeIfPresent(String.self,
                                                   forKey: RawCodingKey(stringValue: "stepType"))) ?? nil
            if let authoredKind {
                if let parsed = Kind(rawValue: authoredKind) {
                    kind = parsed
                } else {
                    kind = nil
                    InspectConfig.unknownKeyWarnings.append(
                        "row '\(id)': kind '\(authoredKind)' is not one of "
                        + "\(Kind.allCases.map(\.rawValue).joined(separator: "/")) — treated as a plain row")
                }
                if legacy != nil {
                    InspectConfig.unknownKeyWarnings.append(
                        "row '\(id)': both 'kind' and 'stepType' authored — 'kind' wins")
                }
            } else if let legacy {
                if let folded = Self.kindAliases[legacy] {
                    kind = folded
                    InspectConfig.unknownKeyWarnings.append(
                        "row '\(id)': 'stepType: \(legacy)' is a row kind — folded to 'kind'")
                } else {
                    kind = nil
                    InspectConfig.unknownKeyWarnings.append(
                        "row '\(id)': 'stepType: \(legacy)' names a renderer or a phase, and a row "
                        + "has neither — the value is inert")
                }
            } else {
                kind = nil
            }

            guiIndex = try container.decodeIfPresent(Int.self, forKey: .guiIndex) ?? 0
            paths = try container.decodeIfPresent([String].self, forKey: .paths) ?? []
            logAliases = try container.decodeIfPresent([String].self, forKey: .logAliases)

            subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            claim = try container.decodeIfPresent(String.self, forKey: .claim)
            size = try container.decodeIfPresent(String.self, forKey: .size)
            version = try container.decodeIfPresent(String.self, forKey: .version)
            timeEstimate = try container.decodeIfPresent(Double.self, forKey: .timeEstimate)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            info = try container.decodeIfPresent([String].self, forKey: .info)
            plistKey = try container.decodeIfPresent(String.self, forKey: .plistKey)
            expectedValue = try container.decodeIfPresent(String.self, forKey: .expectedValue)
            evaluation = try container.decodeIfPresent(String.self, forKey: .evaluation)
            plistRecheckInterval = try container.decodeIfPresent(Int.self, forKey: .plistRecheckInterval)
            useUserDefaults = try container.decodeIfPresent(Bool.self, forKey: .useUserDefaults)
            plistMonitors = try container.decodeIfPresent([PlistMonitor].self, forKey: .plistMonitors)
            jsonMonitors = try container.decodeIfPresent([JsonMonitor].self, forKey: .jsonMonitors)
            requirements = try container.decodeIfPresent([ItemConfig.Requirement].self, forKey: .requirements)
            satisfy = try container.decodeIfPresent(String.self, forKey: .satisfy)
            managedPrefDomain = try container.decodeIfPresent(String.self, forKey: .managedPrefDomain)
            managedPrefKey = try container.decodeIfPresent(String.self, forKey: .managedPrefKey)
            showBundleInfo = try container.decodeIfPresent(String.self, forKey: .showBundleInfo)
            openURL = try container.decodeIfPresent(String.self, forKey: .openURL)
            completedStatus = try container.decodeIfPresent(String.self, forKey: .completedStatus)
            downloadingStatus = try container.decodeIfPresent(String.self, forKey: .downloadingStatus)
            pendingStatus = try container.decodeIfPresent(String.self, forKey: .pendingStatus)
            finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
            failureMessage = try container.decodeIfPresent(String.self, forKey: .failureMessage)
            highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            itemOverlay = try container.decodeIfPresent(DetailOverlayConfig.self, forKey: .itemOverlay)
        }
    }
}
