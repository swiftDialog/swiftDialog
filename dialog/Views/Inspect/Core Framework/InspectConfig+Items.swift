//
//  InspectConfig+Items.swift
//  dialog
//
//  ItemConfig, the item model for presets 1–4 and 6, with its monitors, cadence and log-monitor config.
//

import Foundation
import SwiftUI

extension InspectConfig {
    struct ItemConfig: Codable, Sendable {
        let id: String
        let displayName: String
        /// Consecutive items sharing a group render under one heading; nil means ungrouped.
        let group: String?
        let subtitle: String?           // Subtitle for the preset 6 checklist row

        /// One short line saying what is being done to this item ("Clearing the runway"); the same
        /// line in every state, unlike `subtitle`, which says what the item is.
        let claim: String?

        /// Authored download size, e.g. "86 MB".
        let size: String?

        /// Authored version shown as `version · size` on the row.
        let version: String?

        /// Rough install time in seconds; "Time left" sums these over unfinished rows.
        let timeEstimate: Double?
        var guiIndex: Int   // var: `listitem: order` renumbers rows
        let paths: [String]
        /// Other names this row answers to in log text. See `MonitoredItem.logAliases`.
        let logAliases: [String]?
        let icon: String?
        let status: String?             // Status icon name; updatable via listitem: commands
        let banner: String?             // Banner image path for preset cards
        let plistKey: String?           // Plist key to check
        let expectedValue: String?      // Expected value for the key
        let evaluation: String?         // equals | boolean | exists | contains | range
        let plistRecheckInterval: Int?  // Seconds between plist rechecks (0 = disabled, 1-3600, default 0)
        let useUserDefaults: Bool?      // Watch via UserDefaults notifications instead of polling (default false)
        let category: String?
        let categoryIcon: String?

        // Step-by-step guidance
        let guidanceTitle: String?
        let guidanceContent: [GuidanceContent]?
        let stepType: String?           // "info" | "confirmation" | "processing" | "completion"

        /// Which end of the flow this step sits at, independent of what it shows.
        let phase: String?              // "intro" | "main" | "outro" (nil = main)

        /// The one definition of the phase. An authored `intro`/`outro` in `stepType` still counts,
        /// for compatibility; a renderer name there implies no phase.
        var resolvedPhase: String {
            if let phase { return phase }
            if let stepType, InspectConfig.stepPhaseValues.contains(stepType) { return stepType }
            return "main"
        }
        let autoAdvanceOnComplete: Bool? // Per-item override of the global setting
        let actionButtonText: String?
        let continueButtonText: String?
        let finalButtonText: String?
        let processingDuration: Int?    // Processing steps: seconds
        let processingMessage: String?

        let blocking: Bool?             // Blocks further progress
        let required: Bool?             // false: the primary button does not wait for this item (nil = required)
        let observeOnly: Bool?          // Per-item override of the global observeOnly
        let dockCandidate: Bool?        // Offer in the outro dock picker; when any item sets it,
                                        // only flagged items are offered, else every completed item

        // Per-item status text (overrides UILabels)
        let completedStatus: String?
        let downloadingStatus: String?
        let pendingStatus: String?

        let info: [String]?             // Bullet list for cards
        let gradientColors: [String]?   // Hex strings

        let keyPointsText: String?      // Paragraph above the "Key Points" bullets in guide steps
        let highlightColor: String?     // Hex; overrides the global highlightColor

        let successMessage: String?
        let failureMessage: String?

        // Progressive override for stuck workflows
        let waitWarningTime: Int?       // Seconds before the warning (default 120)
        let waitSmallOverrideTime: Int? // Seconds before the small override link (default 30)
        let waitLargeOverrideTime: Int? // Seconds before the large override button (default 60)
        let overrideButtonText: String? // Default "Override"
        let allowOverride: Bool?        // Default true
        let allowNavigationDuringProcessing: Bool? // Default true

        let processingMode: String?     // "simple" (default, auto-completes) | "progressive" (waits for triggers)
        let autoAdvance: Bool?          // Auto-navigate after simple mode completes (default false)
        let autoResult: String?         // Simple mode result: "success" (default) | "failure"
        let waitForExternalTrigger: Bool? // Never auto-complete; wait for a success:/failure: command

        let plistMonitors: [PlistMonitor]?
        let completionMode: String?        // "any" (default) | "all" — how completionTriggers combine

        let jsonMonitors: [JsonMonitor]?

        let itemOverlay: DetailOverlayConfig? // Overrides the global detailOverlay for this item

        let showBundleInfo: String? // "version" | "build" | "identifier" | "all"
        /// What "Open" does: nil launches the app (by `app` requirement bundle id, else first path);
        /// a URL is opened instead. Bare custom schemes are deeplinks some apps refuse.
        let openURL: String?

        // Window reposition when this step appears, as IntroStep.windowPosition.
        let windowPosition: String?             // "left" | "right" | "center" | "topleft" …
        let windowPositionOffset: Double?       // Edge offset in points

        // Completes when the managed preference lands in /Library/Managed Preferences/<domain>.plist;
        // `expectedValue`/`evaluation` refine the check (default: key exists).
        let managedPrefDomain: String?
        let managedPrefKey: String?

        // With `requirements`, completion is `satisfy` over the group and the paths/plistKey
        // ladder is ignored.
        let requirements: [Requirement]?
        let satisfy: String?            // "all" (default) | "any"

        // Card chrome ("chrome": "card"), as IntroStep.cardPanel/footerNote/continueAction.
        let cardPanel: CardPanel?               // Layout inferred from field presence
        let footerNote: String?                 // Markdown; replaces the step dots
        let continueAction: String?             // URL (x-apple.systempreferences:…) opened beside the flow

        struct Requirement: Codable, Sendable {
            let type: String            // "path" | "app" | "receipt" | "plist"
            let id: String?             // Reporting id (defaults to r<index>)
            let label: String?
            let negate: Bool?           // Invert satisfaction
            let paths: [String]?        // path: any existing path satisfies
            let bundleId: String?       // app: resolved through LaunchServices wherever installed
            let pkgId: String?          // receipt: <receiptsBasePath>/<pkgId>.plist|.bom
            let domain: String?         // plist: UserDefaults suite (includes managed prefs)
            let path: String?           // plist: absolute file, alternative to domain
            let key: String?            // plist: key path
            let expectedValue: String?
            let evaluation: String?     // exists|equals|boolean|contains|range (default: equals, or exists)
        }

        // MARK: - Auto-discovery initializer
        init(
            id: String,
            displayName: String,
            icon: String? = nil,
            paths: [String] = [],
            guiIndex: Int = 0,
            category: String? = nil,
            categoryIcon: String? = nil,
            plistKey: String? = nil,
            expectedValue: String? = nil,
            evaluation: String? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.subtitle = nil
            self.guiIndex = guiIndex
            self.paths = paths
            self.logAliases = nil
            self.icon = icon
            self.status = nil
            self.banner = nil
            self.plistKey = plistKey
            self.expectedValue = expectedValue
            self.evaluation = evaluation
            self.plistRecheckInterval = nil
            self.useUserDefaults = nil
            self.category = category
            self.categoryIcon = categoryIcon
            self.guidanceTitle = nil
            self.guidanceContent = nil
            self.stepType = nil
            self.phase = nil
            self.autoAdvanceOnComplete = nil
            self.actionButtonText = nil
            self.continueButtonText = nil
            self.finalButtonText = nil
            self.processingDuration = nil
            self.processingMessage = nil
            self.blocking = nil
            self.required = nil
            self.observeOnly = nil
            self.dockCandidate = nil
            self.completedStatus = nil
            self.downloadingStatus = nil
            self.pendingStatus = nil
            self.info = nil
            self.gradientColors = nil
            self.keyPointsText = nil
            self.highlightColor = nil
            self.successMessage = nil
            self.failureMessage = nil
            self.waitWarningTime = nil
            self.waitSmallOverrideTime = nil
            self.waitLargeOverrideTime = nil
            self.overrideButtonText = nil
            self.allowOverride = nil
            self.allowNavigationDuringProcessing = nil
            self.processingMode = nil
            self.autoAdvance = nil
            self.autoResult = nil
            self.waitForExternalTrigger = nil
            self.plistMonitors = nil
            self.completionMode = nil
            self.jsonMonitors = nil
            self.itemOverlay = nil
            self.showBundleInfo = nil
            self.openURL = nil
            self.windowPosition = nil
            self.windowPositionOffset = nil
            self.managedPrefDomain = nil
            self.managedPrefKey = nil
            self.requirements = nil
            self.satisfy = nil
            self.cardPanel = nil
            self.footerNote = nil
            self.continueAction = nil
            self.group = nil
            self.claim = nil
            self.size = nil
            self.version = nil
            self.timeEstimate = nil
        }

        // MARK: - Decoding
        private enum CodingKeys: String, CodingKey {
            case id, displayName, group, subtitle, claim, size, version, timeEstimate, guiIndex, paths, icon, status, banner
            case plistKey, expectedValue, evaluation, plistRecheckInterval, useUserDefaults
            case logAliases
            case category, categoryIcon
            case guidanceTitle, guidanceContent, stepType, phase
            case autoAdvanceOnComplete, actionButtonText, continueButtonText, finalButtonText
            case processingDuration, processingMessage
            case blocking, required, observeOnly, dockCandidate
            case completedStatus, downloadingStatus, pendingStatus
            case info, gradientColors
            case keyPointsText, highlightColor
            case successMessage, failureMessage
            case waitWarningTime, waitSmallOverrideTime, waitLargeOverrideTime
            case overrideButtonText, allowOverride, allowNavigationDuringProcessing
            case processingMode, autoAdvance, autoResult, waitForExternalTrigger
            case plistMonitors, completionMode, jsonMonitors, itemOverlay
            case showBundleInfo
            case openURL
            case windowPosition, windowPositionOffset
            case managedPrefDomain, managedPrefKey
            case requirements, satisfy
            case cardPanel, footerNote, continueAction
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let dynamicContainer = try decoder.container(keyedBy: RawCodingKey.self)
            let allItemKeys = Set(dynamicContainer.allKeys.map(\.stringValue))
            let itemId = (try? container.decode(String.self, forKey: .id)) ?? "unknown"
            let unknownItemKeys = InspectConfig.unknownKeys(in: allItemKeys, against: InspectConfig.knownItemKeys)
            for key in unknownItemKeys {
                InspectConfig.unknownKeyWarnings.append("Unknown key '\(key)' in item '\(itemId)'")
            }
            InspectConfig.auditBlockArray(in: dynamicContainer, arrayKey: "guidanceContent",
                                          owner: "item '\(itemId)'")

            id = try container.decode(String.self, forKey: .id)
            // displayName falls back to the "title" alias, then to id.
            if let dn = try container.decodeIfPresent(String.self, forKey: .displayName) {
                displayName = dn
            } else {
                let rawContainer = try decoder.container(keyedBy: RawCodingKey.self)
                displayName = (try? rawContainer.decodeIfPresent(String.self, forKey: RawCodingKey(stringValue: "title"))) ?? id
            }

            guiIndex = try container.decodeIfPresent(Int.self, forKey: .guiIndex) ?? 0
            paths = try container.decodeIfPresent([String].self, forKey: .paths) ?? []
            logAliases = try container.decodeIfPresent([String].self, forKey: .logAliases)

            subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            banner = try container.decodeIfPresent(String.self, forKey: .banner)
            plistKey = try container.decodeIfPresent(String.self, forKey: .plistKey)
            expectedValue = try container.decodeIfPresent(String.self, forKey: .expectedValue)
            evaluation = try container.decodeIfPresent(String.self, forKey: .evaluation)
            plistRecheckInterval = try container.decodeIfPresent(Int.self, forKey: .plistRecheckInterval)
            useUserDefaults = try container.decodeIfPresent(Bool.self, forKey: .useUserDefaults)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon)
            guidanceTitle = try container.decodeIfPresent(String.self, forKey: .guidanceTitle)
            // Same block canonicalization as steps: preset 6 also decodes `items[]` as `[IntroStep]`,
            // and the two decodes must agree.
            var decodedBlocks = try container.decodeIfPresent([GuidanceContent].self,
                                                              forKey: .guidanceContent)
            var blockAdvisories: [String] = []
            InspectConfig.canonicalizeBlocks(&decodedBlocks, id: id, advisories: &blockAdvisories)
            InspectConfig.unknownKeyWarnings.append(contentsOf: blockAdvisories)
            guidanceContent = decodedBlocks
            stepType = try container.decodeIfPresent(String.self, forKey: .stepType)
            phase = try container.decodeIfPresent(String.self, forKey: .phase)
            windowPosition = try container.decodeIfPresent(String.self, forKey: .windowPosition)
            windowPositionOffset = try container.decodeIfPresent(Double.self, forKey: .windowPositionOffset)
            managedPrefDomain = try container.decodeIfPresent(String.self, forKey: .managedPrefDomain)
            managedPrefKey = try container.decodeIfPresent(String.self, forKey: .managedPrefKey)
            autoAdvanceOnComplete = try container.decodeIfPresent(Bool.self, forKey: .autoAdvanceOnComplete)
            actionButtonText = try container.decodeIfPresent(String.self, forKey: .actionButtonText)
            continueButtonText = try container.decodeIfPresent(String.self, forKey: .continueButtonText)
            finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
            processingDuration = try container.decodeIfPresent(Int.self, forKey: .processingDuration)
            processingMessage = try container.decodeIfPresent(String.self, forKey: .processingMessage)
            blocking = try container.decodeIfPresent(Bool.self, forKey: .blocking)
            required = try container.decodeIfPresent(Bool.self, forKey: .required)
            dockCandidate = try container.decodeIfPresent(Bool.self, forKey: .dockCandidate)
            observeOnly = try container.decodeIfPresent(Bool.self, forKey: .observeOnly)
            completedStatus = try container.decodeIfPresent(String.self, forKey: .completedStatus)
            downloadingStatus = try container.decodeIfPresent(String.self, forKey: .downloadingStatus)
            pendingStatus = try container.decodeIfPresent(String.self, forKey: .pendingStatus)
            info = try container.decodeIfPresent([String].self, forKey: .info)
            gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
            keyPointsText = try container.decodeIfPresent(String.self, forKey: .keyPointsText)
            highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
            successMessage = try container.decodeIfPresent(String.self, forKey: .successMessage)
            failureMessage = try container.decodeIfPresent(String.self, forKey: .failureMessage)
            waitWarningTime = try container.decodeIfPresent(Int.self, forKey: .waitWarningTime)
            waitSmallOverrideTime = try container.decodeIfPresent(Int.self, forKey: .waitSmallOverrideTime)
            waitLargeOverrideTime = try container.decodeIfPresent(Int.self, forKey: .waitLargeOverrideTime)
            overrideButtonText = try container.decodeIfPresent(String.self, forKey: .overrideButtonText)
            allowOverride = try container.decodeIfPresent(Bool.self, forKey: .allowOverride)
            allowNavigationDuringProcessing = try container.decodeIfPresent(Bool.self, forKey: .allowNavigationDuringProcessing)
            processingMode = try container.decodeIfPresent(String.self, forKey: .processingMode)
            autoAdvance = try container.decodeIfPresent(Bool.self, forKey: .autoAdvance)
            autoResult = try container.decodeIfPresent(String.self, forKey: .autoResult)
            waitForExternalTrigger = try container.decodeIfPresent(Bool.self, forKey: .waitForExternalTrigger)
            plistMonitors = try container.decodeIfPresent([PlistMonitor].self, forKey: .plistMonitors)
            completionMode = try container.decodeIfPresent(String.self, forKey: .completionMode)
            jsonMonitors = try container.decodeIfPresent([JsonMonitor].self, forKey: .jsonMonitors)
            itemOverlay = try container.decodeIfPresent(DetailOverlayConfig.self, forKey: .itemOverlay)
            showBundleInfo = try container.decodeIfPresent(String.self, forKey: .showBundleInfo)
            openURL = try container.decodeIfPresent(String.self, forKey: .openURL)
            requirements = try container.decodeIfPresent([Requirement].self, forKey: .requirements)
            satisfy = try container.decodeIfPresent(String.self, forKey: .satisfy)
            cardPanel = try container.decodeIfPresent(CardPanel.self, forKey: .cardPanel)
            footerNote = try container.decodeIfPresent(String.self, forKey: .footerNote)
            continueAction = try container.decodeIfPresent(String.self, forKey: .continueAction)
            group = try container.decodeIfPresent(String.self, forKey: .group)
            claim = try container.decodeIfPresent(String.self, forKey: .claim)
            size = try container.decodeIfPresent(String.self, forKey: .size)
            version = try container.decodeIfPresent(String.self, forKey: .version)
            timeEstimate = try container.decodeIfPresent(Double.self, forKey: .timeEstimate)
        }
    }

    /// Completes a step automatically when a monitored value meets `condition`.
    struct CompletionTrigger: Codable, Sendable {
        let condition: String           // "equals" | "notEquals" | "exists" | "match" | "greaterThan" | "lessThan"
        let value: String?              // Not needed for "exists"
        let result: String              // "success" | "failure"
        let message: String?
        let delay: Double?              // Seconds before triggering (default 0)
    }

    /// Binds a plist key to a guidance block property.
    struct PlistMonitor: Codable, Sendable {
        let path: String                // Supports globs like "*.installinfo.plist"
        let key: String                 // Dot notation allowed
        let guidanceBlockIndex: Int     // 0-based
        let targetProperty: String      // "state" | "actual" | "currentPhase" | "progress" | "label"
        let valueMap: [String: String]? // Raw value → displayed value
        let recheckInterval: Int        // Seconds, 1-3600
        let useUserDefaults: Bool?      // Default false
        let evaluation: String?         // "equals" | "boolean" | "exists" | "contains" | "range"
        let completionTrigger: CompletionTrigger?
    }

    /// Binds a JSON key path to a guidance block property.
    struct JsonMonitor: Codable, Sendable {
        let path: String                // Supports globs like "*.config.json"
        let key: String                 // Dot notation allowed
        let guidanceBlockIndex: Int     // 0-based
        let targetProperty: String      // "state" | "actual" | "currentPhase" | "progress" | "label"
        let valueMap: [String: String]? // Raw value → displayed value
        let recheckInterval: Int        // Seconds, 1-3600
        let evaluation: String?         // "equals" | "boolean" | "exists" | "contains" | "range"
        let completionTrigger: CompletionTrigger?
    }

    /// The condition that advances one cadence entry.
    struct CadenceAttribute: Codable, Sendable {
        let source: String?             // "native" (default, evaluated here) | "ipc" (cadence: command)
        let type: String?               // native: "app" | "file" | "plist" | "defaults" | "json" | "managedpref"
        let bundleId: String?           // app: bundle id
        let path: String?               // file / app / plist / defaults / json path
        let key: String?                // plist/defaults/json key (dot notation)
        let expectedValue: String?      // Same field names as ItemConfig/PlistMonitor for shared evaluation
        let evaluation: String?         // "equals" | "boolean" | "exists" | "contains" | "range"
        let useUserDefaults: Bool?      // For "defaults" reads
        // managedpref: reads /Library/Managed Preferences/<domain>.plist, written by any MDM.
        let domain: String?
        let scope: String?              // "device" (default) | "user"
    }

    /// One cadence step: a message shown until `attribute` is satisfied.
    struct CadenceEntry: Codable, Identifiable, Sendable {
        let id: String                  // Stable; used by `cadence:satisfy:<id>` and SwiftUI identity
        let message: String
        let attribute: CadenceAttribute
        let minDwell: Double?           // Minimum seconds shown even if already satisfied
        let timeout: Double?            // Force-advance after this many seconds
        // Per-entry hero override; falls back to the step hero when nil.
        let sfSymbol: String?
        let imagePath: String?          // Overrides sfSymbol
        let iconColor: String?          // Hex
        let label: String?              // Tile name; localizable via "{stepId}.cadence.{entryId}.label"
        let subtitle: String?           // Tiles: the function line under the name
        var timeEstimate: Double?       // Seconds; per entry, or filled from the step's `totalTimeEstimate`
        let size: String?               // Human size ("38 MB")
        /// Hold the cadence here once satisfied; the step does not auto-advance. Without
        /// `stayMaxHold` the only exit is the orchestrator closing the dialog.
        var stay: Bool?
        /// Seconds after which Continue goes live regardless of `continueWhileRunning`.
        var stayMaxHold: Double?
        /// "pass" (default) | "fail" | "halt"; see `CadenceTimeoutOutcome.resolve(_:)`. Kept as a
        /// raw string so junk decodes without failing the entry.
        var onTimeout: String?
        /// Runs only when an earlier pick matches (`ShowWhenConfig`), evaluated as the step starts.
        var showWhen: ShowWhenConfig?

        /// This entry with `imagePath` replaced.
        func withImagePath(_ path: String) -> CadenceEntry {
            CadenceEntry(id: id, message: message, attribute: attribute, minDwell: minDwell,
                         timeout: timeout, sfSymbol: sfSymbol, imagePath: path, iconColor: iconColor,
                         label: label, subtitle: subtitle, timeEstimate: timeEstimate, size: size,
                         stay: stay, stayMaxHold: stayMaxHold, onTimeout: onTimeout, showWhen: showWhen)
        }
    }

    /// What an entry's timeout means. `pass` and `fail` both advance and differ only on the card;
    /// `halt` stops the cadence and reveals Continue.
    enum CadenceTimeoutOutcome: String, Sendable {
        case pass, fail, halt

        /// nil, unknown spellings and case variants all resolve to `.pass`.
        static func resolve(_ raw: String?) -> CadenceTimeoutOutcome {
            guard let raw, let v = CadenceTimeoutOutcome(rawValue: raw.lowercased()) else { return .pass }
            return v
        }

        var advances: Bool { self != .halt }
        /// Whether the card shows "Didn't finish".
        var marksFailed: Bool { self != .pass }
    }

    /// A managed-preference value by domain and key, read from
    /// `/Library/Managed Preferences/<domain>.plist`; `darkKey` is the dark-mode variant for colors.
    struct ManagedValueRef: Codable, Sendable {
        let domain: String
        let key: String
        let darkKey: String?
    }

    // MARK: - Log monitor
    /// Watches a log or status file and routes status text to items.
    struct LogMonitorConfig: Codable, Sendable {
        let path: String                         // Supports ~
        let preset: String?                      // installomator | jamf | munki | shell | mdm-installer | fleet
        // fleet preset only; paths are authored, never derived.
        let eventsPath: String?                  // software_install_events.jsonl (absent: no download progress)
        let serverURL: String?                   // Fleet server for icons (absent: FleetURL from the fleetd profile)
        let pattern: String?                     // Custom regex (overrides preset)
        let predicate: String?                   // Only process lines containing this string
        let captureGroup: Int?                   // Default 1
        let itemId: String?                      // Single target item
        let itemIds: [String]?                   // Several targets; status routes to all
        let autoMatch: Bool?                     // Match status to items by displayName (default true)
        let addRows: Bool?                       // Unmatched names get a row (`listitem: add`); default false
        let startFromEnd: Bool?                  // Default true

        // JSON status-file format instead of line regex
        let format: String?                      // "json"
        let statusKey: String?                   // Default "status"
        let itemKey: String?                     // Key naming the item the status applies to
    }
}

/// `ItemConfig` already has every `MonitoredItem` member, so steps' rows and items share one watcher.
extension InspectConfig.ItemConfig: MonitoredItem {}
